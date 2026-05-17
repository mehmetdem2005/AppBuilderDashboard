extends Node3D
## Light coordinator. All systems are REAL nodes in Game.tscn (visible &
## tweakable in the editor). This script only wires runtime cross-cutting
## concerns (quality -> sun/fog). No world building here anymore.

@export var sun_path: NodePath
@export var world_env_path: NodePath

var _sun: DirectionalLight3D
var _env: WorldEnvironment

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_sun = get_node_or_null(sun_path) as DirectionalLight3D
	_env = get_node_or_null(world_env_path) as WorldEnvironment
	EventBus.quality_changed.connect(_on_quality)
	_on_quality(QualityManager.active)

func _on_quality(p: QualityPreset) -> void:
	if p == null:
		return
	if _sun != null:
		_sun.shadow_enabled = p.shadows_enabled
		_sun.directional_shadow_max_distance = p.shadow_max_distance
	if _env != null and _env.environment != null:
		_env.environment.fog_depth_end = p.fog_end
