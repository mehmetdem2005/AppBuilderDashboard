class_name TopDownRig
extends CameraRigState

const HEIGHT := 42.0

func desired(target_pos: Vector3, yaw: float, _pitch: float) -> Transform3D:
	var cam_pos := target_pos + Vector3(0, HEIGHT, 0.001)
	var t := Transform3D()
	t.origin = cam_pos
	t = t.looking_at(target_pos, Vector3(sin(yaw), 0, cos(yaw)))
	return t

func projection_is_ortho() -> bool:
	return true

func ortho_size() -> float:
	return 70.0
