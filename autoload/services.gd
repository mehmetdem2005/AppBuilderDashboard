extends Node
## Lightweight service locator. Runtime systems register themselves here so
## nothing couples by hard node path. Cleared on game teardown.

var world_streamer: Node = null
var camera_rig: Node = null
var input_router: Node = null
var character: Node = null
var authority: RefCounted = null
var sim_world: RefCounted = null

func clear() -> void:
	world_streamer = null
	camera_rig = null
	input_router = null
	character = null
	authority = null
	sim_world = null
