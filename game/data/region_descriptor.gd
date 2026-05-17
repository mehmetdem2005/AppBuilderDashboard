class_name RegionDescriptor
extends Resource
## A story zone, defined purely as data. Loaded by reference, never a scene.

@export var region_id: StringName = &"default"
@export var display_name: String = "Bölge"
@export var bounds: AABB = AABB(Vector3(-1000, -100, -1000), Vector3(2000, 460, 2000))
@export var biome: BiomeProfile
@export var spawn_point: Vector3 = Vector3(0, 0, 0)
@export var asset_set: Array[StringName] = []       # allowed prop ids
@export var story_node: StringName = &""            # dialogue_editor hook

func contains_xz(wx: float, wz: float) -> bool:
	return wx >= bounds.position.x and wx <= bounds.position.x + bounds.size.x \
		and wz >= bounds.position.z and wz <= bounds.position.z + bounds.size.z
