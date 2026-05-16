extends Control
## Right-half drag -> camera look delta. Feeds InputRouter.add_look.

var _id := -1
var _last := Vector2.ZERO
var _router: InputRouter

func _ready() -> void:
	_router = Services.input_router
	mouse_filter = Control.MOUSE_FILTER_PASS

func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed and _id == -1:
			_id = e.index
			_last = e.position
		elif not e.pressed and e.index == _id:
			_id = -1
	elif e is InputEventScreenDrag and e.index == _id:
		if _router:
			_router.add_look(e.position - _last)
		_last = e.position
