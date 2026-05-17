extends Control
## Virtual joystick (left by default). Fully data-driven from Settings
## (side / size / opacity). Feeds InputRouter.set_move_vector.

var _radius := 90.0
var _touch_id := -1
var _center := Vector2.ZERO
var _knob := Vector2.ZERO
var _router: InputRouter

func _ready() -> void:
	_router = Services.input_router
	_apply_settings()
	mouse_filter = Control.MOUSE_FILTER_PASS

func _apply_settings() -> void:
	_radius = Settings.joystick_size * 0.5
	modulate.a = Settings.joystick_opacity
	var vp := get_viewport_rect().size
	var y := vp.y - _radius - 60.0
	var x := (_radius + 60.0) if Settings.joystick_on_left else (vp.x - _radius - 60.0)
	_center = Vector2(x, y)
	_knob = _center
	queue_redraw()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed and _touch_id == -1:
			_touch_id = e.index
			_center = e.position
			_knob = e.position
		elif not e.pressed and e.index == _touch_id:
			_touch_id = -1
			_knob = _center
			if _router: _router.set_move_vector(Vector2.ZERO)
		queue_redraw()
	elif e is InputEventScreenDrag and e.index == _touch_id:
		var off: Vector2 = e.position - _center
		if off.length() > _radius:
			off = off.normalized() * _radius
		_knob = _center + off
		if _router:
			_router.set_move_vector(off / _radius)
		queue_redraw()

func _draw() -> void:
	draw_circle(_center, _radius, Color(1, 1, 1, 0.18))
	draw_circle(_knob, _radius * 0.42, Color(1, 1, 1, 0.35))
