@tool
class_name TerrainPreview
extends Node3D
## EDITOR-ONLY coarse island preview so the scene is visible & tweakable
## without running the game. Self-contained (no autoloads — they don't run
## in the editor): reads data/terrain directly, builds one low-res mesh,
## applies the terrain shader from the assigned BiomeProfile. At runtime it
## removes itself; the real streaming world (WorldStreamer) takes over.

@export var terrain_dir: String = "res://data/terrain"
@export var biome: BiomeProfile:
	set(v):
		biome = v
		_rebuild()
@export_range(32, 160) var preview_res: int = 96:
	set(v):
		preview_res = v
		_rebuild()
@export var rebuild_now: bool = false:
	set(v):
		rebuild_now = false
		_rebuild()

var _mi: MeshInstance3D

func _ready() -> void:
	if not Engine.is_editor_hint():
		# real game uses streamed terrain; drop the preview entirely
		queue_free()
		return
	_rebuild()

func _rebuild() -> void:
	if not Engine.is_editor_hint():
		return
	if _mi == null:
		_mi = MeshInstance3D.new()
		_mi.name = "PreviewMesh"
		add_child(_mi)
	var meta := _load_json(terrain_dir + "/terrain.json")
	if meta.is_empty():
		return
	var w: int = int(meta.get("w", 0))
	var h: int = int(meta.get("h", 0))
	var world_size: float = float(meta.get("world_size", 2000.0))
	var relief: float = float(meta.get("relief", 230.0))
	var hf := _load_f32(terrain_dir + "/height.f32")
	if w <= 0 or h <= 0 or hf.size() < w * h:
		return

	var n := preview_res
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	verts.resize((n + 1) * (n + 1))
	norms.resize((n + 1) * (n + 1))
	var half := world_size * 0.5
	for j in range(n + 1):
		for i in range(n + 1):
			var fx := float(i) / float(n)
			var fz := float(j) / float(n)
			var wx := -half + fx * world_size
			var wz := -half + fz * world_size
			var px := clampi(int(fx * float(w - 1)), 0, w - 1)
			var pz := clampi(int(fz * float(h - 1)), 0, h - 1)
			var y := hf[pz * w + px] * relief
			verts[j * (n + 1) + i] = Vector3(wx, y, wz)
	for j in range(n):
		for i in range(n):
			var a := j * (n + 1) + i
			var b := a + 1
			var c := a + (n + 1)
			var d := c + 1
			idx.append(a); idx.append(c); idx.append(b)
			idx.append(b); idx.append(c); idx.append(d)
	# simple normals
	for j in range(n + 1):
		for i in range(n + 1):
			var k := j * (n + 1) + i
			var l := verts[j * (n + 1) + maxi(i - 1, 0)]
			var r := verts[j * (n + 1) + mini(i + 1, n)]
			var dn := verts[maxi(j - 1, 0) * (n + 1) + i]
			var up := verts[mini(j + 1, n) * (n + 1) + i]
			norms[k] = Vector3(l.y - r.y, 2.0, dn.y - up.y).normalized()

	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_mi.mesh = am
	_mi.material_override = _make_material()

func _make_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	var sh := load("res://world/visual/terrain.gdshader")
	if sh == null:
		return m
	m.shader = sh
	var b := biome
	if b == null:
		b = BiomeProfile.new()
	m.set_shader_parameter("sea_level", b.sea_level)
	m.set_shader_parameter("relief", b.relief)
	m.set_shader_parameter("c_sand", b.c_sand)
	m.set_shader_parameter("c_grass", b.c_grass)
	m.set_shader_parameter("c_grass2", b.c_grass2)
	m.set_shader_parameter("c_dry", b.c_dry)
	m.set_shader_parameter("c_rock", b.c_rock)
	return m

func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if typeof(d) == TYPE_DICTIONARY else {}

func _load_f32(path: String) -> PackedFloat32Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedFloat32Array()
	return f.get_buffer(f.get_length()).to_float32_array()
