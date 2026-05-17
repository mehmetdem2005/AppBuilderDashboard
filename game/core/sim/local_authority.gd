class_name LocalAuthority
extends IAuthority
## Single-player authority: intent comes from local InputRouter, the sim is
## advanced locally. Same interface a future NetAuthority will satisfy.

var _tick := 0
var _motor: CharacterMotor

func _init(terrain: TerrainData) -> void:
	_motor = CharacterMotor.new()
	_motor.terrain = terrain

func is_local_authority() -> bool:
	return true

func tick_index() -> int:
	return _tick

func gather_intent() -> InputIntent:
	var router = Services.input_router
	if router == null:
		return InputIntent.new()
	return router.consume_intent()

func apply_tick(world: SimWorld, intent: InputIntent, dt: float) -> void:
	var move_yaw := 0.0
	var rig = Services.camera_rig
	if rig != null:
		move_yaw = rig.get_move_yaw()
	_motor.step(world.player, intent, move_yaw, dt)
	_tick += 1
	world.tick = _tick
