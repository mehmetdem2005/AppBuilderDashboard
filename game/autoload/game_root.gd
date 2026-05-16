extends Node
## Top-level application state machine. The ONLY place scenes are changed.
## Owns the fixed-step simulation loop (decoupled from render) and drives the
## adaptive quality controller while in game.

enum State { BOOT, MENU, LOADING, IN_GAME, PAUSED }

const GAME_SCENE := "res://scenes/Game.tscn"

var state: int = State.BOOT
var sim_clock: SimClock
var sim_world: SimWorld
var authority: IAuthority
var terrain: TerrainData

func _ready() -> void:
	sim_clock = SimClock.new()
	process_mode = Node.PROCESS_MODE_ALWAYS

func boot_into_game() -> void:
	_set_state(State.LOADING)
	terrain = TerrainData.new()
	if not terrain.load_from(Settings.terrain_dir):
		EventBus.report_error("GameRoot",
			"Arazi yüklenemedi: " + Settings.terrain_dir)
		# still continue: streamer guards against unloaded terrain
	sim_world = SimWorld.new()
	authority = LocalAuthority.new(terrain)
	Services.sim_world = sim_world
	Services.authority = authority
	get_tree().change_scene_to_file.call_deferred(GAME_SCENE)
	await get_tree().process_frame
	await get_tree().process_frame
	_set_state(State.IN_GAME)

func _set_state(s: int) -> void:
	state = s
	EventBus.game_state_changed.emit(s)

func set_paused(p: bool) -> void:
	if state == State.IN_GAME and p:
		_set_state(State.PAUSED)
		get_tree().paused = true
	elif state == State.PAUSED and not p:
		_set_state(State.IN_GAME)
		get_tree().paused = false

func _process(delta: float) -> void:
	if state != State.IN_GAME:
		return
	QualityManager.tick(delta)
	var steps := sim_clock.advance(delta)
	for i in range(steps):
		var intent := authority.gather_intent()
		authority.apply_tick(sim_world, intent, SimClock.SIM_DT)

func sim_alpha() -> float:
	return sim_clock.alpha()
