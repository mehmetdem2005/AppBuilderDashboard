@tool
class_name DialogueLineNode
extends GraphNode

var node_id: String = ""
var _speaker: LineEdit = null
var _text: TextEdit = null

func _init() -> void:
	title = "Replik"
	custom_minimum_size = Vector2(240, 0)

	_speaker = LineEdit.new()
	_speaker.placeholder_text = "Konuşmacı"
	add_child(_speaker)

	_text = TextEdit.new()
	_text.placeholder_text = "Replik metni..."
	_text.custom_minimum_size = Vector2(0, 80)
	_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	add_child(_text)

	# slot 0 (konuşmacı satırı): sol giriş portu
	set_slot(0, true, 0, Color(0.4, 0.8, 1.0), false, 0, Color.WHITE)
	# slot 1 (metin satırı): sağ çıkış portu
	set_slot(1, false, 0, Color.WHITE, true, 0, Color(0.4, 0.8, 1.0))

func get_data() -> Dictionary:
	return {
		"id": node_id,
		"type": "line",
		"speaker": _speaker.text,
		"text": _text.text,
		"position_x": position_offset.x,
		"position_y": position_offset.y,
	}

func apply_data(d: Dictionary) -> void:
	node_id = String(d.get("id", node_id))
	_speaker.text = String(d.get("speaker", ""))
	_text.text = String(d.get("text", ""))
	position_offset = Vector2(
		float(d.get("position_x", 0.0)),
		float(d.get("position_y", 0.0))
	)
