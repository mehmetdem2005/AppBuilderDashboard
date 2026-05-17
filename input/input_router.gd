class_name InputRouter
extends Node
## The single input abstraction. Touch controls + keyboard/gamepad all funnel
## here; the rest of the game only ever reads InputIntent / look delta.
## SP, future MP and replay all consume the SAME InputIntent.

var _move := Vector2.ZERO          # set by TouchJoystick (or keyboard)
var _look_accum := Vector2.ZERO    # set by TouchLookPad (or mouse)
var _actions := 0
var _camera_cycle := false
var _test_move := Vector2.ZERO
var _test_active := false

func _ready() -> void:
	Services.input_router = self

# ---- called by touch Controls ----
func set_move_vector(v: Vector2) -> void:
	_move = v

func add_look(delta: Vector2) -> void:
	_look_accum += delta

func set_action(bit: int, pressed: bool) -> void:
	if pressed: _actions |= bit
	else: _actions &= ~bit

func request_camera_cycle() -> void:
	_camera_cycle = true

# ---- test hooks (headless) ----
func set_test_move(v: Vector2) -> void:
	_test_move = v
	_test_active = true

func _keyboard_move() -> Vector2:
	return Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

# ---- consumers ----
func get_look_delta() -> Vector2:
	var l := _look_accum * Settings.look_sensitivity * 0.01
	_look_accum = Vector2.ZERO
	return l

func consume_camera_cycle() -> bool:
	var c := _camera_cycle
	_camera_cycle = false
	return c

func consume_intent() -> InputIntent:
	var it := InputIntent.new()
	var m := _move
	if _test_active:
		m = _test_move
	elif m == Vector2.ZERO:
		m = _keyboard_move()
	it.move = m.limit_length(1.0)
	it.actions = _actions
	return it
