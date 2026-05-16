class_name AnimalCharacter
extends Node3D
## Thin host. The authoritative state lives in SimWorld.player (advanced by
## the fixed-step sim). This node only RENDERS that state, interpolated by
## the sim alpha for smooth motion at any framerate. Networking-ready: the
## same SimWorld drives SP now and replicated MP later.

@export var asset_id: StringName = &"animal_player"

var _view: CharacterView
var _prev_pos: Vector3
var _prev_yaw: float
var _last_tick := -1

func _ready() -> void:
	_view = CharacterView.new()
	add_child(_view)
	_view.setup(asset_id)
	Services.character = self
	if Services.sim_world != null:
		var sp := _spawn_point()
		Services.sim_world.player.position = sp
		global_position = sp

func _spawn_point() -> Vector3:
	var td := GameRoot.terrain
	if td != null and td.loaded:
		return Vector3(0, td.height(0, 0), 0)
	return Vector3.ZERO

func _process(_d: float) -> void:
	if Services.sim_world == null:
		return
	var st: CharacterState = Services.sim_world.player
	var tick: int = Services.sim_world.tick
	if tick != _last_tick:
		# a new sim step landed -> current becomes the previous anchor
		_prev_pos = global_position
		_prev_yaw = rotation.y
		_last_tick = tick
	var a := GameRoot.sim_alpha()
	global_position = _prev_pos.lerp(st.position, a)
	rotation.y = lerp_angle(_prev_yaw, st.yaw, a)
