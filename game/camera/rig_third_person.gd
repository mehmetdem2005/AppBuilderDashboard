class_name ThirdPersonRig
extends CameraRigState

const DIST := 7.5
const HEIGHT := 2.4

func desired(target_pos: Vector3, yaw: float, pitch: float) -> Transform3D:
	var pivot := target_pos + Vector3.UP * HEIGHT
	var dir := Vector3(
		sin(yaw) * cos(pitch),
		sin(pitch),
		cos(yaw) * cos(pitch))
	var cam_pos := pivot + dir * DIST
	var t := Transform3D()
	t.origin = cam_pos
	t = t.looking_at(pivot, Vector3.UP)
	return t
