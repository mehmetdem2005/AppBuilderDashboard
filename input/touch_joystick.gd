extends Control
## Dynamic virtual joystick on the left zone. Always-visible resting pad;
## touch anywhere in the zone re-centres it. Feeds InputRouter.set_move_vector.
## Works with touch AND mouse (editor/desktop testing).

var _radius := 95.0
var _dead := 0.12
var _active := false
var _touch_id := -1
var _center := Vector2.ZERO
var _knob := Vector2.ZERO

func _ready() -> void:
	_radius = clampf(Settings.joystick_size * 0.5, 70.0, 150.0)
	_reset_rest()
	resized.connect(_reset_rest)
	set_process(false)

func _router():
	return Services.input_router

func _reset_rest() -> void:
	var r := get_rect()
	_center = Vector2(r.size.x * 0.42, r.size.y - _radius - 90.0)
	_knob = _center
	queue_redraw()

func _begin(pos: Vector2) -> void:
	_active = true
	_center = pos
	_knob = pos
	queue_redraw()

func _move(pos: Vector2) -> void:
	var off := pos - _center
	if off.length() > _radius:
		off = off.normalized() * _radius
	_knob = _center + off
	var v := off / _radius
	if v.length() < _dead:
		v = Vector2.ZERO
	var r = _router()
	if r != null:
		r.set_move_vector(v)
	queue_redraw()

func _end() -> void:
	_active = false
	var r = _router()
	if r != null:
		r.set_move_vector(Vector2.ZERO)
	_reset_rest()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed and _touch_id == -1:
			_touch_id = e.index
			_begin(e.position)
		elif not e.pressed and e.index == _touch_id:
			_touch_id = -1
			_end()
	elif e is InputEventScreenDrag and e.index == _touch_id:
		_move(e.position)
	elif e is InputEventMouseButton:
		if e.pressed and _touch_id == -1:
			_touch_id = -2
			_begin(e.position)
		elif not e.pressed and _touch_id == -2:
			_touch_id = -1
			_end()
	elif e is InputEventMouseMotion and _touch_id == -2:
		_move(e.position)

func _draw() -> void:
	var base_col := Color(1, 1, 1, 0.16 if not _active else 0.24)
	var knob_col := Color(1, 1, 1, 0.30 if not _active else 0.45)
	draw_circle(_center, _radius, base_col)
	draw_arc(_center, _radius, 0.0, TAU, 48, Color(1, 1, 1, 0.30), 2.0)
	draw_circle(_knob, _radius * 0.42, knob_col)
