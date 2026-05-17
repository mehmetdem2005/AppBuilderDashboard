class_name CameraRigState
extends RefCounted
## Abstract camera behaviour. Returns the DESIRED camera transform for the
## current target/look; CameraRig blends toward it (no snapping).

func enter() -> void:
	pass

func exit() -> void:
	pass

## target_pos = character position; yaw/pitch from accumulated look input.
func desired(_target_pos: Vector3, _yaw: float, _pitch: float) -> Transform3D:
	return Transform3D.IDENTITY

func projection_is_ortho() -> bool:
	return false

func ortho_size() -> float:
	return 60.0

## yaw used for camera-relative character movement
func move_yaw(yaw: float) -> float:
	return yaw
