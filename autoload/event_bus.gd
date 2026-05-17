extends Node
## Global, typed signal hub. ONLY signal declarations — no logic, no state.
## Every cross-module message goes through here so nothing couples by node path.

signal region_load_requested(region_id: StringName)
signal region_activated(region_id: StringName)

signal quality_changed(preset: Resource)            # QualityPreset
signal quality_step(direction: int)                 # -1 down / +1 up

signal camera_mode_changed(mode: int)

signal save_completed(slot: int)
signal save_failed(slot: int, reason: String)
signal load_completed(slot: int)

signal streaming_idle(is_idle: bool)
signal streaming_budget_exceeded(kind: int)         # 0 visual / 1 collision / 2 prop

signal asset_missing(id: StringName)

signal game_state_changed(state: int)

# Smoke/diagnostics: any script error routed here so tests can assert "clean".
signal diagnostic_error(where: String, message: String)

func report_error(where: String, message: String) -> void:
	push_error("[%s] %s" % [where, message])
	diagnostic_error.emit(where, message)
