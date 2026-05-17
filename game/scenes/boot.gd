extends Node
## Thin entry point: hand control to the app state machine. No data here.

func _ready() -> void:
	GameRoot.boot_into_game.call_deferred()
