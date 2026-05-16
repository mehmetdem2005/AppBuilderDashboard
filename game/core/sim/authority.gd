class_name IAuthority
extends RefCounted
## Abstract authority interface. Gameplay talks ONLY to this — never to
## networking. LocalAuthority (SP) implements it now; NetAuthority (MP)
## will implement the same contract later with zero gameplay changes.

func is_local_authority() -> bool:
	return true

func tick_index() -> int:
	return 0

## Returns the InputIntent that should drive the sim for this tick.
func gather_intent() -> InputIntent:
	return InputIntent.new()

## Advance authoritative state by one fixed sim step.
func apply_tick(_world: SimWorld, _intent: InputIntent, _dt: float) -> void:
	pass
