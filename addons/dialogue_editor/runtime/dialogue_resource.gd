@tool
class_name DialogueResource
extends Resource

## Diyalog ağacının serileştirilebilir gösterimi.
## nodes: her biri {id, type, speaker, text, choices, position_x, position_y}
## connections: her biri {from_id, from_port, to_id}

@export var start_id: String = ""
@export var nodes: Array = []
@export var connections: Array = []

func to_dict() -> Dictionary:
	return {
		"start_id": start_id,
		"nodes": nodes,
		"connections": connections,
	}

func to_json() -> String:
	return JSON.stringify(to_dict(), "\t")

static func from_dict(data: Dictionary) -> DialogueResource:
	var res := DialogueResource.new()
	res.start_id = data.get("start_id", "")
	res.nodes = data.get("nodes", [])
	res.connections = data.get("connections", [])
	return res

static func from_json(text: String) -> DialogueResource:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	return from_dict(parsed)
