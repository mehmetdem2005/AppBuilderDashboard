class_name ObjectPool
extends RefCounted
## Reuses Node instances to avoid GDScript GC stalls on weak CPUs.
## Caller supplies a factory Callable; pool owns free instances only.

var _factory: Callable
var _free: Array[Node] = []
var _max_free: int

func _init(factory: Callable, max_free: int = 64) -> void:
	_factory = factory
	_max_free = max_free

func acquire() -> Node:
	if _free.is_empty():
		return _factory.call()
	return _free.pop_back()

func release(n: Node) -> void:
	if n == null:
		return
	if n.get_parent() != null:
		n.get_parent().remove_child(n)
	if _free.size() < _max_free:
		_free.append(n)
	else:
		n.queue_free()

func clear() -> void:
	for n in _free:
		n.queue_free()
	_free.clear()
