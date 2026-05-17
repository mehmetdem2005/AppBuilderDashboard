class_name SettingsMenu
extends Control
## Placeholder settings panel (live quality/control config lands here).
## Kept thin & data-driven; expanded when UI art is provided.

func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
