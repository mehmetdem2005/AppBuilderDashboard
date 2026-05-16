@tool
class_name DialogueChoiceNode
extends GraphNode

## Birden çok seçenek; her seçenek ayrı bir sağ çıkış portu.
## Çıkış port index'i = seçenek index'i (0-tabanlı).

var node_id: String = ""
var _text: TextEdit = null
var _choices: Array = []  # Array[LineEdit]

func _init() -> void:
	title = "Seçim"
	custom_minimum_size = Vector2(260, 0)

	_text = TextEdit.new()
	_text.placeholder_text = "Soru / metin..."
	_text.custom_minimum_size = Vector2(0, 70)
	_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	add_child(_text)  # child 0

	var add_btn := Button.new()
	add_btn.text = "+ Seçenek Ekle"
	add_btn.pressed.connect(_on_add_choice)
	add_child(add_btn)  # child 1

	# slot 0 (metin satırı): sadece sol giriş
	set_slot(0, true, 0, Color(0.4, 0.8, 1.0), false, 0, Color.WHITE)
	# slot 1 (ekle butonu): port yok
	set_slot(1, false, 0, Color.WHITE, false, 0, Color.WHITE)

	_add_choice("")

func _on_add_choice() -> void:
	_add_choice("")

func _add_choice(text: String) -> void:
	var le := LineEdit.new()
	le.placeholder_text = "Seçenek %d" % (_choices.size() + 1)
	le.text = text
	add_child(le)
	_choices.append(le)
	_refresh_slots()

func _refresh_slots() -> void:
	# child sırası: 0=metin, 1=ekle butonu, 2.. = seçenekler
	for i in range(_choices.size()):
		var child_index := 2 + i
		set_slot(child_index, false, 0, Color.WHITE, true, 0, Color(1.0, 0.8, 0.4))

func get_data() -> Dictionary:
	var opts: Array = []
	for le in _choices:
		opts.append(le.text)
	return {
		"id": node_id,
		"type": "choice",
		"text": _text.text,
		"choices": opts,
		"position_x": position_offset.x,
		"position_y": position_offset.y,
	}

func apply_data(d: Dictionary) -> void:
	node_id = String(d.get("id", node_id))
	_text.text = String(d.get("text", ""))
	for le in _choices:
		le.queue_free()
	_choices.clear()
	var opts: Array = d.get("choices", [])
	if opts.is_empty():
		_add_choice("")
	else:
		for o in opts:
			_add_choice(String(o))
	position_offset = Vector2(
		float(d.get("position_x", 0.0)),
		float(d.get("position_y", 0.0))
	)
