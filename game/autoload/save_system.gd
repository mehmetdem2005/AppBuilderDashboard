extends Node
## Versioned, atomic save/load. Terrain is NOT saved (regenerated from the
## deterministic heightmap) so files stay tiny. Survives mid-write app kills.

const SAVE_VERSION := 1
const DIR := "user://saves"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

func _slot_path(slot: int) -> String:
	return "%s/slot_%d.save" % [DIR, slot]

func save_game(slot: int, world: SimWorld) -> bool:
	var data := {
		"save_version": SAVE_VERSION,
		"world": world.to_dict(),
		"settings": {
			"quality": String(Settings.quality_preset_id),
		},
	}
	var tmp := _slot_path(slot) + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		EventBus.save_failed.emit(slot, "açılamadı")
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	# atomic swap
	var da := DirAccess.open(DIR)
	if da != null:
		if da.file_exists("slot_%d.save" % slot):
			da.remove("slot_%d.save" % slot)
		da.rename("slot_%d.save.tmp" % slot, "slot_%d.save" % slot)
	EventBus.save_completed.emit(slot)
	return true

func has_save(slot: int) -> bool:
	return FileAccess.file_exists(_slot_path(slot))

func load_game(slot: int, world: SimWorld) -> bool:
	var f := FileAccess.open(_slot_path(slot), FileAccess.READ)
	if f == null:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		EventBus.report_error("SaveSystem", "save bozuk slot %d" % slot)
		return false
	var ver := int(parsed.get("save_version", 0))
	if ver > SAVE_VERSION:
		EventBus.report_error("SaveSystem",
			"save sürümü çok yeni (%d > %d) — yüklenmedi" % [ver, SAVE_VERSION])
		return false
	parsed = _migrate(parsed, ver)
	world.from_dict(parsed.get("world", {}))
	EventBus.load_completed.emit(slot)
	return true

func _migrate(data: Dictionary, from_ver: int) -> Dictionary:
	# chain future migrations here; v0/v1 need none
	if from_ver < 1:
		data["save_version"] = 1
	return data
