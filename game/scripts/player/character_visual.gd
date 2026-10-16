class_name CharacterVisual
extends Node3D

## Presentation layer for the player avatar.
##
## The gameplay body is a CharacterBody3D with a capsule collider; everything the
## camera sees lives under this node. A GLB model (the Kenney "space kit"
## astronaut already vendored in this repository) is instantiated, measured and
## fitted to a target height, so swapping the model never needs hand-tuned scale
## numbers.
##
## Motion is procedural on purpose: the kit models are static meshes with no rig,
## so walking bob, strafe lean, run pitch and recoil are driven here from the
## controller's velocity. If the model is missing, the fallback capsule stays
## visible instead of leaving the player invisible.

@export var model_scene: PackedScene
@export var weapon_scene: PackedScene
@export_range(1.0, 2.4, 0.01) var target_height: float = 1.78
@export_range(0.2, 2.0, 0.01) var weapon_length: float = 0.86
@export_range(-180.0, 180.0, 1.0) var weapon_yaw_offset_degrees: float = 0.0
@export_range(-45.0, 45.0, 0.5) var weapon_pitch_degrees: float = -4.0
@export_range(-180.0, 180.0, 1.0) var model_yaw_offset_degrees: float = 180.0
@export_range(0.0, 2.0, 0.01) var bob_amplitude: float = 0.04
@export_range(0.0, 12.0, 0.1) var bob_frequency: float = 7.0
@export_range(0.0, 30.0, 0.5) var strafe_roll_degrees: float = 6.0
@export_range(0.0, 30.0, 0.5) var run_pitch_degrees: float = 5.0
@export_range(1.0, 30.0, 0.5) var move_speed_reference: float = 6.0
@export_range(60.0, 2000.0, 10.0) var aiming_turn_speed_degrees: float = 900.0
@export_range(30.0, 900.0, 10.0) var free_turn_speed_degrees: float = 320.0
@export_range(0.0, 0.5, 0.005) var recoil_kick: float = 0.05

var _model: Node3D
var _model_bounds: AABB
var _model_height: float = 0.0
var _facing_yaw: float = 0.0
var _bob_phase: float = 0.0
var _bob_offset: float = 0.0
var _roll_degrees: float = 0.0
var _pitch_degrees: float = 0.0
var _recoil_remaining: float = 0.0
var _recoil_duration: float = 0.16
var _aiming: bool = false
var _weapon_socket_base_position: Vector3 = Vector3.ZERO
var _weapon_socket_base_rotation: Vector3 = Vector3.ZERO

@onready var _fallback_body: MeshInstance3D = get_node_or_null("BodyMesh")
@onready var _weapon_socket: Node3D = get_node_or_null("WeaponSocket")


func _ready() -> void:
	_spawn_model()
	_spawn_weapon()


func has_model() -> bool:
	return _model != null and is_instance_valid(_model)


func model_height() -> float:
	return _model_height


func is_aiming() -> bool:
	return _aiming


## Height of the avatar as rendered (after the model was fitted), in metres.
## The camera uses it to frame the player; 1.8 is the capsule fallback.
func visual_height() -> float:
	return _model_height if has_model() else 1.8


func walk_intensity() -> float:
	return absf(_bob_offset) / maxf(bob_amplitude, 0.0001)


func set_aiming(value: bool) -> void:
	_aiming = value


func play_recoil(strength: float = 1.0, duration: float = 0.16) -> void:
	_recoil_duration = maxf(duration, 0.01)
	_recoil_remaining = maxf(_recoil_remaining, _recoil_duration * clampf(strength, 0.2, 2.0))


func recoil_ratio() -> float:
	if _recoil_duration <= 0.0:
		return 0.0
	return clampf(_recoil_remaining / _recoil_duration, 0.0, 1.0)


## Decide which way the avatar looks. Aiming wins, then movement, then a slow
## turn towards the aim point so an idle player still faces the crosshair.
func update_facing(aim_point: Vector3, velocity: Vector3, aim_active: bool, delta: float) -> void:
	var desired_yaw := _facing_yaw
	var turn_speed := free_turn_speed_degrees
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if aim_active:
		var to_aim := aim_point - global_position
		to_aim.y = 0.0
		if to_aim.length_squared() > 0.0004:
			desired_yaw = atan2(-to_aim.x, -to_aim.z)
			turn_speed = aiming_turn_speed_degrees
	elif horizontal.length_squared() > 0.04:
		desired_yaw = atan2(-horizontal.x, -horizontal.z)
	else:
		var to_idle_aim := aim_point - global_position
		to_idle_aim.y = 0.0
		if to_idle_aim.length_squared() > 0.0004:
			desired_yaw = atan2(-to_idle_aim.x, -to_idle_aim.z)
	_facing_yaw = rotate_toward(_facing_yaw, desired_yaw, deg_to_rad(turn_speed) * delta)


func update_pose(velocity: Vector3, grounded: bool, delta: float) -> void:
	var horizontal := Vector2(velocity.x, velocity.z)
	var speed_ratio := clampf(horizontal.length() / maxf(move_speed_reference, 0.001), 0.0, 1.4)
	var target_bob := 0.0
	var target_roll := 0.0
	var target_pitch := 0.0

	if grounded and speed_ratio > 0.02:
		_bob_phase = fmod(_bob_phase + bob_frequency * speed_ratio * delta, TAU)
		target_bob = sin(_bob_phase) * bob_amplitude * minf(speed_ratio, 1.0)
		# Strafing rolls the avatar into the turn; running pitches it forward.
		var local_side := (global_transform.basis.inverse() * velocity).x
		target_roll = -local_side / maxf(move_speed_reference, 0.001) * strafe_roll_degrees
		target_pitch = speed_ratio * run_pitch_degrees
	else:
		_bob_phase = 0.0

	if _aiming:
		# Aiming stills the body: no bob, minimal lean.
		target_bob = 0.0
		target_roll *= 0.3
		target_pitch *= 0.4

	var blend := 9.0 * delta
	_bob_offset = lerpf(_bob_offset, target_bob, blend)
	_roll_degrees = lerpf(_roll_degrees, target_roll, blend)
	_pitch_degrees = lerpf(_pitch_degrees, target_pitch, blend)

	if _recoil_remaining > 0.0:
		_recoil_remaining = maxf(_recoil_remaining - delta, 0.0)
	_apply_pose()


func _apply_pose() -> void:
	var kick := recoil_ratio()
	rotation.y = _facing_yaw
	rotation.x = deg_to_rad(_pitch_degrees + kick * 4.5)
	rotation.z = deg_to_rad(_roll_degrees)
	position.y = _bob_offset
	if is_instance_valid(_weapon_socket):
		_weapon_socket.position.z = _weapon_socket_base_position.z + kick * recoil_kick
		_weapon_socket.rotation.x = _weapon_socket_base_rotation.x - kick * 0.36


func _spawn_model() -> void:
	if is_instance_valid(_weapon_socket):
		_weapon_socket_base_position = _weapon_socket.position
		_weapon_socket_base_rotation = _weapon_socket.rotation
	if model_scene == null:
		_keep_fallback("no model assigned")
		return

	var instance := model_scene.instantiate()
	if not instance is Node3D:
		_keep_fallback("model did not instantiate as Node3D")
		return

	# The kit models are authored facing +Z while the game's forward is -Z, so the
	# avatar is turned by a dedicated pivot. Centring happens *inside* that pivot:
	# compensating on the rotated node itself would push the model away from the
	# player by twice the offset (that bug made the avatar render ~9 m off-centre).
	_model = instance as Node3D
	_model.name = "CharacterModel"
	var model_pivot := Node3D.new()
	model_pivot.name = "ModelPivot"
	model_pivot.rotation.y = deg_to_rad(model_yaw_offset_degrees)
	add_child(model_pivot)
	model_pivot.add_child(_model)
	_fit_model()

	if _model_height <= 0.001:
		_model.queue_free()
		_model = null
		_keep_fallback("model has no measurable mesh")
		return

	_apply_outline(_model)
	if is_instance_valid(_fallback_body):
		_fallback_body.visible = false
	# One line in the console/log: which model the avatar actually got, how tall it
	# renders and whether the fallback is in use. Read from the browser console
	# during web QA and from the editor log on device.
	print(
		(
			"CharacterVisual: model=%s fitted_height=%.3fm scale=%.3f fallback=no"
			% [_model.name, _model_height, _model.scale.y]
		)
	)


func _spawn_weapon() -> void:
	if weapon_scene == null or not is_instance_valid(_weapon_socket):
		return
	var instance := weapon_scene.instantiate()
	if not instance is Node3D:
		push_warning("CharacterVisual: weapon scene did not instantiate as Node3D.")
		return
	var weapon := instance as Node3D
	weapon.name = "WeaponModel"
	_weapon_socket.add_child(weapon)

	var bounds := _combined_bounds(weapon)
	if bounds.size.length() <= 0.0001:
		weapon.queue_free()
		return
	# Kit models are authored along different axes; put the longest side on -Z so
	# the barrel always points where the aim ray goes.
	var longest := _longest_axis(bounds.size)
	var axis_rotation := Vector3.ZERO
	if longest == 0:
		axis_rotation.y = deg_to_rad(90.0)
	elif longest == 1:
		axis_rotation.x = deg_to_rad(-90.0)
	weapon.rotation = Vector3(
		axis_rotation.x + deg_to_rad(weapon_pitch_degrees),
		axis_rotation.y + deg_to_rad(weapon_yaw_offset_degrees),
		axis_rotation.z
	)
	# Re-measure after the rotation: the long side now runs along Z.
	var rotated_bounds := _combined_bounds(weapon)
	var length := maxf(rotated_bounds.size.z, 0.0001)
	var fit := weapon_length / length
	weapon.scale = Vector3.ONE * fit
	var center := rotated_bounds.position + rotated_bounds.size * 0.5
	weapon.position = Vector3(-center.x * fit, -center.y * fit, -center.z * fit)


static func _longest_axis(size_vector: Vector3) -> int:
	if size_vector.x >= size_vector.y and size_vector.x >= size_vector.z:
		return 0
	if size_vector.y >= size_vector.z:
		return 1
	return 2


## A dark rim around every mesh of the avatar. The world is bright and the kit
## suit is light, so without it the player reads as a pale smudge against the
## floor; an unshaded overlay grown past the surface keeps the silhouette legible
## from any camera angle and costs one extra draw per surface.
func _apply_outline(root: Node3D) -> void:
	var outline := StandardMaterial3D.new()
	outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline.albedo_color = Color(0.02, 0.05, 0.09, 1.0)
	outline.cull_mode = BaseMaterial3D.CULL_FRONT
	outline.grow = true
	outline.grow_amount = 0.022
	outline.no_depth_test = false
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if is_instance_valid(mesh_instance):
			mesh_instance.material_overlay = outline


func _keep_fallback(reason: String) -> void:
	push_warning("CharacterVisual: using the fallback capsule (%s)." % reason)
	if is_instance_valid(_fallback_body):
		_fallback_body.visible = true


func _fit_model() -> void:
	_model_bounds = _combined_bounds(_model)
	if _model_bounds.size.y <= 0.0001:
		_model_height = 0.0
		return

	var fit_scale := target_height / _model_bounds.size.y
	# report the fitted height: callers care about how tall the avatar renders,
	# not how the GLB happened to be authored.
	_model_height = _model_bounds.size.y * fit_scale
	var center := _model_bounds.position + _model_bounds.size * 0.5
	_model.scale = Vector3.ONE * fit_scale
	# Feet on the origin, body centred over the collider.
	_model.position = Vector3(
		-center.x * fit_scale, -_model_bounds.position.y * fit_scale, -center.z * fit_scale
	)


## Bounds of every mesh under [param root], expressed in root-local space.
func _combined_bounds(root: Node3D) -> AABB:
	var has_bounds := false
	var combined := AABB()
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if not is_instance_valid(mesh_instance) or mesh_instance.mesh == null:
			continue
		var relative := _local_transform_within(root, mesh_instance)
		var converted := _transform_aabb(mesh_instance.get_aabb(), relative)
		combined = converted if not has_bounds else combined.merge(converted)
		has_bounds = true
	return combined


## Transform of [param node] relative to [param root], built by walking parents so
## nested GLTF nodes are measured correctly without relying on global transforms.
static func _local_transform_within(root: Node3D, node: Node3D) -> Transform3D:
	var chain: Array[Node3D] = []
	var current: Node = node
	while current != null and current != root:
		if current is Node3D:
			chain.append(current as Node3D)
		current = current.get_parent()
	var result := Transform3D.IDENTITY
	for index in range(chain.size() - 1, -1, -1):
		result = result * chain[index].transform
	return result


static func _transform_aabb(bounds: AABB, transform: Transform3D) -> AABB:
	var min_corner := Vector3.INF
	var max_corner := -Vector3.INF
	for corner_index in range(8):
		var local_corner := bounds.position
		if (corner_index & 1) != 0:
			local_corner.x += bounds.size.x
		if (corner_index & 2) != 0:
			local_corner.y += bounds.size.y
		if (corner_index & 4) != 0:
			local_corner.z += bounds.size.z
		var transformed := transform * local_corner
		min_corner = min_corner.min(transformed)
		max_corner = max_corner.max(transformed)
	return AABB(min_corner, max_corner - min_corner)
