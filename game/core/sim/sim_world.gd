class_name SimWorld
extends RefCounted
## Pure simulation state container (no Nodes, no rendering).
## Serialisable -> drives save/load AND future network replication.

var tick: int = 0
var seed: int = 12345
var region_id: StringName = &"default"
var player: CharacterState = CharacterState.new()

func to_dict() -> Dictionary:
	return {
		"tick": tick,
		"seed": seed,
		"region_id": String(region_id),
		"player": player.to_dict(),
	}

func from_dict(d: Dictionary) -> void:
	tick = int(d.get("tick", 0))
	seed = int(d.get("seed", 12345))
	region_id = StringName(d.get("region_id", "default"))
	player.from_dict(d.get("player", {}))
