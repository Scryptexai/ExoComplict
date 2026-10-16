class_name ThirdPersonCameraRig
extends Node3D

## Over-the-shoulder camera with an aim-down-sights (ADS) state, smooth
## transitions and short recoil kicks.
##
## Node layout is fixed and referenced by the player controller, the HUD tests and
## the wave director: CameraRig/YawPivot/PitchPivot/SpringArm3D/Camera3D.
## Hold-to-aim (desktop right mouse) or the HUD AIM toggle calls set_aiming(true);
## the rig then eases the arm in, raises the shoulder offset and narrows the FOV
## instead of snapping, which is what makes aiming readable on a phone screen.

@export var look_sensitivity: float = 0.0035
@export_range(-80.0, 0.0, 1.0) var min_pitch_degrees: float = -55.0
@export_range(0.0, 80.0, 1.0) var max_pitch_degrees: float = 38.0
@export_group("Framing")
@export_range(1.5, 9.0, 0.05) var rest_spring_length: float = 4.6
@export_range(0.8, 6.0, 0.05) var aim_spring_length: float = 2.45
@export var rest_shoulder_offset: Vector3 = Vector3(0.42, 0.12, 0.0)
@export var aim_shoulder_offset: Vector3 = Vector3(0.58, 0.2, 0.0)
@export var rest_pivot_height: float = 1.52
@export var aim_pivot_height: float = 1.58
@export_range(30.0, 110.0, 0.5) var rest_fov: float = 70.0
@export_range(20.0, 90.0, 0.5) var aim_fov: float = 50.0
@export_range(1.0, 30.0, 0.5) var transition_speed: float = 9.0
@export_group("Kick")
@export_range(0.0, 1.0, 0.005) var kick_rotation_degrees: float = 0.16
@export_range(0.0, 1.0, 0.005) var kick_push: float = 0.05
@export_range(1.0, 30.0, 0.5) var kick_recovery: float = 11.0
@export_range(0.0, 1.0, 0.01) var walk_bob_scale: float = 0.35

var _aiming: bool = false
var _aim_blend: float = 0.0
var _kick: float = 0.0
var _kick_offset: Vector3 = Vector3.ZERO

@onready var yaw_pivot: Node3D = $YawPivot
@onready var pitch_pivot: Node3D = $YawPivot/PitchPivot
@onready var spring_arm: SpringArm3D = $YawPivot/PitchPivot/SpringArm3D
@onready var spring_camera: Camera3D = $YawPivot/PitchPivot/SpringArm3D/Camera3D


func _ready() -> void:
	_apply_blend(0.0)
	pitch_pivot.rotation.x = clampf(
		pitch_pivot.rotation.x, deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees)
	)


func _process(delta: float) -> void:
	var target_blend := 1.0 if _aiming else 0.0
	_aim_blend = move_toward(_aim_blend, target_blend, clampf(transition_speed, 1.0, 30.0) * delta)
	_apply_blend(_aim_blend)
	if _kick > 0.0:
		_kick = maxf(_kick - kick_recovery * delta * _kick, 0.0)
		if _kick < 0.001:
			_kick = 0.0
		_apply_kick()


func apply_look_delta(delta: Vector2) -> void:
	# Aiming slows the look down so fine adjustments are possible on touch.
	var sensitivity := look_sensitivity * (0.55 if _aim_blend > 0.5 else 1.0)
	yaw_pivot.rotation.y -= delta.x * sensitivity
	var min_pitch := deg_to_rad(min_pitch_degrees)
	var max_pitch := deg_to_rad(max_pitch_degrees)
	pitch_pivot.rotation.x = clampf(
		pitch_pivot.rotation.x - delta.y * sensitivity, min_pitch, max_pitch
	)


func get_yaw_basis() -> Basis:
	return yaw_pivot.global_transform.basis


func set_aiming(value: bool) -> void:
	_aiming = value


func is_aiming() -> bool:
	return _aiming


## 0 at rest, 1 fully aimed; the HUD uses it to tighten the crosshair.
func aim_blend() -> float:
	return _aim_blend


func add_recoil_kick(strength: float = 1.0) -> void:
	_kick = minf(_kick + 0.6 * clampf(strength, 0.2, 2.0), 1.4)
	_apply_kick()


## Short side-to-side sway driven by walking, so movement reads without the
## motion-sickness of a full first-person head bob.
func apply_walk_bob(intensity: float, time_seconds: float) -> void:
	if _kick_offset.length_squared() > 0.0:
		return
	var sway := sin(time_seconds * 6.0) * walk_bob_scale * intensity * 0.05
	spring_camera.h_offset = sway
	spring_camera.v_offset = absf(sin(time_seconds * 3.0)) * walk_bob_scale * intensity * 0.05


func _apply_blend(blend: float) -> void:
	if not is_instance_valid(spring_arm):
		return
	spring_arm.spring_length = lerpf(rest_spring_length, aim_spring_length, blend)
	spring_arm.position = rest_shoulder_offset.lerp(aim_shoulder_offset, blend)
	position.y = lerpf(rest_pivot_height, aim_pivot_height, blend)
	if is_instance_valid(spring_camera):
		spring_camera.fov = lerpf(rest_fov, aim_fov, blend)


func _apply_kick() -> void:
	if not is_instance_valid(spring_camera):
		return
	var decayed := _kick * _kick
	_kick_offset = (
		Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
		* decayed
		* kick_rotation_degrees
	)
	spring_camera.rotation = Vector3(
		deg_to_rad(-_kick_offset.x * 6.0), deg_to_rad(_kick_offset.y * 6.0), 0.0
	)
	spring_camera.position.z = decayed * kick_push
