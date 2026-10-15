class_name PulseProjectile
extends Node3D

@export var collision_mask: int = 3

var _direction: Vector3 = Vector3.FORWARD
var _damage: float = 18.0
var _speed: float = 42.0
var _remaining_range: float = 45.0
var _shooter: CollisionObject3D


func launch(
	start_position: Vector3,
	aim_point: Vector3,
	shooter: CollisionObject3D,
	damage: float,
	speed: float,
	max_range: float
) -> void:
	global_position = start_position
	_direction = aim_point - start_position
	if _direction.length_squared() < 0.0001:
		_direction = -global_basis.z
	_direction = _direction.normalized()
	_shooter = shooter
	_damage = damage
	_speed = speed
	_remaining_range = max_range
	look_at(global_position + _direction, Vector3.UP)


func _physics_process(delta: float) -> void:
	if _remaining_range <= 0.0:
		queue_free()
		return

	var step_distance := minf(_speed * delta, _remaining_range)
	var next_position := global_position + _direction * step_distance
	var excluded_rids: Array[RID] = []
	if is_instance_valid(_shooter):
		excluded_rids.append(_shooter.get_rid())

	var query := PhysicsRayQueryParameters3D.create(
		global_position, next_position, collision_mask, excluded_rids
	)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var collider: Object = hit.get("collider")
		if collider != null and collider.has_method("apply_damage"):
			collider.call("apply_damage", _damage, _shooter)
		var hit_position: Vector3 = hit.get("position", next_position)
		global_position = hit_position
		queue_free()
		return

	global_position = next_position
	_remaining_range -= step_distance
