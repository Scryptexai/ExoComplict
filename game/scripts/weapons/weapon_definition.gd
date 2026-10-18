class_name WeaponDefinition
extends Resource

@export var weapon_id: StringName = &""
@export var display_name: String = ""
@export_multiline var role_description: String = ""
@export var projectile_scene: PackedScene
@export_range(0.1, 20.0, 0.1) var fire_rate: float = 5.0
@export_range(1, 100, 1) var magazine_size: int = 24
@export_range(0.2, 5.0, 0.05) var reload_seconds: float = 1.35
@export_range(1.0, 500.0, 1.0) var damage: float = 18.0
@export_range(0.0, 100.0, 1.0) var projectile_speed: float = 42.0
@export_range(1.0, 100.0, 1.0) var max_range: float = 45.0
@export_flags_3d_physics var collision_mask: int = 3
@export_range(0.0, 1000.0, 1.0) var splash_damage: float = 0.0
@export_range(0.0, 20.0, 0.1) var splash_radius: float = 0.0
@export_range(0, 5, 1) var chain_count: int = 0
@export_range(0.0, 20.0, 0.1) var chain_radius: float = 0.0
@export_range(0.0, 1.0, 0.05) var chain_damage_multiplier: float = 0.7


func is_valid_definition() -> bool:
	return (
		weapon_id != &""
		and not display_name.strip_edges().is_empty()
		and is_instance_valid(projectile_scene)
		and fire_rate > 0.0
		and magazine_size > 0
		and reload_seconds > 0.0
		and damage > 0.0
		and projectile_speed >= 0.0
		and max_range > 0.0
		and splash_damage >= 0.0
		and splash_radius >= 0.0
		and (splash_damage <= 0.0 or splash_radius > 0.0)
		and chain_count >= 0
		and chain_radius >= 0.0
		and (chain_count <= 0 or chain_radius > 0.0)
		and chain_damage_multiplier >= 0.0
		and chain_damage_multiplier <= 1.0
		and (chain_count <= 0 or chain_damage_multiplier > 0.0)
	)
