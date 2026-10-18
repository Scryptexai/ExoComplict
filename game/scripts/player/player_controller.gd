class_name PlayerController
extends CharacterBody3D

signal shot_fired
signal weapon_changed(display_name: String)
signal health_changed(current: float, maximum: float)
signal damage_received(amount: float, current: float, maximum: float)
signal skill_used(targets_hit: int, cooldown_seconds: float)
signal skill_cooldown_changed(remaining_seconds: float, total_seconds: float)
signal defeated

const ThirdPersonCameraRigScript = preload("res://scripts/camera/camera_rig.gd")
const WeaponControllerScript = preload("res://scripts/weapons/weapon_controller.gd")

@export_range(1.0, 15.0, 0.1) var move_speed: float = 6.0
@export_range(1.0, 60.0, 0.5) var move_acceleration: float = 24.0
@export_range(10.0, 100.0, 1.0) var aim_range: float = 55.0
@export_range(1.0, 500.0, 1.0) var max_health: float = 100.0
@export_range(6.0, 30.0, 0.5) var emp_pulse_cooldown: float = 12.0
@export_range(4.0, 20.0, 0.5) var emp_pulse_radius: float = 9.0
@export_range(1.0, 100.0, 1.0) var emp_pulse_damage: float = 18.0

var current_health: float = 0.0
var _skill_cooldown_remaining: float = 0.0
var _is_defeated: bool = false
var _touch_movement: Vector2 = Vector2.ZERO
var _touch_fire_pressed: bool = false
var _character_animation_player: AnimationPlayer
var _active_character_animation: String = ""

@onready var camera_rig: ThirdPersonCameraRigScript = $CameraRig
@onready var aim_camera: Camera3D = $CameraRig/YawPivot/PitchPivot/SpringArm3D/Camera3D
@onready var visual_root: Node3D = $VisualRoot
@onready var character_model: Node = $VisualRoot/CharacterModel
@onready var muzzle: Marker3D = $VisualRoot/WeaponSocket/Muzzle
@onready var weapon_controller: WeaponControllerScript = $WeaponController


func _ready() -> void:
	current_health = max_health
	weapon_controller.weapon_changed.connect(_on_weapon_changed)
	_character_animation_player = _find_animation_player(character_model)
	_configure_character_animations()
	_set_character_animation("idle")
	health_changed.emit(current_health, max_health)


func _physics_process(delta: float) -> void:
	if _is_defeated:
		velocity = Vector3.ZERO
		_set_character_animation("idle")
		return
	_update_movement(delta)
	_update_character_animation()
	if _skill_cooldown_remaining > 0.0:
		var previous_cooldown_bucket := ceili(_skill_cooldown_remaining)
		_skill_cooldown_remaining = maxf(_skill_cooldown_remaining - delta, 0.0)
		if ceili(_skill_cooldown_remaining) != previous_cooldown_bucket:
			skill_cooldown_changed.emit(_skill_cooldown_remaining, emp_pulse_cooldown)
	if Input.is_action_just_pressed("weapon_next"):
		select_next_weapon()
	var aim_point := _get_aim_point()
	_face_aim_point(aim_point)
	var desktop_fire := Input.is_action_pressed("fire") and not _is_pointer_over_ui()
	if desktop_fire or _touch_fire_pressed:
		if weapon_controller.try_fire(self, muzzle, aim_point):
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


func activate_skill() -> bool:
	if _is_defeated or _skill_cooldown_remaining > 0.0:
		return false

	var targets_hit := 0
	var radius_squared := emp_pulse_radius * emp_pulse_radius
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node3D or not is_instance_valid(enemy):
			continue
		if enemy.has_method("is_defeated") and bool(enemy.call("is_defeated")):
			continue
		var offset: Vector3 = (enemy as Node3D).global_position - global_position
		offset.y = 0.0
		if offset.length_squared() > radius_squared or not enemy.has_method("apply_damage"):
			continue
		enemy.call("apply_damage", emp_pulse_damage, self)
		targets_hit += 1

	_skill_cooldown_remaining = emp_pulse_cooldown
	_spawn_emp_pulse_effect()
	skill_cooldown_changed.emit(_skill_cooldown_remaining, emp_pulse_cooldown)
	skill_used.emit(targets_hit, emp_pulse_cooldown)
	return true


func select_weapon(index: int) -> bool:
	return weapon_controller.select_weapon(index)


func select_next_weapon() -> bool:
	return weapon_controller.select_next_weapon()


func select_previous_weapon() -> bool:
	return weapon_controller.select_previous_weapon()


func get_current_weapon_name() -> String:
	return weapon_controller.get_current_weapon_name()


func get_active_character_animation() -> String:
	return _active_character_animation


func has_character_animation(clip_name: String) -> bool:
	return not _resolve_character_animation_name(clip_name).is_empty()


func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child in root.get_children():
		var found := _find_animation_player(child)
		if is_instance_valid(found):
			return found
	return null


func _configure_character_animations() -> void:
	if not is_instance_valid(_character_animation_player):
		return
	for clip_name in ["idle", "walk", "run"]:
		var animation_name := _resolve_character_animation_name(clip_name)
		if animation_name.is_empty():
			continue
		var animation := _character_animation_player.get_animation(animation_name)
		if is_instance_valid(animation):
			animation.loop_mode = Animation.LOOP_LINEAR


func _resolve_character_animation_name(clip_name: String) -> String:
	if not is_instance_valid(_character_animation_player):
		return ""
	var requested := clip_name.to_lower()
	for animation_name in _character_animation_player.get_animation_list():
		var normalized_name := animation_name.to_lower()
		if (
			normalized_name == requested
			or normalized_name.ends_with("/" + requested)
			or normalized_name.ends_with(":" + requested)
		):
			return animation_name
	return ""


func _set_character_animation(clip_name: String) -> void:
	if not is_instance_valid(_character_animation_player):
		return
	var animation_name := _resolve_character_animation_name(clip_name)
	if animation_name.is_empty():
		return
	if animation_name == _active_character_animation and _character_animation_player.is_playing():
		return
	_character_animation_player.play(animation_name, 0.16)
	_active_character_animation = animation_name


func _update_character_animation() -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var clip_name := "idle"
	if horizontal_speed >= move_speed * 0.65:
		clip_name = "run"
	elif horizontal_speed >= 0.15:
		clip_name = "walk"
	_set_character_animation(clip_name)


func _on_weapon_changed(display_name: String) -> void:
	weapon_changed.emit(display_name)


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
	_skill_cooldown_remaining = 0.0
	velocity = Vector3.ZERO
	_touch_movement = Vector2.ZERO
	_touch_fire_pressed = false
	health_changed.emit(current_health, max_health)
	skill_cooldown_changed.emit(0.0, emp_pulse_cooldown)


func _spawn_emp_pulse_effect() -> void:
	var pulse_mesh := TorusMesh.new()
	pulse_mesh.inner_radius = 0.91
	pulse_mesh.outer_radius = 1.0
	pulse_mesh.rings = 32
	pulse_mesh.ring_segments = 8

	var pulse_material := StandardMaterial3D.new()
	pulse_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pulse_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pulse_material.albedo_color = Color(0.2, 0.84, 1.0, 0.86)
	pulse_material.emission_enabled = true
	pulse_material.emission = Color(0.08, 0.45, 0.9)
	pulse_material.emission_energy_multiplier = 1.4

	var pulse := MeshInstance3D.new()
	pulse.name = "EmpPulseEffect"
	pulse.mesh = pulse_mesh
	pulse.material_override = pulse_material
	pulse.position = Vector3(0.0, 0.08, 0.0)
	pulse.scale = Vector3.ONE * 0.12
	pulse.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pulse)

	var pulse_tween := create_tween()
	var pulse_tweener := pulse_tween.tween_property(
		pulse, "scale", Vector3.ONE * emp_pulse_radius, 0.45
	)
	pulse_tweener.set_trans(Tween.TRANS_QUAD)
	pulse_tweener.set_ease(Tween.EASE_OUT)
	pulse_tween.tween_callback(pulse.queue_free)


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


func _is_pointer_over_ui() -> bool:
	return is_instance_valid(get_viewport().gui_get_hovered_control())


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
