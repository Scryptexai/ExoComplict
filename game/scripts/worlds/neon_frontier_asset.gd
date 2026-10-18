@tool
extends Node3D

const ScifiBayBuilder = preload("res://scripts/worlds/scifi_bay_builder.gd")

@export_enum(
	"reactor_core",
	"command_center",
	"research_lab",
	"equipment_depot",
	"generator_bank",
	"boss_gate",
	"defense_turret",
	"sensor_tower",
	"landing_pad",
	"wrecked_transport",
	"alien_drone_wreck",
	"crystal_cluster",
	"alien_flora",
	"rock_cluster",
	"enemy_spawn_gate",
	"cover_module"
)
var asset_kind: String = "reactor_core"
@export_range(0, 9999, 1) var variant_seed: int = 0

var _materials: Dictionary = {}
var _built: bool = false


func _ready() -> void:
	if _built or not get_children().is_empty():
		return
	_built = true
	_create_materials()
	match asset_kind:
		"reactor_core":
			_build_reactor_core()
		"command_center":
			_build_command_center()
		"research_lab":
			_build_research_lab()
		"equipment_depot":
			_build_equipment_depot()
		"generator_bank":
			_build_generator_bank()
		"boss_gate":
			_build_boss_gate()
		"defense_turret":
			_build_defense_turret()
		"sensor_tower":
			_build_sensor_tower()
		"landing_pad":
			_build_landing_pad()
		"wrecked_transport":
			_build_wrecked_transport()
		"alien_drone_wreck":
			_build_alien_drone_wreck()
		"crystal_cluster":
			_build_crystal_cluster()
		"alien_flora":
			_build_alien_flora()
		"rock_cluster":
			_build_rock_cluster()
		"enemy_spawn_gate":
			_build_enemy_spawn_gate()
		"cover_module":
			_build_cover_module()


func _create_materials() -> void:
	_materials = {
		"silver": _make_material(Color(0.36, 0.43, 0.48), 0.56, 0.43),
		"pearl": _make_material(Color(0.58, 0.65, 0.7), 0.15, 0.5),
		"ceramic": _make_material(Color(0.43, 0.52, 0.58), 0.23, 0.5),
		"blue": _make_material(Color(0.055, 0.15, 0.28), 0.46, 0.4),
		"deep_blue": _make_material(Color(0.025, 0.08, 0.18), 0.5, 0.44),
		"cyan": _make_emissive(Color(0.02, 0.53, 0.7), 0.78),
		"turquoise": _make_emissive(Color(0.015, 0.6, 0.52), 0.7),
		# The reactor's big glass and energy shapes were becoming a white/cyan
		# billboard in portrait; reserve the brightest values for slim halos.
		"reactor_core": _make_emissive(Color(0.02, 0.3, 0.37), 0.27),
		"reactor_spine": _make_material(Color(0.07, 0.16, 0.19), 0.62, 0.38),
		"reactor_coils": _make_emissive(Color(0.08, 0.64, 0.58), 0.75),
		"emerald": _make_emissive(Color(0.08, 0.53, 0.33), 0.58),
		"yellow": _make_emissive(Color(0.9, 0.54, 0.065), 0.43),
		"orange": _make_emissive(Color(1.0, 0.27, 0.035), 0.95),
		"red": _make_emissive(Color(0.98, 0.045, 0.055), 1.25),
		"dark_trim": _make_material(Color(0.105, 0.17, 0.2), 0.66, 0.36),
		"rock": _make_material(Color(0.59, 0.43, 0.34), 0.02, 0.93),
		"rock_light": _make_material(Color(0.76, 0.58, 0.42), 0.02, 0.88),
		"rock_rose": _make_material(Color(0.64, 0.39, 0.37), 0.03, 0.9),
		"glass": _make_translucent(Color(0.09, 0.48, 0.61, 0.2), 0.25, 0.2),
		"reactor_glass": _make_translucent(Color(0.07, 0.34, 0.42, 0.085), 0.25, 0.2),
		"flora": _make_material(Color(0.19, 0.64, 0.35), 0.0, 0.72),
		"flora_lime": _make_emissive(Color(0.51, 0.87, 0.17), 0.25),
		"flora_teal": _make_material(Color(0.04, 0.58, 0.54), 0.05, 0.52),
		"copper": _make_material(Color(0.76, 0.32, 0.13), 0.65, 0.34),
	}


func _make_material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


func _make_emissive(color: Color, strength: float) -> StandardMaterial3D:
	var material := _make_material(color, 0.28, 0.28)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = strength
	return material


func _make_translucent(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := _make_material(color, metallic, roughness)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return material


func _box(
	node_name: String,
	at: Vector3,
	size: Vector3,
	material: Material,
	rotation: Vector3 = Vector3.ZERO,
	collidable: bool = false
) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.rotation_degrees = rotation
	add_child(instance)
	if collidable:
		_add_box_collider(node_name + "Collision", at, size, rotation)
	return instance


func _add_box_collider(
	node_name: String, at: Vector3, size: Vector3, rotation: Vector3 = Vector3.ZERO
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = at
	body.rotation_degrees = rotation
	body.collision_layer = 1
	body.collision_mask = 0
	var collision_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision_shape.shape = shape
	body.add_child(collision_shape)
	add_child(body)
	return body


func _cylinder(
	node_name: String,
	at: Vector3,
	bottom_radius: float,
	top_radius: float,
	height: float,
	material: Material,
	rotation: Vector3 = Vector3.ZERO,
	radial_segments: int = 24
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom_radius
	mesh.top_radius = top_radius
	mesh.height = height
	mesh.radial_segments = radial_segments
	mesh.rings = 1
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.rotation_degrees = rotation
	add_child(instance)
	return instance


func _sphere(
	node_name: String,
	at: Vector3,
	size: Vector3,
	material: Material,
	rotation: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 16
	mesh.rings = 10
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.scale = size
	instance.rotation_degrees = rotation
	add_child(instance)
	return instance


func _link_cylinder(
	node_name: String, start: Vector3, finish: Vector3, radius: float, material: Material
) -> MeshInstance3D:
	var direction := finish - start
	var length := direction.length()
	var instance := _cylinder(
		node_name, (start + finish) * 0.5, radius, radius, length, material, Vector3.ZERO, 16
	)
	if length > 0.001:
		instance.basis = Basis(Quaternion(Vector3.UP, direction / length))
	return instance


func _ring(
	node_name: String,
	center: Vector3,
	radius: float,
	y: float,
	thickness: float,
	material: Material,
	segments: int = 20
) -> void:
	var segment_length := 2.0 * radius * sin(PI / float(segments))
	for segment in range(segments):
		var angle := TAU * float(segment) / float(segments)
		var midpoint_angle := angle + PI / float(segments)
		var at := center + Vector3(cos(midpoint_angle) * radius, y, sin(midpoint_angle) * radius)
		var yaw_degrees := rad_to_deg(midpoint_angle - PI * 0.5)
		_box(
			"%s_%02d" % [node_name, segment],
			at,
			Vector3(segment_length * 1.06, thickness, thickness),
			material,
			Vector3(0.0, yaw_degrees, 0.0)
		)


func _reactor_coils() -> MeshInstance3D:
	# One small mesh, not ten extra glowing cylinders/draw calls. Keeping dark
	# gaps between these powered bands breaks the old six-metre green billboard
	# without removing the uploaded-FBX columns and cladding around the reactor.
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for tier in range(10):
		var height := 4.38 + float(tier) * 0.59
		var radius := lerpf(0.98, 0.78, float(tier) / 9.0)
		for segment in range(24):
			var angle := TAU * float(segment) / 24.0
			var next_angle := TAU * float(segment + 1) / 24.0
			var lower := Vector3(cos(angle) * radius, height, sin(angle) * radius)
			var upper := lower + Vector3.UP * 0.075
			var next_lower := Vector3(cos(next_angle) * radius, height, sin(next_angle) * radius)
			var next_upper := next_lower + Vector3.UP * 0.075
			vertices.append_array(
				PackedVector3Array([lower, upper, next_lower, upper, next_upper, next_lower])
			)
			var normal := Vector3(cos(angle), 0.0, sin(angle))
			var next_normal := Vector3(cos(next_angle), 0.0, sin(next_angle))
			normals.append_array(
				PackedVector3Array([normal, normal, next_normal, normal, next_normal, next_normal])
			)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var coils := MeshInstance3D.new()
	coils.name = "ReactorCoils"
	coils.mesh = mesh
	coils.material_override = _materials["reactor_coils"]
	coils.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(coils)
	return coils


func _add_bolts(
	prefix: String, center: Vector3, half_size: Vector2, y: float, material: Material
) -> void:
	for x_sign in [-1.0, 1.0]:
		for z_sign in [-1.0, 1.0]:
			_cylinder(
				"%s_Bolt_%s_%s" % [prefix, str(x_sign), str(z_sign)],
				center + Vector3(half_size.x * x_sign, y, half_size.y * z_sign),
				0.055,
				0.055,
				0.035,
				material,
				Vector3.ZERO,
				10
			)


func _build_reactor_core() -> void:
	# Four separated footings support the suspended reactor while keeping combat lanes open.
	for x_sign in [-1.0, 1.0]:
		for z_sign in [-1.0, 1.0]:
			_box(
				"ReactorFoundation_%s_%s" % [str(x_sign), str(z_sign)],
				Vector3(x_sign * 4.7, 0.09, z_sign * 4.7),
				Vector3(3.4, 0.18, 3.4),
				_materials["silver"]
			)
			_box(
				"ReactorFootingStripe_%s_%s" % [str(x_sign), str(z_sign)],
				Vector3(x_sign * 4.7, 0.2, z_sign * 4.7),
				Vector3(2.8, 0.04, 2.8),
				_materials["yellow"]
			)
	_box(
		"ReactorAccessWalk", Vector3(0.0, 0.08, 6.0), Vector3(2.2, 0.16, 2.0), _materials["silver"]
	)
	for side in [-1.0, 1.0]:
		_box(
			"ReactorConduit_%s" % str(side),
			Vector3(side * 6.6, 0.52, 0.0),
			Vector3(2.4, 0.34, 1.0),
			_materials["copper"]
		)
		_box(
			"ReactorConduitGlow_%s" % str(side),
			Vector3(side * 6.6, 0.72, 0.0),
			Vector3(2.0, 0.05, 0.2),
			_materials["orange"]
		)

	# Four load-bearing pylons frame a clear walkable and line-of-fire opening below the core.
	for x_sign in [-1.0, 1.0]:
		for z_sign in [-1.0, 1.0]:
			var pylon_x: float = 4.35 * x_sign
			var pylon_z: float = 4.35 * z_sign
			_cylinder(
				"ReactorPylonFoot_%s_%s" % [str(x_sign), str(z_sign)],
				Vector3(pylon_x, 0.55, pylon_z),
				0.8,
				0.58,
				0.7,
				_materials["copper"]
			)
			# Keep the old mesh as an editable structural fallback, but dress the
			# visible load-bearing pylon with the user's imported FBX column.
			var blockout_pylon := _box(
				"ReactorPylon_%s_%s" % [str(x_sign), str(z_sign)],
				Vector3(pylon_x, 4.55, pylon_z),
				Vector3(0.72, 7.2, 0.72),
				_materials["pearl"]
			)
			blockout_pylon.visible = false
			ScifiBayBuilder.place(
				self,
				"column",
				"SciFiReactorPylon_%s_%s" % [str(x_sign), str(z_sign)],
				Vector3(pylon_x, 0.95, pylon_z),
				0.0,
				1.0,
				true,
				true,
				Vector3(0.2, 1.8, 1.6)
			)
			_box(
				"ReactorPylonLight_%s_%s" % [str(x_sign), str(z_sign)],
				Vector3(pylon_x * 1.095, 5.0, pylon_z * 1.095),
				Vector3(0.09, 5.4, 0.09),
				_materials["cyan"]
			)
			_box(
				"ReactorPylonBrace_%s_%s" % [str(x_sign), str(z_sign)],
				Vector3(pylon_x * 0.73, 2.1, pylon_z * 0.73),
				Vector3(0.34, 2.5, 0.34),
				_materials["blue"],
				Vector3(18.0 * z_sign, 0.0, -18.0 * x_sign)
			)

	_cylinder(
		"ContainmentGlass",
		Vector3(0.0, 7.0, 0.0),
		2.45,
		2.45,
		5.6,
		_materials["reactor_glass"],
		Vector3.ZERO,
		32
	)
	_cylinder(
		"EmeraldEnergyColumn",
		Vector3(0.0, 7.0, 0.0),
		0.84,
		0.64,
		6.1,
		_materials["reactor_spine"],
		Vector3.ZERO,
		24
	)
	_reactor_coils()
	for rail in range(6):
		var angle := TAU * float(rail) / 6.0
		_box(
			"ReactorCoilRail_%02d" % rail,
			Vector3(cos(angle) * 1.06, 7.0, sin(angle) * 1.06),
			Vector3(0.12, 5.7, 0.12),
			_materials["dark_trim"],
			Vector3(0.0, -rad_to_deg(angle), 0.0)
		)
	# Focus the emissive focal point inside the larger FBX-framed structure:
	# the earlier overexposed cyan orb filled the portrait camera's horizon.
	_sphere(
		"SuspendedReactorSeed",
		Vector3(0.0, 7.0, 0.0),
		Vector3(1.32, 1.63, 1.32),
		_materials["reactor_core"]
	)
	_ring("ContainmentLowerHalo", Vector3.ZERO, 3.1, 4.1, 0.3, _materials["cyan"], 24)
	_ring("ContainmentUpperHalo", Vector3.ZERO, 3.1, 9.9, 0.3, _materials["cyan"], 24)
	_ring("ReactorServiceRing", Vector3.ZERO, 4.9, 10.9, 0.42, _materials["silver"], 24)
	_ring("ReactorWarningRing", Vector3.ZERO, 5.1, 10.7, 0.08, _materials["orange"], 24)
	for quadrant in range(4):
		var angle := PI * 0.5 * float(quadrant)
		var at := Vector3(cos(angle) * 3.5, 11.2, sin(angle) * 3.5)
		_box(
			"ReactorTopArm_%d" % quadrant,
			at,
			Vector3(2.6, 0.35, 0.45),
			_materials["silver"],
			Vector3(0.0, -rad_to_deg(angle), 0.0)
		)
	_box("ReactorTopBridge", Vector3(0.0, 11.65, 0.0), Vector3(7.0, 0.35, 0.6), _materials["blue"])
	_sphere("ReactorBeacon", Vector3(0.0, 12.2, 0.0), Vector3(0.52, 0.8, 0.52), _materials["cyan"])
	for bolt_x in [-4.0, 4.0]:
		for bolt_z in [-4.0, 4.0]:
			_cylinder(
				"ReactorDeckFastener",
				Vector3(bolt_x, 0.93, bolt_z),
				0.075,
				0.075,
				0.035,
				_materials["dark_trim"],
				Vector3.ZERO,
				8
			)


func _build_command_center() -> void:
	_box(
		"CommandFoundation",
		Vector3(0.0, 0.24, 0.0),
		Vector3(22.0, 0.48, 16.0),
		_materials["silver"],
		Vector3.ZERO,
		true
	)
	_box(
		"CommandLowerHull",
		Vector3(0.0, 2.9, 0.0),
		Vector3(18.0, 5.0, 12.5),
		_materials["pearl"],
		Vector3.ZERO,
		true
	)
	_box(
		"CommandUpperBridge", Vector3(0.0, 6.55, -0.25), Vector3(12.4, 2.4, 9.0), _materials["blue"]
	)
	_box("CommandRoof", Vector3(0.0, 7.85, -0.25), Vector3(13.4, 0.3, 10.0), _materials["silver"])
	_box(
		"CommandFrontVisor", Vector3(0.0, 6.85, 4.55), Vector3(13.0, 0.56, 0.52), _materials["cyan"]
	)
	_box("CommandSignBand", Vector3(0.0, 4.95, 6.32), Vector3(14.5, 0.24, 0.18), _materials["blue"])
	_box(
		"CommandMainDoor",
		Vector3(0.0, 1.65, 6.36),
		Vector3(3.2, 3.3, 0.24),
		_materials["deep_blue"]
	)
	_box(
		"CommandDoorLight",
		Vector3(0.0, 1.8, 6.51),
		Vector3(0.1, 2.6, 0.045),
		_materials["turquoise"]
	)
	for window_index in range(6):
		var x := -6.1 + float(window_index) * 2.44
		_box(
			"CommandWindow_%02d" % window_index,
			Vector3(x, 3.5, 6.32),
			Vector3(1.65, 1.75, 0.16),
			_materials["glass"]
		)
		_box(
			"CommandWindowTrim_%02d" % window_index,
			Vector3(x, 2.52, 6.43),
			Vector3(1.85, 0.12, 0.16),
			_materials["blue"]
		)
	for side in [-1.0, 1.0]:
		for z in [-4.0, 0.0, 4.0]:
			_box(
				"CommandSideFin",
				Vector3(side * 9.15, 2.8, z),
				Vector3(0.34, 4.6, 0.8),
				_materials["blue"]
			)
		for x in [-7.0, 7.0]:
			_box(
				"CommandCornerArmor",
				Vector3(x, 3.1, side * 6.1),
				Vector3(0.45, 5.3, 0.45),
				_materials["silver"]
			)
	for vent_index in range(5):
		_box(
			"CommandRoofVent_%02d" % vent_index,
			Vector3(-4.8 + vent_index * 2.4, 8.12, -2.4),
			Vector3(1.0, 0.48, 1.6),
			_materials["dark_trim"]
		)
	_box(
		"CommandAntennaMast",
		Vector3(7.5, 9.2, -4.2),
		Vector3(0.22, 2.2, 0.22),
		_materials["silver"]
	)
	_cylinder(
		"CommandAntennaDish",
		Vector3(7.5, 10.3, -4.2),
		0.82,
		0.82,
		0.12,
		_materials["cyan"],
		Vector3(34.0, 0.0, 0.0),
		20
	)
	_box(
		"CommandRoofBeacon",
		Vector3(-7.2, 8.45, -4.0),
		Vector3(0.32, 0.68, 0.32),
		_materials["blue"]
	)
	_sphere(
		"CommandRoofBeaconLens",
		Vector3(-7.2, 8.84, -4.0),
		Vector3(0.22, 0.26, 0.22),
		_materials["turquoise"]
	)
	_add_bolts(
		"CommandFoundation",
		Vector3(0.0, 0.5, 0.0),
		Vector2(10.1, 7.1),
		0.03,
		_materials["dark_trim"]
	)


func _build_research_lab() -> void:
	_box(
		"ResearchFoundation",
		Vector3(0.0, 0.22, 0.0),
		Vector3(20.0, 0.44, 14.0),
		_materials["silver"],
		Vector3.ZERO,
		true
	)
	_box(
		"ResearchMainModule",
		Vector3(0.0, 2.65, 0.0),
		Vector3(16.0, 4.6, 10.5),
		_materials["ceramic"],
		Vector3.ZERO,
		true
	)
	_box("ResearchBlueBelt", Vector3(0.0, 3.5, 5.34), Vector3(15.8, 0.58, 0.16), _materials["blue"])
	_box(
		"ResearchWindowBand",
		Vector3(0.0, 3.55, 5.46),
		Vector3(11.8, 1.08, 0.08),
		_materials["glass"]
	)
	_box(
		"ResearchEntryFrame", Vector3(0.0, 1.35, 5.46), Vector3(3.8, 2.65, 0.45), _materials["blue"]
	)
	_box(
		"ResearchEntryDoor", Vector3(0.0, 1.38, 5.72), Vector3(2.4, 2.5, 0.16), _materials["silver"]
	)
	_box(
		"ResearchDoorLight", Vector3(0.0, 1.45, 5.83), Vector3(0.11, 2.0, 0.04), _materials["cyan"]
	)
	_box("ResearchRoofPod", Vector3(0.0, 5.15, -0.2), Vector3(9.2, 0.6, 7.6), _materials["pearl"])
	_cylinder(
		"ResearchContainmentVessel",
		Vector3(0.0, 6.1, -0.1),
		2.7,
		2.15,
		1.9,
		_materials["glass"],
		Vector3.ZERO,
		28
	)
	_cylinder(
		"ResearchSampleColumn",
		Vector3(0.0, 6.15, -0.1),
		0.75,
		0.55,
		1.55,
		_materials["emerald"],
		Vector3.ZERO,
		20
	)
	_ring("ResearchVesselRing", Vector3(0.0, 0.0, -0.1), 2.85, 6.0, 0.18, _materials["cyan"], 20)
	for side in [-1.0, 1.0]:
		_box(
			"ResearchWing",
			Vector3(side * 7.7, 2.1, -1.0),
			Vector3(2.0, 2.8, 8.0),
			_materials["blue"]
		)
		_box(
			"ResearchWingLight",
			Vector3(side * 8.75, 2.0, -1.0),
			Vector3(0.08, 2.4, 6.2),
			_materials["turquoise"]
		)
		_box(
			"ResearchInstrumentPod",
			Vector3(side * 5.2, 5.2, -4.2),
			Vector3(1.4, 0.9, 1.2),
			_materials["copper"]
		)
	for vent_index in range(4):
		_box(
			"ResearchRoofVent_%02d" % vent_index,
			Vector3(-5.0 + vent_index * 3.3, 5.65, 3.0),
			Vector3(1.1, 0.36, 0.72),
			_materials["dark_trim"]
		)
	_link_cylinder(
		"ResearchMaintenanceArm",
		Vector3(8.0, 4.1, -3.8),
		Vector3(10.2, 3.1, -2.8),
		0.14,
		_materials["silver"]
	)
	_sphere(
		"ResearchToolEnd", Vector3(10.25, 3.1, -2.8), Vector3(0.3, 0.3, 0.3), _materials["yellow"]
	)
	_add_bolts("ResearchFoundation", Vector3.ZERO, Vector2(9.2, 6.2), 0.47, _materials["dark_trim"])


func _build_equipment_depot() -> void:
	_box(
		"DepotFoundation",
		Vector3(0.0, 0.2, 0.0),
		Vector3(19.0, 0.4, 13.0),
		_materials["silver"],
		Vector3.ZERO,
		true
	)

	ScifiBayBuilder.place(
		self,
		"wall_cube",
		"SciFiEquipmentDepotFacade",
		Vector3(-3.6, 0.4, 0.0),
		90.0,
		1.85,
		true,
		true
	)
	ScifiBayBuilder.place(
		self, "doorway", "SciFiEquipmentDepotAccess", Vector3(-3.6, 0.4, 5.2), 0.0, 1.3, false, true
	)

	for crate_index in range(4):
		var crate_x := 7.0 + float(crate_index % 2) * 1.7
		var crate_z := 3.1 + float(crate_index / 2) * 1.6
		ScifiBayBuilder.place(
			self,
			"crate",
			"SciFiEquipmentSupply_%02d" % crate_index,
			Vector3(crate_x, 0.4, crate_z),
			float(crate_index) * 90.0,
			1.2,
			false,
			true
		)
	_add_bolts("DepotFoundation", Vector3.ZERO, Vector2(8.8, 5.8), 0.42, _materials["dark_trim"])


func _build_generator_bank() -> void:
	_box(
		"GeneratorFoundation",
		Vector3(0.0, 0.26, 0.0),
		Vector3(26.0, 0.52, 18.0),
		_materials["silver"],
		Vector3.ZERO,
		true
	)
	_box(
		"GeneratorLowerDeck", Vector3(0.0, 0.56, 0.0), Vector3(24.0, 0.16, 16.0), _materials["blue"]
	)
	for tower_index in range(3):
		var x := -8.0 + float(tower_index) * 8.0
		_cylinder(
			"GeneratorHousing_%d" % tower_index,
			Vector3(x, 4.1, 0.0),
			2.5,
			2.0,
			7.0,
			_materials["pearl"],
			Vector3.ZERO,
			28
		)
		_cylinder(
			"GeneratorCoreGlass_%d" % tower_index,
			Vector3(x, 4.25, 0.0),
			1.58,
			1.42,
			6.2,
			_materials["glass"],
			Vector3.ZERO,
			24
		)
		_cylinder(
			"GeneratorEnergyColumn_%d" % tower_index,
			Vector3(x, 4.2, 0.0),
			0.72,
			0.8,
			5.9,
			_materials["turquoise"] if tower_index == 1 else _materials["emerald"],
			Vector3.ZERO,
			20
		)
		for band_index in range(4):
			var y := 1.2 + float(band_index) * 1.8
			_cylinder(
				"GeneratorBand_%d_%d" % [tower_index, band_index],
				Vector3(x, y, 0.0),
				2.62,
				2.62,
				0.16,
				_materials["copper"] if band_index == 0 else _materials["silver"],
				Vector3.ZERO,
				28
			)
			_cylinder(
				"GeneratorBandLight_%d_%d" % [tower_index, band_index],
				Vector3(x, y + 0.11, 0.0),
				2.64,
				2.64,
				0.06,
				_materials["orange"] if band_index == 0 else _materials["cyan"],
				Vector3.ZERO,
				28
			)
		for side in [-1.0, 1.0]:
			_box(
				"GeneratorRadialBrace_%d_%s" % [tower_index, str(side)],
				Vector3(x + side * 2.1, 3.9, 0.0),
				Vector3(0.22, 6.3, 0.22),
				_materials["blue"]
			)
		_sphere(
			"GeneratorCrown_%d" % tower_index,
			Vector3(x, 8.1, 0.0),
			Vector3(1.1, 0.75, 1.1),
			_materials["cyan"]
		)
	for pipe_z in [-6.2, 6.2]:
		_box(
			"GeneratorManifold",
			Vector3(0.0, 2.6, pipe_z),
			Vector3(22.0, 0.75, 0.65),
			_materials["copper"]
		)
		_box(
			"GeneratorManifoldGlow",
			Vector3(0.0, 3.02, pipe_z),
			Vector3(21.5, 0.08, 0.24),
			_materials["orange"]
		)
	for x in [-8.0, 0.0, 8.0]:
		_link_cylinder(
			"GeneratorFeedPipe",
			Vector3(x, 2.6, -6.2),
			Vector3(x, 2.6, -2.2),
			0.3,
			_materials["cyan"]
		)
		_link_cylinder(
			"GeneratorReturnPipe",
			Vector3(x, 2.1, 2.2),
			Vector3(x, 2.1, 6.2),
			0.24,
			_materials["copper"]
		)
	_box(
		"GeneratorServiceWalk",
		Vector3(0.0, 1.2, -8.4),
		Vector3(20.0, 0.34, 1.0),
		_materials["yellow"]
	)
	for edge_x in [-11.6, 11.6]:
		_box(
			"GeneratorSafetyRail",
			Vector3(edge_x, 1.95, -8.4),
			Vector3(0.16, 1.5, 1.0),
			_materials["silver"]
		)
	_add_bolts(
		"GeneratorFoundation", Vector3.ZERO, Vector2(12.0, 8.0), 0.54, _materials["dark_trim"]
	)


func _build_boss_gate() -> void:
	_box(
		"BossGateFoundation",
		Vector3(0.0, 0.28, 0.0),
		Vector3(36.0, 0.56, 7.0),
		_materials["silver"],
		Vector3.ZERO,
		true
	)
	for side in [-1.0, 1.0]:
		_box(
			"BossGatePillar_%s" % str(side),
			Vector3(side * 13.2, 11.4, 0.0),
			Vector3(4.8, 22.8, 6.0),
			_materials["blue"],
			Vector3.ZERO,
			true
		)
		_box(
			"BossGatePillarArmor_%s" % str(side),
			Vector3(side * 13.2, 11.4, 3.05),
			Vector3(3.5, 20.2, 0.18),
			_materials["pearl"]
		)
		_box(
			"BossGateEnergyRail_%s" % str(side),
			Vector3(side * 10.8, 11.5, 3.2),
			Vector3(0.28, 19.8, 0.18),
			_materials["cyan"]
		)
		_box(
			"BossGateButtress_%s" % str(side),
			Vector3(side * 16.0, 8.4, -1.5),
			Vector3(3.5, 16.8, 3.4),
			_materials["silver"]
		)
		_cylinder(
			"BossGateConduitNode_%s" % str(side),
			Vector3(side * 13.2, 19.5, 3.25),
			0.72,
			0.72,
			0.42,
			_materials["orange"],
			Vector3(90.0, 0.0, 0.0),
			16
		)
		_box(
			"BossGateWarning_%s" % str(side),
			Vector3(side * 13.2, 21.0, 3.25),
			Vector3(0.34, 0.75, 0.18),
			_materials["red"]
		)
		_box(
			"BossGateDoorLeaf_%s" % str(side),
			Vector3(side * 4.3, 8.9, 0.0),
			Vector3(8.4, 17.6, 1.1),
			_materials["dark_trim"]
		)
	for slat_index in range(10):
		var y := 1.0 + float(slat_index) * 1.65
		_box(
			"BossGateShutterSlat_%02d" % slat_index,
			Vector3(0.0, y, 0.75),
			Vector3(8.2, 0.18, 0.14),
			_materials["silver"]
		)
		_box(
			"BossGateShutterLight_%02d" % slat_index,
			Vector3(0.0, y + 0.22, 0.84),
			Vector3(2.4, 0.06, 0.05),
			_materials["cyan"]
		)
	_box("BossGateHeader", Vector3(0.0, 22.8, 0.0), Vector3(30.0, 2.4, 7.0), _materials["pearl"])
	_box(
		"BossGateHeaderBlue", Vector3(0.0, 21.5, 3.2), Vector3(18.0, 0.32, 0.22), _materials["blue"]
	)
	_box(
		"BossGateHeaderEnergy",
		Vector3(0.0, 21.15, 3.32),
		Vector3(10.0, 0.08, 0.08),
		_materials["turquoise"]
	)
	for side in [-1.0, 1.0]:
		for offset in [-5.0, 0.0, 5.0]:
			_link_cylinder(
				"BossGatePowerConduit",
				Vector3(side * 14.5, 2.0, -2.6),
				Vector3(side * 14.5, 18.5, -2.6 + offset * 0.12),
				0.28,
				_materials["copper"]
			)
	_add_bolts(
		"BossGateFoundation", Vector3.ZERO, Vector2(17.0, 3.0), 0.57, _materials["dark_trim"]
	)


func _build_defense_turret() -> void:
	_cylinder(
		"TurretMountPlate",
		Vector3(0.0, 0.22, 0.0),
		2.7,
		2.7,
		0.44,
		_materials["yellow"],
		Vector3.ZERO,
		20
	)
	_cylinder(
		"TurretArmoredFoot",
		Vector3(0.0, 0.75, 0.0),
		2.05,
		1.75,
		0.8,
		_materials["blue"],
		Vector3.ZERO,
		20
	)
	_cylinder(
		"TurretYawBearing",
		Vector3(0.0, 1.28, 0.0),
		1.5,
		1.5,
		0.22,
		_materials["silver"],
		Vector3.ZERO,
		20
	)
	_box("TurretHousing", Vector3(0.0, 2.25, 0.0), Vector3(2.5, 1.25, 2.4), _materials["pearl"])
	_box("TurretFrontArmor", Vector3(0.0, 2.2, 1.2), Vector3(1.9, 0.9, 0.2), _materials["blue"])
	for barrel_index in range(2):
		var x := -0.52 + float(barrel_index) * 1.04
		_link_cylinder(
			"TurretBarrel_%d" % barrel_index,
			Vector3(x, 2.1, 1.3),
			Vector3(x, 2.1, 3.7),
			0.18,
			_materials["silver"]
		)
		_cylinder(
			"TurretMuzzle_%d" % barrel_index,
			Vector3(x, 2.1, 3.75),
			0.23,
			0.25,
			0.25,
			_materials["orange"],
			Vector3(90.0, 0.0, 0.0),
			16
		)
	_box(
		"TurretSensorStem",
		Vector3(0.0, 3.18, -0.25),
		Vector3(0.16, 0.78, 0.16),
		_materials["silver"]
	)
	_sphere(
		"TurretSensor", Vector3(0.0, 3.62, -0.25), Vector3(0.48, 0.36, 0.42), _materials["cyan"]
	)
	for side in [-1.0, 1.0]:
		_box(
			"TurretSideLight_%s" % str(side),
			Vector3(side * 1.34, 2.28, -0.2),
			Vector3(0.08, 0.32, 0.72),
			_materials["orange"]
		)
	_add_box_collider("TurretBaseCollision", Vector3(0.0, 1.25, 0.0), Vector3(3.8, 2.5, 3.8))


func _build_sensor_tower() -> void:
	_cylinder(
		"SensorTowerFoundation",
		Vector3(0.0, 0.25, 0.0),
		2.9,
		2.9,
		0.5,
		_materials["yellow"],
		Vector3.ZERO,
		20
	)
	_cylinder(
		"SensorTowerShaft",
		Vector3(0.0, 7.0, 0.0),
		0.72,
		0.54,
		13.0,
		_materials["pearl"],
		Vector3.ZERO,
		16
	)
	for band_index in range(5):
		var y := 2.3 + float(band_index) * 2.3
		_cylinder(
			"SensorTowerBand_%d" % band_index,
			Vector3(0.0, y, 0.0),
			0.9,
			0.9,
			0.12,
			_materials["blue"],
			Vector3.ZERO,
			16
		)
		_cylinder(
			"SensorTowerBandLight_%d" % band_index,
			Vector3(0.0, y + 0.1, 0.0),
			0.93,
			0.93,
			0.06,
			_materials["cyan"],
			Vector3.ZERO,
			16
		)
	_cylinder(
		"SensorTowerObservationDeck",
		Vector3(0.0, 12.0, 0.0),
		3.5,
		3.5,
		0.52,
		_materials["silver"],
		Vector3.ZERO,
		20
	)
	_cylinder(
		"SensorTowerGlassCabin",
		Vector3(0.0, 13.15, 0.0),
		2.6,
		2.4,
		1.9,
		_materials["glass"],
		Vector3.ZERO,
		20
	)
	_cylinder(
		"SensorTowerRoof",
		Vector3(0.0, 14.2, 0.0),
		2.9,
		2.9,
		0.34,
		_materials["blue"],
		Vector3.ZERO,
		20
	)
	_cylinder(
		"SensorTowerRadar",
		Vector3(0.0, 15.35, 0.0),
		2.1,
		2.1,
		0.12,
		_materials["cyan"],
		Vector3.ZERO,
		24
	)
	_box(
		"SensorTowerAntenna", Vector3(0.0, 17.0, 0.0), Vector3(0.2, 3.0, 0.2), _materials["silver"]
	)
	for side in [-1.0, 1.0]:
		_box(
			"SensorTowerDishMast",
			Vector3(side * 3.3, 13.2, 0.0),
			Vector3(0.14, 2.0, 0.14),
			_materials["silver"]
		)
		_cylinder(
			"SensorTowerDish",
			Vector3(side * 3.3, 14.1, 0.0),
			0.88,
			0.88,
			0.13,
			_materials["turquoise"],
			Vector3(0.0, 0.0, 36.0 * side),
			18
		)
	_add_box_collider("SensorTowerShaftCollision", Vector3(0.0, 6.8, 0.0), Vector3(1.2, 13.2, 1.2))


func _build_landing_pad() -> void:
	_box(
		"LandingPadFoundation",
		Vector3(0.0, 0.3, 0.0),
		Vector3(32.0, 0.6, 24.0),
		_materials["silver"],
		Vector3.ZERO,
		true
	)
	_box("LandingPadDeck", Vector3(0.0, 0.64, 0.0), Vector3(29.0, 0.12, 21.0), _materials["blue"])
	for edge in [-1.0, 1.0]:
		_box(
			"LandingPadSafetyStripeX",
			Vector3(edge * 13.9, 0.73, 0.0),
			Vector3(0.28, 0.06, 19.0),
			_materials["yellow"]
		)
		_box(
			"LandingPadSafetyStripeZ",
			Vector3(0.0, 0.73, edge * 9.9),
			Vector3(27.5, 0.06, 0.28),
			_materials["yellow"]
		)
	for strip_index in range(8):
		var z := -7.0 + float(strip_index) * 2.0
		_box(
			"LandingPadPanel_%02d" % strip_index,
			Vector3(0.0, 0.72, z),
			Vector3(23.0, 0.04, 1.72),
			_materials["pearl"] if strip_index % 2 == 0 else _materials["ceramic"]
		)
	_box(
		"LandingPadCenterStroke",
		Vector3(0.0, 0.78, 0.0),
		Vector3(1.0, 0.05, 8.0),
		_materials["cyan"]
	)
	_box(
		"LandingPadH_Left", Vector3(-4.4, 0.8, 0.0), Vector3(1.15, 0.08, 7.0), _materials["yellow"]
	)
	_box(
		"LandingPadH_Right", Vector3(4.4, 0.8, 0.0), Vector3(1.15, 0.08, 7.0), _materials["yellow"]
	)
	_box(
		"LandingPadH_Crossbar",
		Vector3(0.0, 0.8, 0.0),
		Vector3(9.8, 0.08, 1.0),
		_materials["yellow"]
	)
	for x in [-13.6, 13.6]:
		for z in [-9.6, 9.6]:
			_cylinder(
				"LandingPadBeaconBase",
				Vector3(x, 1.0, z),
				0.42,
				0.42,
				0.55,
				_materials["silver"],
				Vector3.ZERO,
				12
			)
			_sphere(
				"LandingPadBeaconLens",
				Vector3(x, 1.38, z),
				Vector3(0.28, 0.32, 0.28),
				_materials["orange"]
			)
	for panel in range(6):
		_box(
			"LandingPadEdgeRib_%02d" % panel,
			Vector3(-11.0 + panel * 4.4, 0.82, -10.6),
			Vector3(2.0, 0.12, 0.18),
			_materials["cyan"]
		)
	# Six uploaded FBX floor modules form the playable pad surface. The ramp,
	# safety markings and deck collision remain separate so traversal is stable.
	for tile_x in range(3):
		for tile_z in range(2):
			var key := "floor_alt" if (tile_x + tile_z) % 2 == 0 else "floor"
			ScifiBayBuilder.place(
				self,
				key,
				"SciFiLandingDeck_%d_%d" % [tile_x, tile_z],
				Vector3((float(tile_x) - 1.0) * 8.9, 0.745, (float(tile_z) - 0.5) * 8.9),
				90.0,
				1.65,
				false,
				false
			)

	_add_bolts("LandingPadDeck", Vector3.ZERO, Vector2(14.0, 10.0), 0.73, _materials["dark_trim"])


func _build_wrecked_transport() -> void:
	_box(
		"TransportBrokenHull",
		Vector3(0.0, 1.25, 0.0),
		Vector3(9.4, 2.2, 4.4),
		_materials["ceramic"],
		Vector3(0.0, 0.0, -8.0),
		true
	)
	_box(
		"TransportCockpit",
		Vector3(0.0, 2.45, 1.15),
		Vector3(3.4, 1.5, 2.0),
		_materials["glass"],
		Vector3(-8.0, 0.0, 0.0)
	)
	_box(
		"TransportNoseArmor",
		Vector3(0.0, 1.65, 3.4),
		Vector3(3.5, 1.1, 2.5),
		_materials["silver"],
		Vector3(0.0, 0.0, 12.0)
	)
	_box(
		"TransportWingLeft",
		Vector3(-8.6, 0.82, -0.8),
		Vector3(10.0, 0.52, 3.2),
		_materials["blue"],
		Vector3(0.0, 0.0, 22.0)
	)
	_box(
		"TransportWingRightBroken",
		Vector3(7.0, 0.66, -1.2),
		Vector3(7.0, 0.45, 2.6),
		_materials["ceramic"],
		Vector3(12.0, 6.0, -28.0)
	)
	_box(
		"TransportBrokenFin",
		Vector3(6.8, 1.0, 2.3),
		Vector3(3.2, 0.3, 1.8),
		_materials["copper"],
		Vector3(0.0, 0.0, 34.0)
	)
	for engine_index in range(2):
		var x := -3.1 + engine_index * 6.2
		_cylinder(
			"TransportEngine_%d" % engine_index,
			Vector3(x, 1.1, -2.6),
			1.0,
			0.8,
			2.6,
			_materials["dark_trim"],
			Vector3(90.0, 0.0, 0.0),
			18
		)
		_cylinder(
			"TransportEngineGlow_%d" % engine_index,
			Vector3(x, 1.1, -3.94),
			0.58,
			0.58,
			0.18,
			_materials["orange"],
			Vector3(90.0, 0.0, 0.0),
			16
		)
	_box(
		"TransportImpactScar",
		Vector3(-2.3, 2.34, 0.2),
		Vector3(1.0, 0.12, 2.7),
		_materials["orange"],
		Vector3(0.0, 0.0, 28.0)
	)
	for debris_index in range(5):
		var x := -7.0 + float(debris_index) * 3.4
		_box(
			"TransportDebris_%02d" % debris_index,
			Vector3(x, 0.25, 5.0 + sin(float(debris_index)) * 2.0),
			Vector3(1.4, 0.5, 0.9),
			_materials["silver"],
			Vector3(0.0, float(debris_index) * 21.0, float(debris_index) * 9.0)
		)
	_sphere(
		"TransportFireGlow", Vector3(-2.0, 0.85, 2.4), Vector3(0.7, 1.0, 0.7), _materials["orange"]
	)


func _build_alien_drone_wreck() -> void:
	_sphere(
		"DroneCentralChassis",
		Vector3(0.0, 1.7, 0.0),
		Vector3(2.2, 1.15, 2.6),
		_materials["dark_trim"],
		Vector3(0.0, 0.0, 18.0)
	)
	_sphere("DroneCoreLens", Vector3(0.0, 1.85, 1.72), Vector3(1.0, 0.7, 0.3), _materials["red"])
	for arm_index in range(4):
		var angle := TAU * float(arm_index) / 4.0
		var start := Vector3(cos(angle) * 1.1, 1.9, sin(angle) * 1.1)
		var finish := Vector3(cos(angle) * 4.2, 0.55 + float(arm_index % 2) * 0.4, sin(angle) * 4.2)
		_link_cylinder(
			"DroneBrokenArm_%d" % arm_index,
			start,
			finish,
			0.34,
			_materials["copper"] if arm_index % 2 == 0 else _materials["blue"]
		)
		_sphere(
			"DroneJoint_%d" % arm_index, finish, Vector3(0.78, 0.58, 0.72), _materials["silver"]
		)
		_box(
			"DroneClaw_%d" % arm_index,
			finish + Vector3(0.0, -0.38, 0.0),
			Vector3(0.42, 0.82, 0.36),
			_materials["dark_trim"],
			Vector3(0.0, arm_index * 38.0, 18.0)
		)
	for plate_index in range(3):
		_box(
			"DroneArmorPlate_%d" % plate_index,
			Vector3(-0.7 + plate_index * 0.7, 2.45, 0.0),
			Vector3(1.15, 0.18, 2.0),
			_materials["rock_rose"],
			Vector3(0.0, 0.0, float(plate_index - 1) * 14.0)
		)
	_box(
		"DroneSparkingCable",
		Vector3(0.0, 0.55, 2.0),
		Vector3(2.1, 0.08, 0.08),
		_materials["orange"],
		Vector3(0.0, 0.0, 16.0)
	)


func _build_crystal_cluster() -> void:
	var color_keys: Array[String] = ["cyan", "emerald", "turquoise", "flora_lime", "blue"]
	var heights: Array[float] = [3.8, 5.4, 2.9, 4.6, 3.2, 2.3]
	var positions: Array[Vector2] = [
		Vector2(-1.6, -0.4),
		Vector2(-0.6, 0.9),
		Vector2(0.8, -0.8),
		Vector2(1.7, 0.5),
		Vector2(0.2, 1.8),
		Vector2(-2.0, 1.6)
	]
	for crystal_index in range(positions.size()):
		var position := positions[crystal_index]
		var height := heights[(crystal_index + variant_seed) % heights.size()]
		var bottom_radius := 0.58 + 0.08 * float((crystal_index + variant_seed) % 3)
		_cylinder(
			"CrystalShard_%02d" % crystal_index,
			Vector3(position.x, height * 0.5, position.y),
			bottom_radius,
			0.025,
			height,
			_materials[color_keys[(crystal_index + variant_seed) % color_keys.size()]],
			Vector3(
				float(crystal_index % 2) * 6.0,
				float(crystal_index * 31),
				float(crystal_index % 3 - 1) * 8.0
			),
			6
		)
		_cylinder(
			"CrystalRoot_%02d" % crystal_index,
			Vector3(position.x, 0.18, position.y),
			bottom_radius * 1.35,
			bottom_radius,
			0.36,
			_materials["rock_rose"],
			Vector3.ZERO,
			7
		)
	for shard in range(3):
		var x := -2.0 + float(shard) * 1.8
		_cylinder(
			"CrystalSmallShard_%02d" % shard,
			Vector3(x, 0.52, -2.6),
			0.35,
			0.02,
			1.0 + float(shard % 2) * 0.55,
			_materials[color_keys[(shard + variant_seed) % color_keys.size()]],
			Vector3(0.0, shard * 35.0, 12.0),
			5
		)


func _build_alien_flora() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = variant_seed + 1907
	for plant_index in range(7):
		var angle := TAU * float(plant_index) / 7.0 + rng.randf_range(-0.18, 0.18)
		var radius := rng.randf_range(0.8, 3.0)
		var x := cos(angle) * radius
		var z := sin(angle) * radius
		var height := rng.randf_range(1.0, 2.6)
		_cylinder(
			"FloraStem_%02d" % plant_index,
			Vector3(x, height * 0.5, z),
			0.12,
			0.08,
			height,
			_materials["flora"],
			Vector3(0.0, 0.0, rng.randf_range(-12.0, 12.0)),
			10
		)
		_sphere(
			"FloraLantern_%02d" % plant_index,
			Vector3(x, height, z),
			Vector3(0.25, 0.36, 0.25),
			_materials["flora_lime"]
		)
		for leaf_index in range(3):
			var leaf_angle := angle + float(leaf_index) * TAU / 3.0
			var leaf_center := Vector3(
				x + cos(leaf_angle) * 0.42, height * 0.64, z + sin(leaf_angle) * 0.42
			)
			_sphere(
				"FloraLeaf_%02d_%02d" % [plant_index, leaf_index],
				leaf_center,
				Vector3(0.62, 0.16, 0.28),
				_materials["flora_teal"],
				Vector3(0.0, -rad_to_deg(leaf_angle), 20.0)
			)
	for frond_index in range(3):
		var x := -1.4 + float(frond_index) * 1.4
		_link_cylinder(
			"FloraArchingFrond_%02d" % frond_index,
			Vector3(x, 0.2, 0.0),
			Vector3(x * 1.5, 1.8 + float(frond_index % 2) * 0.4, 0.6),
			0.07,
			_materials["flora"]
		)
		_sphere(
			"FloraFrondTip_%02d" % frond_index,
			Vector3(x * 1.5, 1.8 + float(frond_index % 2) * 0.4, 0.6),
			Vector3(0.18, 0.34, 0.18),
			_materials["flora_lime"]
		)


func _build_rock_cluster() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = variant_seed + 811
	var rock_mats: Array[String] = ["rock", "rock_light", "rock_rose"]
	for rock_index in range(9):
		var angle := TAU * float(rock_index) / 9.0 + rng.randf_range(-0.24, 0.24)
		var distance := rng.randf_range(0.6, 3.8)
		var width := rng.randf_range(1.0, 3.0)
		var height := rng.randf_range(1.1, 4.4)
		var depth := rng.randf_range(1.0, 2.7)
		_sphere(
			"RockMass_%02d" % rock_index,
			Vector3(cos(angle) * distance, height * 0.45, sin(angle) * distance),
			Vector3(width, height, depth),
			_materials[rock_mats[(rock_index + variant_seed) % rock_mats.size()]],
			Vector3(
				rng.randf_range(-24.0, 24.0),
				rng.randf_range(0.0, 360.0),
				rng.randf_range(-16.0, 16.0)
			)
		)
		if rock_index % 3 == 0:
			_add_box_collider(
				"RockCollision_%02d" % rock_index,
				Vector3(cos(angle) * distance, height * 0.42, sin(angle) * distance),
				Vector3(width * 0.72, height * 0.78, depth * 0.72),
				Vector3(0.0, rng.randf_range(0.0, 360.0), 0.0)
			)


func _build_enemy_spawn_gate() -> void:
	_box(
		"SpawnGateLeftFoot", Vector3(-2.8, 0.25, 0.0), Vector3(1.7, 0.5, 2.2), _materials["yellow"]
	)
	_box(
		"SpawnGateRightFoot", Vector3(2.8, 0.25, 0.0), Vector3(1.7, 0.5, 2.2), _materials["yellow"]
	)
	_box(
		"SpawnGateLeftPillar",
		Vector3(-2.55, 2.5, 0.0),
		Vector3(0.8, 4.4, 1.2),
		_materials["pearl"],
		Vector3.ZERO,
		true
	)
	_box(
		"SpawnGateRightPillar",
		Vector3(2.55, 2.5, 0.0),
		Vector3(0.8, 4.4, 1.2),
		_materials["pearl"],
		Vector3.ZERO,
		true
	)
	_box("SpawnGateHeader", Vector3(0.0, 4.75, 0.0), Vector3(6.1, 0.75, 1.6), _materials["blue"])
	_box(
		"SpawnGateEnergyLintel",
		Vector3(0.0, 4.25, 0.88),
		Vector3(4.3, 0.12, 0.08),
		_materials["cyan"]
	)
	_box(
		"SpawnGateWarningPanel",
		Vector3(0.0, 4.8, 0.86),
		Vector3(2.1, 0.4, 0.12),
		_materials["orange"]
	)
	for side in [-1.0, 1.0]:
		_box(
			"SpawnGatePillarStripe",
			Vector3(side * 2.55, 2.5, 0.63),
			Vector3(0.14, 3.3, 0.08),
			_materials["turquoise"]
		)
		_sphere(
			"SpawnGateBeacon",
			Vector3(side * 2.55, 5.35, 0.0),
			Vector3(0.34, 0.3, 0.34),
			_materials["red"]
		)
	for rail_index in range(3):
		_box(
			"SpawnGateFloorGuide_%d" % rail_index,
			Vector3(0.0, 0.06, -0.8 + rail_index * 0.7),
			Vector3(3.4, 0.08, 0.12),
			_materials["cyan"]
		)
	_add_bolts("SpawnGate", Vector3.ZERO, Vector2(2.9, 0.8), 0.54, _materials["dark_trim"])


func _build_cover_module() -> void:
	_box(
		"CoverModuleBase",
		Vector3(0.0, 0.4, 0.0),
		Vector3(4.4, 0.8, 1.5),
		_materials["blue"],
		Vector3.ZERO,
		true
	)
	_box(
		"CoverModuleArmor",
		Vector3(0.0, 1.18, 0.0),
		Vector3(3.9, 0.84, 1.25),
		_materials["pearl"],
		Vector3.ZERO,
		true
	)
	_box(
		"CoverModuleTopStripe",
		Vector3(0.0, 1.62, 0.0),
		Vector3(3.7, 0.09, 1.12),
		_materials["yellow"]
	)
	for side in [-1.0, 1.0]:
		_box(
			"CoverModuleEdgeGuard",
			Vector3(side * 1.82, 1.12, 0.0),
			Vector3(0.22, 1.25, 1.35),
			_materials["copper"]
		)
		_box(
			"CoverModuleSignal",
			Vector3(side * 1.1, 1.18, 0.64),
			Vector3(0.54, 0.32, 0.06),
			_materials["cyan"]
		)
	for bolt_index in range(4):
		_cylinder(
			"CoverModuleBolt_%d" % bolt_index,
			Vector3(-1.4 + bolt_index * 0.94, 1.28, 0.69),
			0.07,
			0.07,
			0.04,
			_materials["dark_trim"],
			Vector3(90.0, 0.0, 0.0),
			8
		)
