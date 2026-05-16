class_name CollisionChunk
extends StaticBody3D
## Pooled terrain collider for one collision cell. A HeightMapShape3D is
## created on the MAIN thread from a pre-sampled heightfield. Reused via the
## pool (map_data reassigned in place) so there is no node-alloc churn.

const N := CollisionBuilder.N

var cell: Vector2i = Vector2i.ZERO
var _cs: CollisionShape3D
var _shape: HeightMapShape3D

func _ensure() -> void:
	if _cs == null:
		_cs = CollisionShape3D.new()
		_shape = HeightMapShape3D.new()
		_shape.map_width = N + 1
		_shape.map_depth = N + 1
		_cs.shape = _shape
		add_child(_cs)

func commit(result: Dictionary) -> void:
	_ensure()
	cell = Vector2i(result.cx, result.cz)
	_shape.map_width = N + 1
	_shape.map_depth = N + 1
	_shape.map_data = result.data
	var c: Vector3 = result.center
	var step: float = result.step
	global_position = c
	# local heightfield grid spacing is 1 unit -> scale to metres
	_cs.scale = Vector3(step, 1.0, step)
	_cs.position = Vector3.ZERO

func recycle() -> void:
	cell = Vector2i.ZERO
