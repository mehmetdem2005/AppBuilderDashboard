class_name RingLog
extends RefCounted
## Tiny fixed-size diagnostic buffer (no unbounded growth on device).

var _cap: int
var _buf: PackedStringArray = PackedStringArray()

func _init(cap: int = 64) -> void:
	_cap = cap

func add(line: String) -> void:
	_buf.append(line)
	if _buf.size() > _cap:
		_buf.remove_at(0)

func dump() -> String:
	return "\n".join(_buf)
