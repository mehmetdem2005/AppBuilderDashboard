class_name WorldStreamer
extends Node3D
## Orchestrates the TWO independent streaming grids + regions. Visual grid
## updates every frame; collision grid + region check run at a slower fixed
## cadence (20 Hz) — distant visual LOD churn costs ZERO collision work.

const COLLISION_HZ_DIV := 3              # 60 physics ticks / 3 = 20 Hz

## Inspector-tweakable: assign a BiomeProfile .tres (terrain colours,
## scatter density, fog). Leave null to use the active region's biome.
@export var biome_override: BiomeProfile
## Optional terrain data dir override (defaults to Settings.terrain_dir).
@export var terrain_dir_override: String = ""

var terrain: TerrainData
var visual: VisualChunkGrid
var collision: CollisionChunkGrid
var regions: RegionManager
var _phys_count := 0

func _ready() -> void:
	terrain = GameRoot.terrain
	visual = VisualChunkGrid.new()
	visual.name = "VisualGrid"
	add_child(visual)
	collision = CollisionChunkGrid.new()
	collision.name = "CollisionGrid"
	add_child(collision)
	regions = RegionManager.new()
	regions.name = "RegionManager"
	add_child(regions)

	visual.setup(terrain, biome_override)
	collision.setup(terrain)
	regions.setup(visual)
	Services.world_streamer = self

func _focus() -> Vector3:
	if Services.sim_world != null:
		return Services.sim_world.player.position
	return Vector3.ZERO

func _process(_d: float) -> void:
	visual.update(_focus())
	EventBus.streaming_idle.emit(visual.is_idle() and collision.is_idle())

func _physics_process(_d: float) -> void:
	_phys_count += 1
	if _phys_count % COLLISION_HZ_DIV != 0:
		return
	var f := _focus()
	collision.update(f)
	regions.update(f)

func active_visual_count() -> int:
	return visual.active_count() if visual else 0

func active_collision_count() -> int:
	return collision.active_count() if collision else 0

func pending_jobs() -> int:
	return (visual.pending_count() if visual else 0)
