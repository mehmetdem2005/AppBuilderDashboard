class_name CameraRig
extends Node3D
## Owns the single Camera3D. Live-switchable rig state machine with a smooth
## blend (no snap). Look input comes ONLY from InputRouter (never raw Input).

enum Mode { THIRD, FIRST, TOP }
const BLEND := 0.25
const PITCH_MIN := -1.15
const PITCH_MAX := 1.15

var cam: Camera3D
var mode: int = Mode.THIRD
var yaw := 0.0
var pitch := -0.25
var _states := {}
var _state: CameraRigState
var _blend_from: Transform3D
var _blend_t := 1.0

func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 60.0
	cam.far = 4000.0
	cam.current = true
	add_child(cam)
	_states = {
		Mode.THIRD: ThirdPersonRig.new(),
		Mode.FIRST: FirstPersonRig.new(),
		Mode.TOP: TopDownRig.new(),
	}
	mode = clampi(Settings.camera_default_mode, 0, 2)
	_state = _states[mode]
	_state.enter()
	Services.camera_rig = self
	EventBus.quality_changed.connect(_on_quality)
	_on_quality(QualityManager.active)

func _on_quality(p: QualityPreset) -> void:
	if p == null or cam == null:
		return
	get_viewport().scaling_3d_scale = p.render_scale

func set_mode(m: int) -> void:
	m = clampi(m, 0, 2)
	if m == mode:
		return
	_state.exit()
	mode = m
	_state = _states[mode]
	_state.enter()
	_blend_from = cam.global_transform
	_blend_t = 0.0
	EventBus.camera_mode_changed.emit(mode)

func cycle_mode() -> void:
	set_mode((mode + 1) % 3)

func get_move_yaw() -> float:
	return _state.move_yaw(yaw)

func _target_pos() -> Vector3:
	if Services.character != null:
		return Services.character.global_position
	return Vector3.ZERO

func _process(delta: float) -> void:
	var router = Services.input_router
	if router != null:
		var lk: Vector2 = router.get_look_delta()
		yaw -= lk.x
		var iy := -1.0 if Settings.invert_look_y else 1.0
		pitch = clampf(pitch + lk.y * iy, PITCH_MIN, PITCH_MAX)
		if router.consume_camera_cycle():
			cycle_mode()

	cam.projection = (Camera3D.PROJECTION_ORTHOGONAL
		if _state.projection_is_ortho() else Camera3D.PROJECTION_PERSPECTIVE)
	if _state.projection_is_ortho():
		cam.size = _state.ortho_size()

	var goal := _state.desired(_target_pos(), yaw, pitch)
	if _blend_t < 1.0:
		_blend_t = minf(1.0, _blend_t + delta / BLEND)
		cam.global_transform = _blend_from.interpolate_with(goal, _blend_t)
	else:
		cam.global_transform = goal
