extends Node3D

@export var arena_width: float = 30.0
@export var arena_depth: float = 30.0
@export var wall_height: float = 3.6


func _ready() -> void:
	var floor_material := _make_material(Color(0.035, 0.065, 0.085), 0.18, 0.82)
	var wall_material := _make_material(Color(0.055, 0.12, 0.16), 0.34, 0.58)
	var cover_material := _make_material(Color(0.12, 0.26, 0.31), 0.48, 0.4)
	var low_cover_material := _make_material(Color(0.16, 0.31, 0.34), 0.34, 0.62)
	var relay_material := _make_material(Color(0.07, 0.18, 0.23), 0.55, 0.38)
	var cyan_accent := _make_emissive_material(Color(0.08, 0.62, 0.78), 0.65)
	var amber_accent := _make_emissive_material(Color(0.95, 0.32, 0.08), 0.45)

	_add_box(
		"ArenaFloor",
		Vector3(0.0, -0.5, 0.0),
		Vector3(arena_width, 1.0, arena_depth),
		floor_material
	)
	_add_box(
		"NorthWall",
		Vector3(0.0, wall_height * 0.5, -arena_depth * 0.5),
		Vector3(arena_width, wall_height, 0.6),
		wall_material
	)
	_add_box(
		"SouthWall",
		Vector3(0.0, wall_height * 0.5, arena_depth * 0.5),
		Vector3(arena_width, wall_height, 0.6),
		wall_material
	)
	_add_box(
		"WestWall",
		Vector3(-arena_width * 0.5, wall_height * 0.5, 0.0),
		Vector3(0.6, wall_height, arena_depth),
		wall_material
	)
	_add_box(
		"EastWall",
		Vector3(arena_width * 0.5, wall_height * 0.5, 0.0),
		Vector3(0.6, wall_height, arena_depth),
		wall_material
	)

	_add_box("CoverWest", Vector3(-4.0, 0.8, 0.0), Vector3(2.0, 1.6, 1.2), cover_material)
	_add_box("CoverEast", Vector3(4.0, 0.8, -3.0), Vector3(2.0, 1.6, 1.2), cover_material)
	_add_box(
		"CoverNorthWest", Vector3(-6.3, 0.65, -6.0), Vector3(2.6, 1.3, 1.1), low_cover_material
	)
	_add_box("CoverNorthEast", Vector3(6.3, 0.9, -6.5), Vector3(1.6, 1.8, 2.0), cover_material)
	_add_box("CoverSouthWest", Vector3(-6.0, 0.75, 6.0), Vector3(2.8, 1.5, 1.0), cover_material)
	_add_box("CoverSouthEast", Vector3(4.6, 0.55, 7.0), Vector3(2.6, 1.1, 1.1), low_cover_material)

	_add_box("RelayCore", Vector3(-1.8, 1.2, 0.0), Vector3(1.2, 2.4, 1.2), relay_material)
	_add_visual_box(
		"RelayCoreStatusPanel", Vector3(-1.8, 1.35, 0.62), Vector3(0.7, 1.2, 0.035), cyan_accent
	)
	_add_visual_box(
		"RelayRingNorth", Vector3(0.0, 0.025, -2.1), Vector3(4.2, 0.025, 0.08), cyan_accent
	)
	_add_visual_box(
		"RelayRingSouth", Vector3(0.0, 0.025, 2.1), Vector3(4.2, 0.025, 0.08), cyan_accent
	)
	_add_visual_box(
		"RelayRingWest", Vector3(-2.1, 0.025, 0.0), Vector3(0.08, 0.025, 4.2), cyan_accent
	)
	_add_visual_box(
		"RelayRingEast", Vector3(2.1, 0.025, 0.0), Vector3(0.08, 0.025, 4.2), cyan_accent
	)

	_add_box("ServiceDeck", Vector3(11.3, 0.25, 5.5), Vector3(3.0, 0.5, 3.0), cover_material)
	_add_box(
		"ServiceRamp",
		Vector3(8.1, 0.25, 5.5),
		Vector3(3.4, 0.16, 2.4),
		low_cover_material,
		Vector3(0.0, 0.0, 8.5)
	)
	_add_visual_box(
		"ServiceDeckStripe", Vector3(11.3, 0.52, 5.5), Vector3(2.0, 0.025, 0.08), amber_accent
	)
	_add_visual_box(
		"ServiceRampStripe",
		Vector3(8.1, 0.36, 5.5),
		Vector3(2.5, 0.025, 0.07),
		amber_accent,
		Vector3(0.0, 0.0, 8.5)
	)

	_add_visual_box(
		"SouthLaneMarking", Vector3(0.0, 0.018, 8.0), Vector3(0.1, 0.02, 10.0), cyan_accent
	)
	_add_visual_box(
		"NorthLaneMarking", Vector3(0.0, 0.018, -8.0), Vector3(0.1, 0.02, 10.0), cyan_accent
	)
	_add_spawn_beacons(amber_accent)
	_add_key_light()
	_add_world_environment()


func _add_spawn_beacons(material: Material) -> void:
	var spawn_points := get_node_or_null("../SpawnPoints") as Node3D
	if spawn_points == null:
		return

	for marker in spawn_points.get_children():
		if not marker is Marker3D:
			continue
		var beacon := MeshInstance3D.new()
		beacon.name = "%s_Beacon" % marker.name
		var disc := CylinderMesh.new()
		disc.top_radius = 0.72
		disc.bottom_radius = 0.72
		disc.height = 0.035
		disc.radial_segments = 16
		beacon.mesh = disc
		beacon.material_override = material
		beacon.position = to_local((marker as Marker3D).global_position) + Vector3.UP * 0.025
		add_child(beacon)


func _add_box(
	node_name: String,
	center: Vector3,
	dimensions: Vector3,
	material: Material,
	rotation_degrees: Vector3 = Vector3.ZERO
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = center
	body.rotation_degrees = rotation_degrees
	add_child(body)

	var shape := BoxShape3D.new()
	shape.size = dimensions
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)

	var box_mesh := BoxMesh.new()
	box_mesh.size = dimensions
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	return body


func _add_visual_box(
	node_name: String,
	center: Vector3,
	dimensions: Vector3,
	material: Material,
	rotation_degrees: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var box_mesh := BoxMesh.new()
	box_mesh.size = dimensions
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = center
	mesh_instance.rotation_degrees = rotation_degrees
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = material
	add_child(mesh_instance)
	return mesh_instance


func _make_material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


func _make_emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := _make_material(color, 0.18, 0.45)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


func _add_key_light() -> void:
	var light := DirectionalLight3D.new()
	light.name = "GreyboxKeyLight"
	light.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	light.light_energy = 1.25
	light.shadow_enabled = false
	add_child(light)


func _add_world_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.008, 0.022, 0.034)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.22, 0.38, 0.48)
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	var world_environment := WorldEnvironment.new()
	world_environment.name = "ArenaEnvironment"
	world_environment.environment = environment
	add_child(world_environment)
