class_name RegionManager
extends Node
## Story zones as DATA. Regions are descriptor overlays on one continuous
## heightmap (seamless world) — never separate scenes. Switching a region
## only swaps biome/assets/env via reference + threaded preload; no
## change_scene, no hitch, no terrain rebuild.

const REGION_DIR := "res://data/resources/regions/"

var _regions: Array[RegionDescriptor] = []
var _active: RegionInstance
var _visual_grid: VisualChunkGrid

func setup(visual_grid: VisualChunkGrid) -> void:
	_visual_grid = visual_grid
	_load_descriptors()
	if _regions.is_empty():
		_regions.append(_default_descriptor())
	_activate(_regions[0], true)

func _load_descriptors() -> void:
	if not DirAccess.dir_exists_absolute(REGION_DIR):
		return
	var da := DirAccess.open(REGION_DIR)
	if da == null:
		return
	for fn in da.get_files():
		if fn.ends_with(".tres"):
			var r = load(REGION_DIR + fn)
			if r is RegionDescriptor:
				_regions.append(r)

func _default_descriptor() -> RegionDescriptor:
	var d := RegionDescriptor.new()
	d.region_id = &"default"
	d.display_name = "Ana Ada"
	d.biome = BiomeProfile.new()
	return d

func active_id() -> StringName:
	return _active.id() if _active != null else &"default"

func region_at(wx: float, wz: float) -> RegionDescriptor:
	for r in _regions:
		if r != null and r.contains_xz(wx, wz):
			return r
	return _regions[0] if not _regions.is_empty() else null

## Called by WorldStreamer with the current focus; detects boundary crossing.
func update(focus: Vector3) -> void:
	if _active == null:
		return
	var r := region_at(focus.x, focus.z)
	if r != null and r.region_id != _active.id():
		EventBus.region_load_requested.emit(r.region_id)
		AssetRegistry.preload_set(r.asset_set)
		_activate(r, false)

func _activate(d: RegionDescriptor, _initial: bool) -> void:
	_active = RegionInstance.new(d)
	_active.activated = true
	if _visual_grid != null and d.biome != null:
		_visual_grid.set_biome(d.biome)
	if Services.sim_world != null:
		Services.sim_world.region_id = d.region_id
	EventBus.region_activated.emit(d.region_id)
