class_name CharacterMotor
extends RefCounted
## Deterministic movement solver. Identical math in SP/MP/replay.
## Operates on CharacterState only; terrain queried read-only for ground.
## Real (collision-mesh) resolution happens in AnimalCharacter via the
## streamed collision chunks; this provides prediction + ground clamp so the
## sim stays stable even before a far collision cell has streamed in.

const SPEED := 9.0
const SPRINT := 16.0
const ACCEL := 12.0
const GRAVITY := 24.0
const JUMP_V := 9.0

var terrain: TerrainData

func step(s: CharacterState, intent: InputIntent, move_yaw: float, dt: float) -> void:
	# camera-relative planar move
	var f := Vector3(sin(move_yaw), 0.0, cos(move_yaw))
	var r := Vector3(f.z, 0.0, -f.x)
	var wish := (f * -intent.move.y + r * intent.move.x)
	if wish.length() > 1.0:
		wish = wish.normalized()
	var target_speed := SPRINT if intent.has(InputIntent.ACT_SPRINT) else SPEED
	var desired := wish * target_speed

	var v := s.velocity
	v.x = move_toward(v.x, desired.x, ACCEL * target_speed * dt / max(target_speed, 1.0) * 4.0)
	v.z = move_toward(v.z, desired.z, ACCEL * target_speed * dt / max(target_speed, 1.0) * 4.0)

	var ground_y := 0.0
	if terrain != null and terrain.loaded:
		ground_y = terrain.height(s.position.x, s.position.z)

	if s.grounded and intent.has(InputIntent.ACT_JUMP):
		v.y = JUMP_V
		s.grounded = false
	else:
		v.y -= GRAVITY * dt

	var p := s.position + v * dt

	if p.y <= ground_y + 0.01:
		p.y = ground_y
		v.y = 0.0
		s.grounded = true
	else:
		s.grounded = false

	if terrain != null:
		p = terrain.clamp_to_world(p)

	s.position = p
	s.velocity = v
	if wish.length() > 0.05:
		s.yaw = atan2(wish.x, wish.z)
