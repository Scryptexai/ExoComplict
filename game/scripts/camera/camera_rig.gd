class_name ThirdPersonCameraRig
extends Node3D

@export var look_sensitivity: float = 0.0035
@export_range(-80.0, 0.0, 1.0) var min_pitch_degrees: float = -52.0
@export_range(0.0, 80.0, 1.0) var max_pitch_degrees: float = 35.0

@onready var yaw_pivot: Node3D = $YawPivot
@onready var pitch_pivot: Node3D = $YawPivot/PitchPivot


func apply_look_delta(delta: Vector2) -> void:
	yaw_pivot.rotation.y -= delta.x * look_sensitivity
	var min_pitch := deg_to_rad(min_pitch_degrees)
	var max_pitch := deg_to_rad(max_pitch_degrees)
	pitch_pivot.rotation.x = clampf(
		pitch_pivot.rotation.x - delta.y * look_sensitivity, min_pitch, max_pitch
	)


func get_yaw_basis() -> Basis:
	return yaw_pivot.global_transform.basis
