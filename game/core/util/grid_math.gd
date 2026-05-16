class_name GridMath
extends RefCounted
## World <-> cell helpers shared by the two independent streaming grids.

static func cell_of(wx: float, wz: float, cell_size: float, world_size: float) -> Vector2i:
	var half := world_size * 0.5
	return Vector2i(int(floor((wx + half) / cell_size)),
					int(floor((wz + half) / cell_size)))

static func cell_origin(c: Vector2i, cell_size: float, world_size: float) -> Vector2:
	var half := world_size * 0.5
	return Vector2(-half + float(c.x) * cell_size, -half + float(c.y) * cell_size)

static func ring(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))   # Chebyshev distance

static func grid_count(world_size: float, cell_size: float) -> int:
	return int(round(world_size / cell_size))
