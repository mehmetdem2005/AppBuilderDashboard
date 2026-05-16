class_name BiomeProfile
extends Resource
## Per-region look & density data. Feeds the terrain shader + scatter.

@export_group("Terrain Shader")
@export var sea_level: float = 11.5
@export var relief: float = 230.0
@export var c_sand: Color = Color(0.36, 0.305, 0.185)
@export var c_grass: Color = Color(0.105, 0.155, 0.062)
@export var c_grass2: Color = Color(0.150, 0.180, 0.080)
@export var c_dry: Color = Color(0.165, 0.158, 0.090)
@export var c_rock: Color = Color(0.135, 0.122, 0.108)

@export_group("Vegetation")
@export var tree_asset: StringName = &"tree_default"
@export var bush_asset: StringName = &"bush_default"
@export_range(0.0, 1.0) var tree_density: float = 0.7
@export_range(0.0, 1.0) var bush_density: float = 0.5
@export var tree_line_frac: float = 0.72            # of (zmax-sea)

@export_group("Atmosphere")
@export var sky_top: Color = Color(0.37, 0.59, 0.85)
@export var sky_horizon: Color = Color(0.77, 0.86, 0.92)
@export var fog_color: Color = Color(0.74, 0.82, 0.88)
@export var fog_begin: float = 350.0
@export var fog_end: float = 1100.0
