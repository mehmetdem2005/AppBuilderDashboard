class_name TerrainChunk
extends Node3D
## Pooled visual tile shell. Heavy resources (ArrayMesh/MultiMesh) are created
## from a pre-built (threaded) result on the MAIN thread only, then freed
## explicitly on release so memory stays bounded on a low-RAM device.

var cell: Vector2i = Vector2i.ZERO
var lod: int = -1

var _terrain_mi: MeshInstance3D
var _tree_mmi: MultiMeshInstance3D
var _bush_mmi: MultiMeshInstance3D

func _ensure_nodes() -> void:
	if _terrain_mi == null:
		_terrain_mi = MeshInstance3D.new()
		add_child(_terrain_mi)

func commit(result: Dictionary, lod_level: int, mat: Material,
		tree_mesh: Mesh, bush_mesh: Mesh, cast_shadow: bool) -> void:
	cell = Vector2i(result.cx, result.cz)
	lod = lod_level
	_ensure_nodes()
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, result.arrays)
	_terrain_mi.mesh = am
	_terrain_mi.material_override = mat
	_terrain_mi.cast_shadow = (GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)

	_apply_mm(result.trees, tree_mesh, true)
	_apply_mm(result.bushes, bush_mesh, false)

func _apply_mm(xforms: Array, mesh: Mesh, is_tree: bool) -> void:
	var holder: MultiMeshInstance3D = _tree_mmi if is_tree else _bush_mmi
	if xforms.is_empty():
		if holder != null:
			holder.multimesh = null
			holder.visible = false
		return
	if holder == null:
		holder = MultiMeshInstance3D.new()
		add_child(holder)
		if is_tree: _tree_mmi = holder
		else: _bush_mmi = holder
	holder.visible = true
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		mm.set_instance_transform(i, xforms[i])
	holder.multimesh = mm

## Called by the pool on eviction: drop heavy GPU resources, keep the node.
func recycle() -> void:
	lod = -1
	if _terrain_mi != null:
		_terrain_mi.mesh = null
	if _tree_mmi != null:
		_tree_mmi.multimesh = null
		_tree_mmi.visible = false
	if _bush_mmi != null:
		_bush_mmi.multimesh = null
		_bush_mmi.visible = false
