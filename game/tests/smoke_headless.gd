extends Node3D
## Headless end-to-end smoke test. Run:
##   xvfb-run -a godot --path game --rendering-driver opengl3 \
##       res://tests/Smoke.tscn
## Asserts: terrain loads, BOTH grids stream with bounded counts, camera
## state machine works, adaptive quality steps within safe bounds, GL
## actually renders (non-blank), save round-trips. PASS -> quit(0).

const HARD_TIMEOUT := 1200
const VISUAL_CAP := 200
const COLLISION_CAP := 64

var _frame := 0
var _phase := 0
var _errors := 0
var _cam_changes := 0
var _streamer: WorldStreamer
var _rig: CameraRig
var _world: SimWorld
var _path: Array = []
var _pi := 0
var _hold := 0
var _busy := false

func _ready() -> void:
	EventBus.diagnostic_error.connect(func(_w, _m): _errors += 1)
	EventBus.camera_mode_changed.connect(func(_m): _cam_changes += 1)

	Settings.terrain_dir = "/tmp/mapgen"
	var td := TerrainData.new()
	if not td.load_from(Settings.terrain_dir):
		_fail("terrain yüklenemedi")
		return
	_assert(td.world_size == 2000.0, "world_size != 2000")
	_assert(td.w == td.h and td.w > 0, "geçersiz boyut")
	GameRoot.terrain = td

	_world = SimWorld.new()
	Services.sim_world = _world
	Services.authority = LocalAuthority.new(td)

	var router := InputRouter.new()
	add_child(router)
	_streamer = WorldStreamer.new()
	add_child(_streamer)
	_rig = CameraRig.new()
	add_child(_rig)

	# focus path: crosses several visual cells (>375 m)
	_path = [
		Vector3(-300, 0, -300), Vector3(-100, 0, -150),
		Vector3(150, 0, 0), Vector3(350, 0, 250),
	]
	_world.player.position = _path[0]
	print("[SMOKE] start")

func _process(_d: float) -> void:
	_frame += 1
	if _frame > HARD_TIMEOUT:
		_fail("hard timeout")
		return
	if _busy:
		return                       # an awaiting phase is in flight

	# bounded-count invariants every frame
	var vis := _streamer.active_visual_count()
	var col := _streamer.active_collision_count()
	if vis > VISUAL_CAP:
		_fail("visual chunk cap aşıldı: %d" % vis); return
	if col > COLLISION_CAP:
		_fail("collision chunk cap aşıldı: %d" % col); return
	if _errors > 0:
		_fail("diagnostic_error tetiklendi"); return

	match _phase:
		0: _phase_move()
		1: _phase_camera()
		2: _phase_quality()
		3: _phase_converge_shot()
		4: _phase_save()
		5: _finish()

func _phase_move() -> void:
	# walk the focus along the path
	var tgt: Vector3 = _path[_pi]
	var p: Vector3 = _world.player.position
	_world.player.position = p.move_toward(tgt, 6.0)
	if _world.player.position.distance_to(tgt) < 1.0:
		_pi += 1
		if _pi >= _path.size():
			_phase = 1
			print("[SMOKE] move ok  visual=%d collision=%d" % [
				_streamer.active_visual_count(),
				_streamer.active_collision_count()])

func _phase_camera() -> void:
	_rig.cycle_mode()
	if _cam_changes >= 3:
		var t := _rig.cam.global_transform
		_assert(t.origin.is_finite(), "kamera transform sonsuz")
		print("[SMOKE] camera ok  changes=%d" % _cam_changes)
		_phase = 2

func _phase_quality() -> void:
	var r0 := QualityManager.active.visual_radius
	var s0 := QualityManager.active.render_scale
	QualityManager._debug_feed(30.0, QualityManager.SAMPLE + 130)
	var degraded := QualityManager.active.render_scale < s0 \
		or QualityManager.active.visual_radius < r0
	_assert(degraded, "adaptif düşüş çalışmadı")
	_assert(QualityManager.active.render_scale >= 0.6, "render_scale taban altı")
	_assert(QualityManager.active.visual_radius >= 3, "radius taban altı")
	QualityManager._debug_feed(6.0, QualityManager.SAMPLE + 400)
	print("[SMOKE] quality ok  scale=%.2f radius=%d" % [
		QualityManager.active.render_scale,
		QualityManager.active.visual_radius])
	_phase = 3

func _phase_converge_shot() -> void:
	_hold += 1
	if not (_streamer.visual.is_idle() and _streamer.collision.is_idle()):
		if _hold > 600:
			_fail("streaming yakınsamadı")
		return
	if _hold < 4:
		return
	_busy = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://smoke.png")
	if not _variance_ok(img):
		_fail("render boş (GL çıktısı yok)")
		return
	print("[SMOKE] render ok  (user://smoke.png)")
	_phase = 4
	_busy = false

func _phase_save() -> void:
	_world.player.position = Vector3(123, 45, -67)
	_world.region_id = &"default"
	_assert(SaveSystem.save_game(0, _world), "save başarısız")
	var w2 := SimWorld.new()
	_assert(SaveSystem.load_game(0, w2), "load başarısız")
	_assert(w2.region_id == &"default", "region round-trip hatası")
	_assert(absf(w2.player.position.x - 123.0) < 0.001, "pos round-trip hatası")
	print("[SMOKE] save ok")
	_phase = 5

func _variance_ok(img: Image) -> bool:
	img.resize(64, 64)
	var mean := 0.0
	var vals: PackedFloat32Array = PackedFloat32Array()
	for y in range(0, 64, 4):
		for x in range(0, 64, 4):
			var l := img.get_pixel(x, y).get_luminance()
			vals.append(l)
			mean += l
	mean /= float(vals.size())
	var var_sum := 0.0
	for v in vals:
		var_sum += (v - mean) * (v - mean)
	return (var_sum / float(vals.size())) > 0.0008

func _assert(cond: bool, msg: String) -> void:
	if not cond:
		_fail(msg)

func _fail(reason: String) -> void:
	push_error("[SMOKE] FAIL: " + reason)
	print("[SMOKE] FAIL: " + reason)
	get_tree().quit(1)

func _finish() -> void:
	print("[SMOKE] PASS  frames=%d visual=%d collision=%d cam=%d err=%d" % [
		_frame, _streamer.active_visual_count(),
		_streamer.active_collision_count(), _cam_changes, _errors])
	get_tree().quit(0)
