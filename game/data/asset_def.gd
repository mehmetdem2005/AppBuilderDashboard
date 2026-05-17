class_name AssetDef
extends Resource
## One swappable art asset, referenced everywhere by `id` (never by path).
## Real models/textures replace `path` later with zero code changes.

enum Kind { MESH, SCENE, MATERIAL, TEXTURE }
enum CollisionKind { NONE, CONVEX, TRIMESH }

@export var id: StringName = &""
@export var kind: Kind = Kind.MESH
@export var path: String = ""
@export var lod_paths: Array[String] = []
@export var collision_kind: CollisionKind = CollisionKind.NONE
@export var fallback_id: StringName = &""
