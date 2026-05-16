extends Node
## Persisted user configuration (user://settings.cfg). No game data here.

const PATH := "user://settings.cfg"

# --- persisted fields (defaults tuned for a weak phone) ---
var quality_preset_id: StringName = &"low"
var terrain_dir: String = "res://data/terrain"      # dev override allowed
var joystick_on_left: bool = true
var joystick_size: float = 180.0
var joystick_opacity: float = 0.45
var look_sensitivity: float = 0.28
var invert_look_y: bool = false
var camera_default_mode: int = 0                     # 0 third / 1 first / 2 top
var master_volume: float = 0.9
var sfx_volume: float = 0.9
var show_perf_overlay: bool = false

func _ready() -> void:
	load_cfg()

func load_cfg() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		# first run: probe a dev terrain export if the packaged one is absent
		if not FileAccess.file_exists(terrain_dir + "/terrain.json") \
				and FileAccess.file_exists("/tmp/mapgen/terrain.json"):
			terrain_dir = "/tmp/mapgen"
		save_cfg()
		return
	quality_preset_id = StringName(cf.get_value("quality", "preset_id", "low"))
	terrain_dir = cf.get_value("paths", "terrain_dir", terrain_dir)
	joystick_on_left = cf.get_value("input", "joystick_on_left", true)
	joystick_size = cf.get_value("input", "joystick_size", 180.0)
	joystick_opacity = cf.get_value("input", "joystick_opacity", 0.45)
	look_sensitivity = cf.get_value("input", "look_sensitivity", 0.28)
	invert_look_y = cf.get_value("input", "invert_look_y", false)
	camera_default_mode = cf.get_value("camera", "default_mode", 0)
	master_volume = cf.get_value("audio", "master", 0.9)
	sfx_volume = cf.get_value("audio", "sfx", 0.9)
	show_perf_overlay = cf.get_value("debug", "perf_overlay", false)

func save_cfg() -> void:
	var cf := ConfigFile.new()
	cf.set_value("quality", "preset_id", String(quality_preset_id))
	cf.set_value("paths", "terrain_dir", terrain_dir)
	cf.set_value("input", "joystick_on_left", joystick_on_left)
	cf.set_value("input", "joystick_size", joystick_size)
	cf.set_value("input", "joystick_opacity", joystick_opacity)
	cf.set_value("input", "look_sensitivity", look_sensitivity)
	cf.set_value("input", "invert_look_y", invert_look_y)
	cf.set_value("camera", "default_mode", camera_default_mode)
	cf.set_value("audio", "master", master_volume)
	cf.set_value("audio", "sfx", sfx_volume)
	cf.set_value("debug", "perf_overlay", show_perf_overlay)
	cf.save(PATH)
