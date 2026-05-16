extends Node
## Asset-agnostic registry. Everything references art by StringName id.
## Missing/absent art -> graceful fallback (never crash). When real models
## arrive, only the manifest .tres + res://assets files change; zero code edits.

const MANIFEST_PATH := "res://data/resources/assets/manifest.tres"

var _defs: Dictionary = {}              # StringName -> AssetDef
var _mesh_cache: Dictionary = {}        # StringName -> Mesh
var _missing_reported: Dictionary = {}

func _ready() -> void:
	if ResourceLoader.exists(MANIFEST_PATH):
		var man = load(MANIFEST_PATH)
		if man is AssetManifest:
			for d in man.defs:
				if d != null and d.id != &"":
					_defs[d.id] = d

func get_mesh(id: StringName) -> Mesh:
	if _mesh_cache.has(id):
		return _mesh_cache[id]
	var m := _resolve_mesh(id, 0)
	_mesh_cache[id] = m
	return m

func _resolve_mesh(id: StringName, depth: int) -> Mesh:
	if depth > 4:
		return _procedural_for(id)
	var def: AssetDef = _defs.get(id, null)
	if def != null and def.path != "" and ResourceLoader.exists(def.path):
		var res = load(def.path)
		if res is Mesh:
			return res
		if res is PackedScene:
			# allow a scene whose root holds a MeshInstance3D
			var inst = res.instantiate()
			var mi := _find_mesh(inst)
			var mm: Mesh = mi.mesh if mi != null else null
			inst.queue_free()
			if mm != null:
				return mm
	if def != null and def.fallback_id != &"" and def.fallback_id != id:
		return _resolve_mesh(def.fallback_id, depth + 1)
	_report_missing(id)
	return _procedural_for(id)

func _find_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var r := _find_mesh(c)
		if r != null:
			return r
	return null

func _procedural_for(id: StringName) -> Mesh:
	var s := String(id)
	if s.begins_with("bush"):
		return ProcMeshFactory.bush()
	if s.begins_with("rock"):
		return ProcMeshFactory.rock()
	if s.begins_with("char") or s.begins_with("animal"):
		return ProcMeshFactory.character()
	return ProcMeshFactory.tree()

func _report_missing(id: StringName) -> void:
	if _missing_reported.has(id):
		return
	_missing_reported[id] = true
	EventBus.asset_missing.emit(id)

func preload_set(_ids: Array) -> void:
	# Threaded preload hook (no-op until real assets exist; keeps API stable).
	pass

func release_set(_ids: Array) -> void:
	pass
