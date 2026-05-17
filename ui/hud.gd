class_name GameHud
extends Control
## Touch HUD built in code (no baked layout). Non-overlapping zones:
## left half = movement joystick, right half = camera look. Buttons on top.

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# right half: camera look pad
	var look := Control.new()
	look.set_script(load("res://input/touch_look_pad.gd"))
	look.anchor_left = 0.5
	look.anchor_top = 0.0
	look.anchor_right = 1.0
	look.anchor_bottom = 1.0
	look.offset_left = 0.0
	look.offset_right = 0.0
	look.offset_top = 0.0
	look.offset_bottom = 0.0
	look.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(look)

	# left half: virtual joystick
	var joy := Control.new()
	joy.set_script(load("res://input/touch_joystick.gd"))
	joy.anchor_left = 0.0
	joy.anchor_top = 0.0
	joy.anchor_right = 0.5
	joy.anchor_bottom = 1.0
	joy.offset_left = 0.0
	joy.offset_right = 0.0
	joy.offset_top = 0.0
	joy.offset_bottom = 0.0
	joy.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(joy)

	# top-right buttons (drawn over the zones)
	var cam_btn := Button.new()
	cam_btn.text = "Kamera"
	cam_btn.anchor_left = 1.0
	cam_btn.anchor_right = 1.0
	cam_btn.offset_left = -150.0
	cam_btn.offset_top = 20.0
	cam_btn.offset_right = -20.0
	cam_btn.offset_bottom = 84.0
	cam_btn.pressed.connect(func():
		if Services.input_router != null:
			Services.input_router.request_camera_cycle())
	add_child(cam_btn)

	var pause_btn := Button.new()
	pause_btn.text = "II"
	pause_btn.anchor_left = 1.0
	pause_btn.anchor_right = 1.0
	pause_btn.offset_left = -150.0
	pause_btn.offset_top = 96.0
	pause_btn.offset_right = -86.0
	pause_btn.offset_bottom = 160.0
	add_child(pause_btn)
	var pause := PauseMenu.new()
	add_child(pause)
	pause_btn.pressed.connect(pause.open)

	var perf := PerfOverlay.new()
	add_child(perf)
