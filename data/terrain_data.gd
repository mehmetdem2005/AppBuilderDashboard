class_name TerrainData
extends RefCounted
## Single source of truth for terrain geometry. Loads the PROCESSED heightmap
## exported by the Blender pipeline (height.f32 row-major <f4 0..1 + terrain.json).
## Read-only and thread-safe to SAMPLE (no mutation after load) so chunk &
## collision builder jobs can call height()/normal() from worker threads.

var w := 0
var h := 0
var world_size := 2000.0
var relief := 230.0
var sea := 0.0
var zmin := 0.0
var zmax := 0.0
var loaded := false
var _hf := PackedFloat32Array()

func load_from(dir: String) -> bool:
	var jpath := dir + "/terrain.json"
	var jf := FileAccess.open(jpath, FileAccess.READ)
	if jf == null:
		EventBus.report_error("TerrainData", "terrain.json yok: " + jpath)
		return false
	var meta = JSON.parse_string(jf.get_as_text())
	if typeof(meta) != TYPE_DICTIONARY:
		EventBus.report_error("TerrainData", "terrain.json bozuk")
		return false
	w = int(meta.w); h = int(meta.h)
	world_size = float(meta.world_size)
	relief = float(meta.relief)
	sea = float(meta.sea)
	zmin = float(meta.get("zmin", 0.0))
	zmax = float(meta.get("zmax", relief))
	var bf := FileAccess.open(dir + "/height.f32", FileAccess.READ)
	if bf == null:
		EventBus.report_error("TerrainData", "height.f32 yok")
		return false
	_hf = bf.get_buffer(bf.get_length()).to_float32_array()
	if _hf.size() < w * h:
		EventBus.report_error("TerrainData",
			"height.f32 küçük: %d < %d" % [_hf.size(), w * h])
		return false
	loaded = true
	return true

func _raw(ix: int, iy: int) -> float:
	ix = clampi(ix, 0, w - 1)
	iy = clampi(iy, 0, h - 1)
	return _hf[iy * w + ix]

## world X,Z (terrain centred on origin) -> world height Y in metres
func height(wx: float, wz: float) -> float:
	var half := world_size * 0.5
	var u := (wx + half) / world_size * float(w - 1)
	var v := (wz + half) / world_size * float(h - 1)
	var x0 := int(floor(u))
	var y0 := int(floor(v))
	var fx := u - float(x0)
	var fy := v - float(y0)
	var a := _raw(x0, y0)
	var b := _raw(x0 + 1, y0)
	var c := _raw(x0, y0 + 1)
	var d := _raw(x0 + 1, y0 + 1)
	return lerp(lerp(a, b, fx), lerp(c, d, fx), fy) * relief

func normal(wx: float, wz: float, eps := 2.0) -> Vector3:
	var hl := height(wx - eps, wz)
	var hr := height(wx + eps, wz)
	var hd := height(wx, wz - eps)
	var hu := height(wx, wz + eps)
	return Vector3(hl - hr, 2.0 * eps, hd - hu).normalized()

## Region lookup is descriptor-driven (RegionManager owns the descriptors);
## TerrainData only provides geometry. Kept as a stub hook for clarity.
func clamp_to_world(p: Vector3) -> Vector3:
	var half := world_size * 0.5 - 1.0
	return Vector3(clampf(p.x, -half, half), p.y, clampf(p.z, -half, half))
