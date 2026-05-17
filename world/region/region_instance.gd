class_name RegionInstance
extends RefCounted
## Lightweight runtime wrapper around an active RegionDescriptor.
## Holds no scene/baked data — purely a reference + activation bookkeeping.

var descriptor: RegionDescriptor
var activated: bool = false

func _init(d: RegionDescriptor) -> void:
	descriptor = d

func id() -> StringName:
	return descriptor.region_id if descriptor != null else &"default"
