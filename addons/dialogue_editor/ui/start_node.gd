@tool
class_name DialogueStartNode
extends GraphNode

var node_id: String = ""

func _init() -> void:
	title = "Start"
	var label := Label.new()
	label.text = "→ Diyalog başlangıcı"
	add_child(label)
	# Tek sağ (çıkış) port. Sol giriş yok.
	set_slot(0, false, 0, Color.WHITE, true, 0, Color(0.4, 0.8, 1.0))

func get_data() -> Dictionary:
	return {
		"id": node_id,
		"type": "start",
		"position_x": position_offset.x,
		"position_y": position_offset.y,
	}

func apply_data(d: Dictionary) -> void:
	node_id = String(d.get("id", node_id))
	position_offset = Vector2(
		float(d.get("position_x", 0.0)),
		float(d.get("position_y", 0.0))
	)
