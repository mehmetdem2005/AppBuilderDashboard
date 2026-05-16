@tool
extends EditorPlugin

const DialogueDock := preload("res://addons/dialogue_editor/ui/dialogue_dock.gd")

var _dock: Control = null

func _enter_tree() -> void:
	_dock = DialogueDock.new()
	add_control_to_bottom_panel(_dock, "Diyalog")

func _exit_tree() -> void:
	if _dock:
		remove_control_from_bottom_panel(_dock)
		_dock.queue_free()
		_dock = null
