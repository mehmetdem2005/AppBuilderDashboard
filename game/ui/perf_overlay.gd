class_name PerfOverlay
extends Label
## Diagnostic HUD. Bounded-count assertions in the smoke test read the same
## streamer counters shown here.

var _t := 0.0

func _ready() -> void:
	add_theme_color_override("font_color", Color(1, 1, 1))
	add_theme_font_size_override("font_size", 18)
	position = Vector2(12, 12)
	visible = Settings.show_perf_overlay

func _process(d: float) -> void:
	_t += d
	if _t < 0.5:
		return
	_t = 0.0
	var ws = Services.world_streamer
	var vis := 0
	var col := 0
	var pend := 0
	if ws != null:
		vis = ws.active_visual_count()
		col = ws.active_collision_count()
		pend = ws.pending_jobs()
	var dc := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var mem := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	text = "FPS %d  %.1f ms\nvisual %d  collision %d  jobs %d\nscale %.2f  draw %d  mem %.0f MB" % [
		Engine.get_frames_per_second(),
		1000.0 / maxf(Engine.get_frames_per_second(), 1.0),
		vis, col, pend,
		QualityManager.active.render_scale, dc, mem]
