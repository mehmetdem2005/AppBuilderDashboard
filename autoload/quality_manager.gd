extends Node
## Adaptive performance controller. Targets 60 FPS, degrades gracefully with
## hysteresis, and enforces a SAFE FLOOR so the game can never crash/OOM even
## if it cannot hit framerate. Emits EventBus.quality_changed; world/camera
## subscribe and reconfigure live (no reload).

const PRESET_DIR := "res://data/resources/quality/"
const DOWN_MS := 20.0                    # > => slower than ~50 FPS
const UP_MS := 14.0                      # < => faster than ~70 FPS
const DOWN_HOLD := 1.5
const UP_HOLD := 6.0
const SAMPLE := 90

var active: QualityPreset
var _frames: PackedFloat32Array = PackedFloat32Array()
var _below_t := 0.0
var _above_t := 0.0
var _thermal_lock := false

func _ready() -> void:
	active = _load_or_build(Settings.quality_preset_id)
	# defer so other autoloads/subscribers exist
	call_deferred("_emit")

func _emit() -> void:
	EventBus.quality_changed.emit(active)

func _load_or_build(id: StringName) -> QualityPreset:
	var p := PRESET_DIR + String(id) + ".tres"
	if ResourceLoader.exists(p):
		var r = load(p)
		if r is QualityPreset:
			return r
	return _builtin(id)

func _builtin(id: StringName) -> QualityPreset:
	var q := QualityPreset.new()
	q.id = id
	match String(id):
		"ultra_low":
			q.display_name = "Çok Düşük"
			q.visual_radius = 3; q.scatter_mul = 0.4; q.render_scale = 0.6
			q.shadows_enabled = false; q.msaa = 0; q.collision_radius = 1
			q.fog_end = 650.0; q.worker_tasks = 2; q.lod_bias = 1.4
		"medium":
			q.display_name = "Orta"
			q.visual_radius = 6; q.scatter_mul = 1.0; q.render_scale = 1.0
			q.shadows_enabled = true; q.shadow_max_distance = 160.0
			q.msaa = 2; q.collision_radius = 2; q.fog_end = 1100.0
			q.worker_tasks = 2; q.lod_bias = 0.85
		_:
			q.id = &"low"
			q.display_name = "Düşük"
			q.visual_radius = 4; q.scatter_mul = 0.7; q.render_scale = 0.85
			q.shadows_enabled = false; q.msaa = 0; q.collision_radius = 2
			q.fog_end = 900.0; q.worker_tasks = 2; q.lod_bias = 1.0
	return q

func set_preset(id: StringName) -> void:
	active = _load_or_build(id)
	Settings.quality_preset_id = active.id
	Settings.save_cfg()
	_below_t = 0.0
	_above_t = 0.0
	_emit()

## Called every frame by GameRoot while IN_GAME.
func tick(frame_delta: float) -> void:
	var ms := frame_delta * 1000.0
	_frames.append(ms)
	if _frames.size() > SAMPLE:
		_frames.remove_at(0)
	if _frames.size() < SAMPLE:
		return
	var sum := 0.0
	for f in _frames:
		sum += f
	var avg := sum / float(_frames.size())

	if avg > DOWN_MS:
		_below_t += frame_delta
		_above_t = 0.0
		if _below_t >= DOWN_HOLD:
			_step_down()
			_below_t = 0.0
	elif avg < UP_MS and not _thermal_lock:
		_above_t += frame_delta
		_below_t = 0.0
		if _above_t >= UP_HOLD:
			_step_up()
			_above_t = 0.0
	else:
		_below_t = 0.0
		_above_t = 0.0

func _step_down() -> void:
	var changed := false
	if active.render_scale > 0.6:
		active.render_scale = maxf(0.6, active.render_scale - 0.15); changed = true
	elif active.visual_radius > 3:
		active.visual_radius -= 1; changed = true
	elif active.shadows_enabled:
		active.shadows_enabled = false; changed = true
	elif active.scatter_mul > 0.4:
		active.scatter_mul = maxf(0.4, active.scatter_mul - 0.2); changed = true
	elif active.collision_radius > 1:
		active.collision_radius = 1; changed = true
	# else: already at safe floor — hold, never crash
	if changed:
		# sustained degradation acts as a thermal proxy (no GL thermal API)
		_thermal_lock = (active.render_scale <= 0.6 and active.visual_radius <= 3)
		EventBus.quality_step.emit(-1)
		_emit()

func _step_up() -> void:
	var ceil_p := _load_or_build(Settings.quality_preset_id)
	var changed := false
	if active.scatter_mul < ceil_p.scatter_mul:
		active.scatter_mul = minf(ceil_p.scatter_mul, active.scatter_mul + 0.2); changed = true
	elif active.visual_radius < ceil_p.visual_radius:
		active.visual_radius += 1; changed = true
	elif active.render_scale < ceil_p.render_scale:
		active.render_scale = minf(ceil_p.render_scale, active.render_scale + 0.15); changed = true
	elif ceil_p.shadows_enabled and not active.shadows_enabled:
		active.shadows_enabled = true; changed = true
	if changed:
		EventBus.quality_step.emit(1)
		_emit()

# test helper: inject synthetic frame times
func _debug_feed(ms: float, n: int) -> void:
	for i in range(n):
		tick(ms / 1000.0)
