class_name ProcMeshFactory
extends RefCounted
## Universal procedural fallback meshes. Used when a real asset id is missing
## so the game NEVER crashes on absent art. Vertex-coloured, one material.

static func _vc_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	return m

static func _ring(r: float, seg: int) -> Array:
	var p := []
	for k in range(seg):
		var a := TAU * float(k) / float(seg)
		p.append(Vector3(cos(a) * r, 0.0, sin(a) * r))
	return p

static func _cone(st: SurfaceTool, r: float, hgt: float, base_y: float, col: Color) -> void:
	var seg := 8
	var rg := _ring(r, seg)
	var apex := Vector3(0, base_y + hgt, 0)
	for k in range(seg):
		var p0: Vector3 = rg[k] + Vector3(0, base_y, 0)
		var p1: Vector3 = rg[(k + 1) % seg] + Vector3(0, base_y, 0)
		st.set_color(col); st.add_vertex(p0)
		st.set_color(col); st.add_vertex(apex)
		st.set_color(col); st.add_vertex(p1)

static func _cyl(st: SurfaceTool, r: float, hgt: float, base_y: float, col: Color) -> void:
	var seg := 6
	var rg := _ring(r, seg)
	for k in range(seg):
		var a0: Vector3 = rg[k] + Vector3(0, base_y, 0)
		var a1: Vector3 = rg[(k + 1) % seg] + Vector3(0, base_y, 0)
		var b0: Vector3 = a0 + Vector3(0, hgt, 0)
		var b1: Vector3 = a1 + Vector3(0, hgt, 0)
		st.set_color(col); st.add_vertex(a0)
		st.set_color(col); st.add_vertex(b0)
		st.set_color(col); st.add_vertex(a1)
		st.set_color(col); st.add_vertex(a1)
		st.set_color(col); st.add_vertex(b0)
		st.set_color(col); st.add_vertex(b1)

static func tree() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bark := Color(0.15, 0.09, 0.05)
	var leaf := Color(0.07, 0.16, 0.07)
	_cyl(st, 0.18, 1.6, 0.0, bark)
	_cone(st, 1.5, 2.4, 1.3, leaf)
	_cone(st, 1.1, 2.2, 2.7, leaf)
	_cone(st, 0.65, 2.0, 4.0, leaf)
	st.generate_normals()
	st.set_material(_vc_mat())
	return st.commit()

static func bush() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cone(st, 0.9, 1.1, 0.0, Color(0.09, 0.15, 0.07))
	_cone(st, 0.65, 0.9, 0.5, Color(0.10, 0.17, 0.08))
	st.generate_normals()
	st.set_material(_vc_mat())
	return st.commit()

static func rock() -> Mesh:
	var bm := BoxMesh.new()
	bm.size = Vector3(1.4, 1.0, 1.2)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 0.28, 0.25)
	m.roughness = 0.95
	bm.material = m
	return bm

static func character() -> Mesh:
	var cap := CapsuleMesh.new()
	cap.radius = 0.5
	cap.height = 1.8
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.35, 0.6)
	cap.material = m
	return cap
