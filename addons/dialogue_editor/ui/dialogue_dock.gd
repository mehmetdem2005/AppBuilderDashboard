@tool
extends Control

const DialogueResourceScript := preload("res://addons/dialogue_editor/runtime/dialogue_resource.gd")
const StartNode := preload("res://addons/dialogue_editor/ui/start_node.gd")
const LineNode := preload("res://addons/dialogue_editor/ui/line_node.gd")
const ChoiceNode := preload("res://addons/dialogue_editor/ui/choice_node.gd")

enum FileMode { SAVE_TRES, LOAD_TRES, EXPORT_JSON }

var _graph: GraphEdit = null
var _status: Label = null
var _file_dialog: FileDialog = null
var _id_counter: int = 0
var _file_mode: int = FileMode.SAVE_TRES

func _init() -> void:
	name = "DialogueDock"
	custom_minimum_size = Vector2(0, 320)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	var toolbar := HBoxContainer.new()
	vbox.add_child(toolbar)

	_add_tool_button(toolbar, "+ Start", _add_start)
	_add_tool_button(toolbar, "+ Replik", _add_line)
	_add_tool_button(toolbar, "+ Seçim", _add_choice)
	toolbar.add_child(VSeparator.new())
	_add_tool_button(toolbar, "Kaydet (.tres)", _on_save)
	_add_tool_button(toolbar, "Yükle (.tres)", _on_load)
	_add_tool_button(toolbar, "JSON Export", _on_json)
	toolbar.add_child(VSeparator.new())
	_add_tool_button(toolbar, "Temizle", _clear_graph)

	_status = Label.new()
	_status.text = "Hazır."
	toolbar.add_child(_status)

	_graph = GraphEdit.new()
	_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_graph.right_disconnects = true
	_graph.connection_request.connect(_on_connection_request)
	_graph.disconnection_request.connect(_on_disconnection_request)
	vbox.add_child(_graph)

	_file_dialog = FileDialog.new()
	_file_dialog.access = FileDialog.ACCESS_RESOURCES
	_file_dialog.file_selected.connect(_on_file_selected)
	add_child(_file_dialog)

func _add_tool_button(parent: Control, text: String, handler: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.pressed.connect(handler)
	parent.add_child(btn)

func _next_id(prefix: String) -> String:
	_id_counter += 1
	return "%s_%d" % [prefix, _id_counter]

func _spawn(node: GraphNode, id: String) -> void:
	node.set("node_id", id)
	node.name = id
	node.position_offset = _graph.scroll_offset + Vector2(80, 80)
	_graph.add_child(node)

func _add_start() -> void:
	for c in _graph.get_children():
		if c is StartNode:
			_set_status("Zaten bir Start node var.")
			return
	_spawn(StartNode.new(), _next_id("start"))

func _add_line() -> void:
	_spawn(LineNode.new(), _next_id("line"))

func _add_choice() -> void:
	_spawn(ChoiceNode.new(), _next_id("choice"))

func _clear_graph() -> void:
	_graph.clear_connections()
	for c in _graph.get_children():
		if c is GraphNode:
			c.queue_free()
	_id_counter = 0
	_set_status("Graf temizlendi.")

# --- Bağlantı yönetimi ---

func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	_graph.connect_node(from_node, from_port, to_node, to_port)

func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	_graph.disconnect_node(from_node, from_port, to_node, to_port)

# --- Serileştirme ---

func _build_resource() -> DialogueResource:
	var res := DialogueResourceScript.new()
	var nodes: Array = []
	for c in _graph.get_children():
		if c is GraphNode and c.has_method("get_data"):
			var d: Dictionary = c.get_data()
			nodes.append(d)
			if c is StartNode:
				res.start_id = String(d.get("id", ""))
	res.nodes = nodes

	var conns: Array = []
	for con in _graph.get_connection_list():
		conns.append({
			"from_id": String(con["from_node"]),
			"from_port": int(con["from_port"]),
			"to_id": String(con["to_node"]),
		})
	res.connections = conns
	return res

func _load_resource(res: DialogueResource) -> void:
	_clear_graph()
	var max_counter: int = 0
	for nd in res.nodes:
		var t: String = String(nd.get("type", ""))
		var node: GraphNode = null
		match t:
			"start":
				node = StartNode.new()
			"line":
				node = LineNode.new()
			"choice":
				node = ChoiceNode.new()
			_:
				continue
		var id: String = String(nd.get("id", ""))
		node.name = id
		_graph.add_child(node)
		node.call("apply_data", nd)
		max_counter = max(max_counter, _id_suffix(id))
	_id_counter = max_counter

	for con in res.connections:
		_graph.connect_node(
			StringName(String(con.get("from_id", ""))),
			int(con.get("from_port", 0)),
			StringName(String(con.get("to_id", ""))),
			0
		)
	_set_status("Yüklendi: %d node." % res.nodes.size())

func _id_suffix(id: String) -> int:
	var parts := id.split("_")
	if parts.size() >= 2 and parts[parts.size() - 1].is_valid_int():
		return parts[parts.size() - 1].to_int()
	return 0

# --- Dosya iletişim kutusu ---

func _on_save() -> void:
	_file_mode = FileMode.SAVE_TRES
	_file_dialog.access = FileDialog.ACCESS_RESOURCES
	_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_file_dialog.filters = PackedStringArray(["*.tres ; Dialogue Resource"])
	_file_dialog.current_file = "dialogue.tres"
	_file_dialog.popup_centered_ratio(0.6)

func _on_load() -> void:
	_file_mode = FileMode.LOAD_TRES
	_file_dialog.access = FileDialog.ACCESS_RESOURCES
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.filters = PackedStringArray(["*.tres ; Dialogue Resource"])
	_file_dialog.popup_centered_ratio(0.6)

func _on_json() -> void:
	_file_mode = FileMode.EXPORT_JSON
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_file_dialog.filters = PackedStringArray(["*.json ; JSON"])
	_file_dialog.current_file = "dialogue.json"
	_file_dialog.popup_centered_ratio(0.6)

func _on_file_selected(path: String) -> void:
	match _file_mode:
		FileMode.SAVE_TRES:
			var res := _build_resource()
			var err := ResourceSaver.save(res, path)
			_set_status("Kaydedildi: %s" % path if err == OK else "Kaydetme hatası (%d)" % err)
		FileMode.LOAD_TRES:
			var loaded: Resource = ResourceLoader.load(path)
			if loaded is DialogueResource:
				_load_resource(loaded)
			else:
				_set_status("Geçersiz DialogueResource.")
		FileMode.EXPORT_JSON:
			var res2 := _build_resource()
			var f := FileAccess.open(path, FileAccess.WRITE)
			if f:
				f.store_string(res2.to_json())
				f.close()
				_set_status("JSON yazıldı: %s" % path)
			else:
				_set_status("JSON yazma hatası.")

func _set_status(msg: String) -> void:
	if _status:
		_status.text = msg
