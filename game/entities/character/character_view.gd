class_name CharacterView
extends Node3D
## Visual rig holder. Mesh comes from AssetRegistry by id (swappable when
## real animal models arrive — no code change, just the manifest/asset).

var _mi: MeshInstance3D

func setup(asset_id: StringName) -> void:
	if _mi == null:
		_mi = MeshInstance3D.new()
		add_child(_mi)
	_mi.mesh = AssetRegistry.get_mesh(asset_id)
