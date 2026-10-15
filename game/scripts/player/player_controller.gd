class_name PlayerController
extends CharacterBody3D

signal shot_fired
signal health_changed(current: float, maximum: float)
signal damage_received(amount: float, current: float, maximum: float)
signal defeated

const ThirdPersonCameraRigScript = preload("res://scripts/camera/camera_rig.gd")
const PulseRifleScript = preload("res://scripts/weapons/pulse_rifle.gd")

@export_range(1.0, 15.0, 0.1) var move_speed: float = 6.0
@export_range(1.0, 60.0, 0.5) var move_acceleration: float = 24.0
@export_range(10.0, 100.0, 1.0) var aim_range: float = 55.0
@export_range(1.0, 500.0, 1.0) var max_health: float = 100.0

var current_health: float = 0.0
var _is_defeated: bool = false
var _touch_movement: Vector2 = Vector2.ZERO
var _touch_fire_pressed: bool = false

@onready var camera_rig: ThirdPersonCameraRigScript = $CameraRig
@onready var aim_camera: Camera3D = $CameraRig/YawPivot/PitchPivot/SpringArm3D/Camera3D
@onready var visual_root: Node3D = $VisualRoot
@onready var muzzle: Marker3D = $VisualRoot/WeaponSocket/Muzzle
@onready var pulse_rifle: PulseRifleScript = $PulseRifle


func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)


func _physics_process(delta: float) -> void:
	if _is_defeated:
		velocity = Vector3.ZERO
		return
	_update_movement(delta)
	var aim_point := _get_aim_point()
	_face_aim_point(aim_point)
	if Input.is_action_pressed("fire") or _touch_fire_pressed:
		if pulse_rifle.try_fire(self, muzzle, aim_point):
			shot_fired.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_rig.apply_look_delta(event.relative)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func set_touch_movement(value: Vector2) -> void:
	_touch_movement = value.limit_length(1.0)


func apply_touch_look(delta: Vector2) -> void:
	camera_rig.apply_look_delta(delta)


func set_touch_fire_pressed(pressed: bool) -> void:
	_touch_fire_pressed = pressed


func can_take_damage() -> bool:
	return not _is_defeated


func apply_damage(amount: float, _source: Node = null) -> void:
	if _is_defeated or amount <= 0.0:
		return

	var applied_damage := minf(amount, current_health)
	current_health = maxf(current_health - applied_damage, 0.0)
	damage_received.emit(applied_damage, current_health, max_health)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		_is_defeated = true
		_touch_fire_pressed = false
		_touch_movement = Vector2.ZERO
		defeated.emit()


func is_defeated() -> bool:
	return _is_defeated


func reset_player() -> void:
	_is_defeated = false
	current_health = max_health
	velocity = Vector3.ZERO
	_touch_movement = Vector2.ZERO
	_touch_fire_pressed = false
	health_changed.emit(current_health, max_health)


func _update_movement(delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if _touch_movement.length_squared() > 0.0001:
		input_vector = _touch_movement

	var camera_basis := camera_rig.get_yaw_basis()
	var forward := -camera_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := camera_basis.x
	right.y = 0.0
	right = right.normalized()
	var move_direction := (right * input_vector.x - forward * input_vector.y).limit_length(1.0)
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var desired_velocity := move_direction * move_speed
	horizontal_velocity = horizontal_velocity.move_toward(
		desired_velocity, move_acceleration * delta
	)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	if not is_on_floor():
		velocity.y -= float(ProjectSettings.get_setting("physics/3d/default_gravity")) * delta
	else:
		velocity.y = 0.0
	move_and_slide()


func _get_aim_point() -> Vector3:
	var viewport_size := aim_camera.get_viewport().get_visible_rect().size
	var screen_center := viewport_size * 0.5
	var ray_origin := aim_camera.project_ray_origin(screen_center)
	var ray_direction := aim_camera.project_ray_normal(screen_center)
	var ray_end := ray_origin + ray_direction * aim_range
	var excluded_rids: Array[RID] = [get_rid()]
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, 3, excluded_rids)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var hit_position: Vector3 = hit.get("position", ray_end)
		return hit_position
	return ray_end


func _face_aim_point(aim_point: Vector3) -> void:
	var flat_direction := aim_point - global_position
	flat_direction.y = 0.0
	if flat_direction.length_squared() <= 0.0001:
		return
	flat_direction = flat_direction.normalized()
	visual_root.rotation.y = atan2(-flat_direction.x, -flat_direction.z)
