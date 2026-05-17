class_name SimClock
extends RefCounted
## Fixed-timestep accumulator (30 Hz). Decouples simulation from render FPS:
## keeps physics/gameplay deterministic and stable under thermal throttling,
## and is the foundation for future multiplayer. Render interpolates via alpha.

const SIM_HZ := 30.0
const SIM_DT := 1.0 / SIM_HZ
const MAX_STEPS := 5                     # spiral-of-death guard

var _accum := 0.0

## Returns number of fixed steps to run this frame.
func advance(frame_delta: float) -> int:
	_accum += minf(frame_delta, 0.25)
	var steps := 0
	while _accum >= SIM_DT and steps < MAX_STEPS:
		_accum -= SIM_DT
		steps += 1
	if steps == MAX_STEPS:
		_accum = 0.0                      # drop backlog, never spiral
	return steps

## 0..1 blend factor between previous and current sim state for rendering.
func alpha() -> float:
	return clampf(_accum / SIM_DT, 0.0, 1.0)
