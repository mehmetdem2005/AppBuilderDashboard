class_name InputIntent
extends RefCounted
## One frame of abstracted intent. The ONLY thing gameplay/camera consume.
## Same struct flows in SP, future MP, and deterministic replay.

const ACT_JUMP := 1 << 0
const ACT_INTERACT := 1 << 1
const ACT_SPRINT := 1 << 2

var move: Vector2 = Vector2.ZERO        # -1..1 (planar, camera-relative)
var look: Vector2 = Vector2.ZERO        # delta this frame
var actions: int = 0                    # bitmask of ACT_*
var camera_cycle: bool = false

func has(action: int) -> bool:
	return (actions & action) != 0

func clone() -> InputIntent:
	var c := InputIntent.new()
	c.move = move
	c.look = look
	c.actions = actions
	c.camera_cycle = camera_cycle
	return c
