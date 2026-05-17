class_name CollisionBuilder
extends RefCounted
## STATELESS heightfield sampler for one collision cell, run on a worker
## thread. Returns only a PackedFloat32Array (no PhysicsServer calls — the
## body/shape are created on the main thread by CollisionChunkGrid).
## Resolution is FIXED and independent of visual LOD so the player never
## falls through terrain when distant visuals pop to a coarse LOD.

const N := 16                            # subdivisions per collision cell

static func build(td: TerrainData, cx: int, cz: int, cell_size: float,
		world_size: float) -> Dictionary:
	var half := world_size * 0.5
	var ox := -half + float(cx) * cell_size
	var oz := -half + float(cz) * cell_size
	var step := cell_size / float(N)
	var data := PackedFloat32Array()
	data.resize((N + 1) * (N + 1))
	for j in range(N + 1):
		for i in range(N + 1):
			var wx := ox + float(i) * step
			var wz := oz + float(j) * step
			data[j * (N + 1) + i] = td.height(wx, wz)
	return {
		"cx": cx, "cz": cz,
		"data": data,
		"center": Vector3(ox + cell_size * 0.5, 0.0, oz + cell_size * 0.5),
		"step": step,
	}
