extends Node3D
## Thin world assembly. Builds runtime systems by REFERENCE/script — no
## meshes, transforms, or region data baked in this scene.

var sun: DirectionalLight3D
var world_env: WorldEnvironment

func _ready() -> void:
	# input first (others read Services.input_router)
	var router := InputRouter.new()
	router.name = "InputRouter"
	add_child(router)

	_build_environment()

	var streamer := WorldStreamer.new()
	streamer.name = "WorldStreamer"
	add_child(streamer)

	var character := AnimalCharacter.new()
	character.name = "Player"
	add_child(character)

	var rig := CameraRig.new()
	rig.name = "CameraRig"
	add_child(rig)

	var layer := CanvasLayer.new()
	add_child(layer)
	var hud := GameHud.new()
	layer.add_child(hud)

	EventBus.quality_changed.connect(_on_quality)
	_on_quality(QualityManager.active)

func _build_environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.37, 0.59, 0.85)
	sm.sky_horizon_color = Color(0.77, 0.86, 0.92)
	sm.ground_horizon_color = Color(0.77, 0.86, 0.92)
	sm.ground_bottom_color = Color(0.5, 0.6, 0.62)
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.74, 0.82, 0.88)
	env.fog_depth_begin = 350.0
	env.fog_depth_end = 1000.0
	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 38, 0)
	sun.light_energy = 1.2
	sun.light_color = Color(1.0, 0.96, 0.88)
	add_child(sun)

func _on_quality(p: QualityPreset) -> void:
	if p == null:
		return
	if sun != null:
		sun.shadow_enabled = p.shadows_enabled
		sun.directional_shadow_max_distance = p.shadow_max_distance
	if world_env != null:
		world_env.environment.fog_depth_end = p.fog_end
