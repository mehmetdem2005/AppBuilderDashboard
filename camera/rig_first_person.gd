class_name FirstPersonRig
extends CameraRigState

const EYE := 1.7

func desired(target_pos: Vector3, yaw: float, pitch: float) -> Transform3D:
	var eye := target_pos + Vector3.UP * EYE
	var fwd := Vector3(
		sin(yaw) * cos(pitch),
		sin(pitch),
		cos(yaw) * cos(pitch))
	var t := Transform3D()
	t.origin = eye
	t = t.looking_at(eye - fwd, Vector3.UP)
	return t
