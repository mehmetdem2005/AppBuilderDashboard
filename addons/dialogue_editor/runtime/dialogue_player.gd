class_name DialoguePlayer
extends Node

## Çalışma anında bir DialogueResource'u oynatır.
## Kullanım:
##   var p := DialoguePlayer.new()
##   add_child(p)
##   p.line_shown.connect(...)
##   p.choices_shown.connect(...)
##   p.finished.connect(...)
##   p.start(my_dialogue_resource)
##   # line_shown sonrası: p.advance()
##   # choices_shown sonrası: p.choose(secilen_index)

signal line_shown(speaker: String, text: String)
signal choices_shown(text: String, options: Array)
signal finished()

var _resource: DialogueResource = null
var _nodes_by_id: Dictionary = {}
var _current_id: String = ""

func start(resource: DialogueResource) -> void:
	_resource = resource
	_nodes_by_id.clear()
	for n in resource.nodes:
		_nodes_by_id[n.get("id", "")] = n
	_current_id = resource.start_id
	_process_current()

func advance() -> void:
	# Bir line_shown sinyalinden sonra çağrılır.
	_current_id = _next_id(_current_id, 0)
	_process_current()

func choose(index: int) -> void:
	# Bir choices_shown sinyalinden sonra seçilen seçeneğin index'i ile çağrılır.
	_current_id = _next_id(_current_id, index)
	_process_current()

func _process_current() -> void:
	if _current_id == "" or not _nodes_by_id.has(_current_id):
		finished.emit()
		return
	var node: Dictionary = _nodes_by_id[_current_id]
	match String(node.get("type", "")):
		"start":
			_current_id = _next_id(_current_id, 0)
			_process_current()
		"line":
			line_shown.emit(String(node.get("speaker", "")), String(node.get("text", "")))
		"choice":
			choices_shown.emit(String(node.get("text", "")), node.get("choices", []))
		_:
			finished.emit()

func _next_id(from_id: String, port: int) -> String:
	if _resource == null:
		return ""
	for c in _resource.connections:
		if String(c.get("from_id", "")) == from_id and int(c.get("from_port", 0)) == port:
			return String(c.get("to_id", ""))
	return ""
