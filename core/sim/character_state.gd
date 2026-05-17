class_name CharacterState
extends RefCounted
## Replicable / serialisable character state. No Nodes. Feeds save & future net.

var position: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
var yaw: float = 0.0
var grounded: bool = false

func to_dict() -> Dictionary:
	return {
		"px": position.x, "py": position.y, "pz": position.z,
		"yaw": yaw,
	}

func from_dict(d: Dictionary) -> void:
	position = Vector3(d.get("px", 0.0), d.get("py", 0.0), d.get("pz", 0.0))
	yaw = d.get("yaw", 0.0)
	velocity = Vector3.ZERO
	grounded = false

func clone() -> CharacterState:
	var c := CharacterState.new()
	c.position = position
	c.velocity = velocity
	c.yaw = yaw
	c.grounded = grounded
	return c
