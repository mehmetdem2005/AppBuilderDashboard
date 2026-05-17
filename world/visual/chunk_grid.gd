class_name VisualChunkGrid
extends Node3D
## Streamed VISUAL terrain grid. Threaded build (WorkerThreadPool), distance
## LOD rings, pooled eviction, per-frame GL-upload budget. Independent from
## the collision grid (different radius/res/cadence) — see CollisionChunkGrid.

const CELL := 125.0
const RES := {0: 32, 1: 24, 2: 16, 3: 8}
const LOD_RING := {0: 1, 1: 3}           # ring<=1 LOD0, <=3 LOD1, else LOD2/3
const MAX_WORKER := 2

var td: TerrainData
var world_size := 2000.0
var grid := 16
var radius := 4
var scatter_mul := 0.7
var cast_shadows := false
var biome: BiomeProfile

var _mat: ShaderMaterial
var _tree_mesh: Mesh
var _bush_mesh: Mesh
var _active: Dictionary = {}             # Vector2i -> TerrainChunk
var _pending: Dictionary = {}            # Vector2i -> int (want lod)
var _tasks: Dictionary = {}              # Vector2i -> task_id
var _mutex: Mutex = Mutex.new()
var _done: Array = []                    # [{result, want_lod}]
var _pool: ObjectPool

func setup(terrain: TerrainData, biome_profile: BiomeProfile) -> void:
	if _mutex == null:
		_mutex = Mutex.new()
	td = terrain
	world_size = terrain.world_size if terrain != null else 2000.0
	grid = GridMath.grid_count(world_size, CELL)
	biome = biome_profile
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://world/visual/terrain.gdshader")
	_apply_biome()
	_tree_mesh = AssetRegistry.get_mesh(biome.tree_asset if biome else &"tree_default")
	_bush_mesh = AssetRegistry.get_mesh(biome.bush_asset if biome else &"bush_default")
	_pool = ObjectPool.new(func(): return TerrainChunk.new(), 160)
	EventBus.quality_changed.connect(_on_quality)
	_on_quality(QualityManager.active)

func _apply_biome() -> void:
	if biome == null:
		return
	_mat.set_shader_parameter("sea_level", biome.sea_level)
	_mat.set_shader_parameter("relief", biome.relief)
	_mat.set_shader_parameter("c_sand", biome.c_sand)
	_mat.set_shader_parameter("c_grass", biome.c_grass)
	_mat.set_shader_parameter("c_grass2", biome.c_grass2)
	_mat.set_shader_parameter("c_dry", biome.c_dry)
	_mat.set_shader_parameter("c_rock", biome.c_rock)

func _on_quality(p: QualityPreset) -> void:
	if p == null:
		return
	radius = p.visual_radius
	scatter_mul = p.scatter_mul
	cast_shadows = p.shadows_enabled

func set_biome(b: BiomeProfile) -> void:
	biome = b
	_apply_biome()
	flush()

func _lod_for(ring: int) -> int:
	if ring <= LOD_RING[0]: return 0
	if ring <= LOD_RING[1]: return 1
	if ring <= radius: return 2
	return 3

func active_count() -> int:
	return _active.size()

func pending_count() -> int:
	return _pending.size()

func is_idle() -> bool:
	return _pending.is_empty() and _done.is_empty()

func flush() -> void:
	for k in _active.keys():
		var ch: TerrainChunk = _active[k]
		ch.recycle()
		_pool.release(ch)
	_active.clear()
	_pending.clear()
	_tasks.clear()
	_done.clear()

func update(focus: Vector3) -> void:
	if td == null:
		return
	var fc := GridMath.cell_of(focus.x, focus.z, CELL, world_size)

	# desired set
	var needed: Dictionary = {}
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var c := Vector2i(fc.x + dx, fc.y + dz)
			if c.x < 0 or c.y < 0 or c.x >= grid or c.y >= grid:
				continue
			var ring: int = maxi(absi(dx), absi(dz))
			if ring > radius:
				continue
			needed[c] = _lod_for(ring)

	# evict
	for k in _active.keys():
		if not needed.has(k):
			var ch: TerrainChunk = _active[k]
			ch.recycle()
			_pool.release(ch)
			_active.erase(k)

	# enqueue builds (nearest first, bounded concurrency)
	var todo: Array = []
	for c in needed.keys():
		var want: int = needed[c]
		if _pending.has(c):
			continue
		if _active.has(c) and _active[c].lod == want:
			continue
		var d: int = absi(c.x - fc.x) + absi(c.y - fc.y)
		todo.append([d, c, want])
	todo.sort_custom(func(a, b): return a[0] < b[0])
	for item in todo:
		if _tasks.size() >= MAX_WORKER:
			break
		var c: Vector2i = item[1]
		var want: int = item[2]
		_pending[c] = want
		var cfg := _scatter_cfg(want)
		var tid := WorkerThreadPool.add_task(
			_run_job.bind(c, want, cfg), false, "chunk")
		_tasks[c] = tid

	# poll finished worker tasks
	for c in _tasks.keys().duplicate():
		var tid: int = _tasks[c]
		if WorkerThreadPool.is_task_completed(tid):
			WorkerThreadPool.wait_for_task_completion(tid)
			_tasks.erase(c)

	# commit with a per-frame budget (avoid GL upload spikes)
	_commit_budget()

func _scatter_cfg(want_lod: int) -> Dictionary:
	var enabled := want_lod <= 1
	var sea := biome.sea_level if biome else 11.5
	var zmax := td.zmax if td else 230.0
	var frac := biome.tree_line_frac if biome else 0.72
	return {
		"enabled": enabled,
		"sea": sea,
		"tree_line": sea + (zmax - sea) * frac,
		"scatter_mul": scatter_mul,
		"tree_density": biome.tree_density if biome else 0.7,
		"bush_density": biome.bush_density if biome else 0.5,
	}

func _run_job(c: Vector2i, want: int, cfg: Dictionary) -> void:
	var res := ChunkBuilder.build(td, c.x, c.y, CELL, RES[want],
		world_size, cfg)
	_mutex.lock()
	_done.append({"result": res, "want": want})
	_mutex.unlock()

func _commit_budget() -> void:
	var lod0_done := 0
	var other_done := 0
	_mutex.lock()
	var batch := _done
	_done = []
	_mutex.unlock()
	var requeue: Array = []
	for entry in batch:
		var want: int = entry.want
		if want == 0 and lod0_done >= 1:
			requeue.append(entry); continue
		if want != 0 and other_done >= 2:
			requeue.append(entry); continue
		var res: Dictionary = entry.result
		var c := Vector2i(res.cx, res.cz)
		_pending.erase(c)
		var ch: TerrainChunk
		if _active.has(c):
			ch = _active[c]
		else:
			ch = _pool.acquire()
			add_child(ch)
			_active[c] = ch
		ch.commit(res, want, _mat, _tree_mesh, _bush_mesh,
			cast_shadows and want <= 1)
		if want == 0: lod0_done += 1
		else: other_done += 1
	if not requeue.is_empty():
		_mutex.lock()
		_done = requeue + _done
		_mutex.unlock()
