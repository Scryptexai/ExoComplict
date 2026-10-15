class_name PulseRifle
extends Node

signal shot_fired

@export var projectile_scene: PackedScene
@export_range(0.5, 20.0, 0.1) var fire_rate: float = 5.0
@export_range(1.0, 100.0, 1.0) var damage: float = 18.0
@export_range(5.0, 100.0, 1.0) var projectile_speed: float = 42.0
@export_range(5.0, 100.0, 1.0) var max_range: float = 45.0

var _cooldown: float = 0.0


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)


func try_fire(shooter: CollisionObject3D, muzzle: Marker3D, aim_point: Vector3) -> bool:
	if _cooldown > 0.0 or projectile_scene == null:
		return false

	var projectile := projectile_scene.instantiate() as Node3D
	if projectile == null:
		push_error("Pulse Rifle projectile scene root must be a Node3D.")
		return false

	var current_scene := get_tree().current_scene
	if current_scene == null:
		projectile.queue_free()
		return false

	current_scene.add_child(projectile)
	projectile.call(
		"launch", muzzle.global_position, aim_point, shooter, damage, projectile_speed, max_range
	)
	_cooldown = 1.0 / maxf(fire_rate, 0.1)
	shot_fired.emit()
	return true
