extends Control
## Right zone: drag to look. Feeds InputRouter.add_look. Touch + mouse.
## Faint hint text so the player knows it is a camera area.

var _id := -1
var _last := Vector2.ZERO
var _hint_t := 6.0

func _ready() -> void:
	queue_redraw()

func _router():
	return Services.input_router

func _process(d: float) -> void:
	if _hint_t > 0.0:
		_hint_t -= d
		if _hint_t <= 0.0:
			queue_redraw()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed and _id == -1:
			_id = e.index
			_last = e.position
			_hint_t = 0.0
			queue_redraw()
		elif not e.pressed and e.index == _id:
			_id = -1
	elif e is InputEventScreenDrag and e.index == _id:
		var r = _router()
		if r != null:
			r.add_look(e.position - _last)
		_last = e.position
	elif e is InputEventMouseButton:
		if e.pressed and _id == -1:
			_id = -2
			_last = e.position
		elif not e.pressed and _id == -2:
			_id = -1
	elif e is InputEventMouseMotion and _id == -2:
		var r2 = _router()
		if r2 != null:
			r2.add_look(e.position - _last)
		_last = e.position

func _draw() -> void:
	if _hint_t > 0.0:
		var r := get_rect()
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(r.size.x * 0.5 - 90.0, r.size.y * 0.5),
			"KAMERA: sürükle", HORIZONTAL_ALIGNMENT_CENTER, 220.0, 22,
			Color(1, 1, 1, 0.35))
