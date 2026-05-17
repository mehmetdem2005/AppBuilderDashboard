class_name ChunkBuilder
extends RefCounted
## STATELESS terrain-tile builder run on WorkerThreadPool. Produces only
## Packed arrays / Transform lists. MUST NOT touch Node/RenderingServer/
## PhysicsServer (Godot threading rule) — the grid commits on the main thread.

const SKIRT_MIN := 8.0
const SKIRT_STEP_K := 4.0                # skirt depth scales with the LOD step

static func build(td: TerrainData, cx: int, cz: int, cell_size: float,
		res: int, world_size: float, scatter: Dictionary) -> Dictionary:
	var half := world_size * 0.5
	var ox := -half + float(cx) * cell_size
	var oz := -half + float(cz) * cell_size
	var step := cell_size / float(res)
	var n := res + 1
	# Coarser LOD => bigger step => bigger possible height jump at a seam.
	# A fixed skirt cannot hide that; scale it with the sampling step so the
	# downward ring always reaches below the neighbouring tile's edge.
	var skirt := maxf(SKIRT_MIN, step * SKIRT_STEP_K)

	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	verts.resize(n * n)
	norms.resize(n * n)
	for j in range(n):
		for i in range(n):
			var wx := ox + float(i) * step
			var wz := oz + float(j) * step
			var k := j * n + i
			verts[k] = Vector3(wx, td.height(wx, wz), wz)
			norms[k] = td.normal(wx, wz)
	for j in range(res):
		for i in range(res):
			var a := j * n + i
			var b := a + 1
			var c := a + n
			var d := c + 1
			idx.append(a); idx.append(b); idx.append(c)
			idx.append(b); idx.append(d); idx.append(c)

	# downward skirt ring (hides LOD/chunk seams without z-fighting)
	var base := verts.size()
	var ring: Array = []
	for i in range(n): ring.append(Vector2i(i, 0))
	for j in range(1, n): ring.append(Vector2i(n - 1, j))
	for i in range(n - 2, -1, -1): ring.append(Vector2i(i, n - 1))
	for j in range(n - 2, 0, -1): ring.append(Vector2i(0, j))
	for r in ring:
		var top: Vector3 = verts[r.y * n + r.x]
		verts.append(top)
		verts.append(Vector3(top.x, top.y - skirt, top.z))
		norms.append(Vector3.UP)
		norms.append(Vector3.UP)
	var rc := ring.size()
	for k in range(rc):
		var k2 := (k + 1) % rc
		var t0 := base + k * 2
		var b0 := t0 + 1
		var t1 := base + k2 * 2
		var b1 := t1 + 1
		idx.append(t0); idx.append(t1); idx.append(b0)
		idx.append(t1); idx.append(b1); idx.append(b0)

	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = idx

	var trees: Array = []
	var bushes: Array = []
	if scatter.get("enabled", false):
		_scatter(td, cx, cz, ox, oz, cell_size, scatter, trees, bushes)

	return {
		"cx": cx, "cz": cz,
		"arrays": arr,
		"trees": trees,
		"bushes": bushes,
	}

static func _scatter(td: TerrainData, cx: int, cz: int, ox: float, oz: float,
		cs: float, cfg: Dictionary, trees: Array, bushes: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(cx, cz))           # deterministic -> save friendly
	var sea: float = cfg.sea
	var tree_line: float = cfg.tree_line
	var mul: float = cfg.scatter_mul
	var samples := int(110 * mul)
	for s in range(samples):
		var wx := ox + rng.randf() * cs
		var wz := oz + rng.randf() * cs
		var y := td.height(wx, wz)
		if y < sea + 2.0 or y > tree_line:
			continue
		if td.normal(wx, wz).y < 0.78:
			continue
		var gate := sin(wx * 0.05) * cos(wz * 0.045) + rng.randf_range(-0.6, 0.6)
		if gate < -0.15:
			continue
		var sc := rng.randf_range(0.8, 1.5)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(
			Vector3(sc, sc * rng.randf_range(0.9, 1.25), sc))
		var t := Transform3D(b, Vector3(wx, y - 0.3, wz))
		if rng.randf() < cfg.tree_density:
			trees.append(t)
		elif rng.randf() < cfg.bush_density:
			bushes.append(t)
