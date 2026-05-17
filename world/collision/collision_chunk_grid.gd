class_name CollisionChunkGrid
extends Node3D
## INDEPENDENT physics-collider streamer. Deliberately separate from the
## visual grid: smaller cell, tiny radius, FIXED resolution, its own 20 Hz
## cadence and worker budget. Distant collision NEVER exists -> bounded CPU
## & RAM on a weak phone, while the ground under the player stays accurate
## and stable regardless of how aggressively visuals drop LOD.

const CELL := 62.5
const MAX_WORKER := 2
const COMMIT_BUDGET := 2

var td: TerrainData
var world_size := 2000.0
var grid := 32
var radius := 2

var _active: Dictionary = {}             # Vector2i -> CollisionChunk
var _pending: Dictionary = {}
var _tasks: Dictionary = {}
var _mutex: Mutex = Mutex.new()
var _done: Array = []
var _pool: ObjectPool

func setup(terrain: TerrainData) -> void:
	if _mutex == null:
		_mutex = Mutex.new()
	td = terrain
	world_size = terrain.world_size if terrain != null else 2000.0
	grid = GridMath.grid_count(world_size, CELL)
	_pool = ObjectPool.new(func(): return CollisionChunk.new(), 80)
	EventBus.quality_changed.connect(_on_quality)
	_on_quality(QualityManager.active)

func _on_quality(p: QualityPreset) -> void:
	if p != null:
		radius = p.collision_radius

func active_count() -> int:
	return _active.size()

func is_idle() -> bool:
	return _pending.is_empty() and _done.is_empty()

func flush() -> void:
	for k in _active.keys():
		var ch: CollisionChunk = _active[k]
		ch.recycle()
		_pool.release(ch)
	_active.clear()
	_pending.clear()
	_tasks.clear()
	_done.clear()

## Called at the collision cadence (NOT every frame) by WorldStreamer.
func update(focus: Vector3) -> void:
	if td == null:
		return
	var fc := GridMath.cell_of(focus.x, focus.z, CELL, world_size)

	var needed: Dictionary = {}
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var c := Vector2i(fc.x + dx, fc.y + dz)
			if c.x < 0 or c.y < 0 or c.x >= grid or c.y >= grid:
				continue
			needed[c] = true

	for k in _active.keys():
		if not needed.has(k):
			var ch: CollisionChunk = _active[k]
			ch.recycle()
			_pool.release(ch)
			_active.erase(k)

	var todo: Array = []
	for c in needed.keys():
		if _pending.has(c) or _active.has(c):
			continue
		var d: int = absi(c.x - fc.x) + absi(c.y - fc.y)
		todo.append([d, c])
	todo.sort_custom(func(a, b): return a[0] < b[0])
	for item in todo:
		if _tasks.size() >= MAX_WORKER:
			break
		var c: Vector2i = item[1]
		_pending[c] = true
		var tid := WorkerThreadPool.add_task(_run_job.bind(c), false, "coll")
		_tasks[c] = tid

	for c in _tasks.keys().duplicate():
		var tid: int = _tasks[c]
		if WorkerThreadPool.is_task_completed(tid):
			WorkerThreadPool.wait_for_task_completion(tid)
			_tasks.erase(c)

	_commit()

func _run_job(c: Vector2i) -> void:
	var res := CollisionBuilder.build(td, c.x, c.y, CELL, world_size)
	_mutex.lock()
	_done.append(res)
	_mutex.unlock()

func _commit() -> void:
	_mutex.lock()
	var batch := _done
	_done = []
	_mutex.unlock()
	var n := 0
	var requeue: Array = []
	for res in batch:
		if n >= COMMIT_BUDGET:
			requeue.append(res); continue
		var c := Vector2i(res.cx, res.cz)
		_pending.erase(c)
		if _active.has(c):
			continue
		var ch: CollisionChunk = _pool.acquire()
		add_child(ch)
		ch.commit(res)
		_active[c] = ch
		n += 1
	if not requeue.is_empty():
		_mutex.lock()
		_done = requeue + _done
		_mutex.unlock()
