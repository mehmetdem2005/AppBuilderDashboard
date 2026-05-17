class_name PauseMenu
extends Control
## Minimal pause overlay. Pure UI; reads/writes nothing baked.

var _box: VBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	_box = VBoxContainer.new()
	_box.set_anchors_preset(Control.PRESET_CENTER)
	_box.add_theme_constant_override("separation", 14)
	add_child(_box)
	_btn("Devam", _resume)
	_btn("Kaydet", _save)
	_btn("Kalite: " + String(Settings.quality_preset_id), _cycle_quality)

func _btn(txt: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(260, 56)
	b.pressed.connect(cb)
	_box.add_child(b)
	return b

func open() -> void:
	visible = true
	GameRoot.set_paused(true)

func _resume() -> void:
	visible = false
	GameRoot.set_paused(false)

func _save() -> void:
	if Services.sim_world != null:
		SaveSystem.save_game(0, Services.sim_world)

func _cycle_quality() -> void:
	var order := [&"ultra_low", &"low", &"medium"]
	var i := order.find(Settings.quality_preset_id)
	var nxt: StringName = order[(i + 1) % order.size()]
	QualityManager.set_preset(nxt)
	_box.get_child(2).text = "Kalite: " + String(nxt)
