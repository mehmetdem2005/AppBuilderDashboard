class_name GameHud
extends Control
## Builds the touch HUD in code (thin scene, no baked layout/data):
## left joystick, right look pad, camera-switch + pause buttons, perf overlay.

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vp := get_viewport_rect().size

	# right-half look pad (under the buttons)
	var look := Control.new()
	look.set_script(load("res://input/touch_look_pad.gd"))
	look.set_anchors_preset(Control.PRESET_FULL_RECT)
	look.anchor_left = 0.5
	look.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(look)

	# left virtual joystick (full rect, draws/handles its own area)
	var joy := Control.new()
	joy.set_script(load("res://input/touch_joystick.gd"))
	joy.set_anchors_preset(Control.PRESET_FULL_RECT)
	joy.anchor_right = 0.5
	joy.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(joy)

	# camera switch button
	var camb := Button.new()
	camb.text = "Kamera"
	camb.custom_minimum_size = Vector2(120, 56)
	camb.position = Vector2(vp.x - 140, 20)
	camb.pressed.connect(func():
		if Services.input_router != null:
			Services.input_router.request_camera_cycle())
	add_child(camb)

	# pause button
	var pb := Button.new()
	pb.text = "II"
	pb.custom_minimum_size = Vector2(56, 56)
	pb.position = Vector2(vp.x - 140, 86)
	add_child(pb)
	var pause := PauseMenu.new()
	add_child(pause)
	pb.pressed.connect(pause.open)

	var perf := PerfOverlay.new()
	add_child(perf)
