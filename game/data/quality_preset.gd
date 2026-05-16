class_name QualityPreset
extends Resource
## Pure data. A device quality tier. Stored as .tres, never in a scene.

@export var id: StringName = &"low"
@export var display_name: String = "Düşük"
@export_range(3, 8) var visual_radius: int = 4
@export_range(0.0, 2.0) var lod_bias: float = 1.0
@export_range(0.3, 1.0) var scatter_mul: float = 0.7
@export_range(0.5, 1.0) var render_scale: float = 0.85
@export var shadows_enabled: bool = false
@export var shadow_max_distance: float = 120.0
@export_range(0, 4) var msaa: int = 0
@export var fog_end: float = 900.0
@export_range(1, 3) var collision_radius: int = 2
@export_range(1, 4) var worker_tasks: int = 2
