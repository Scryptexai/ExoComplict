class_name VanguardStationWorld
extends Node3D

## WORLD 02 — Vanguard Station, Dock 07.
##
## A second, separate world. Neon Frontier is untouched: this scene builds its own
## facility behind its own gate and shares nothing with it but the palette and the
## conventions (`ScifiKitLibrary`, `ScifiBayBuilder.place`).
##
## Everything visible here is an imported module from
## `3DScifiStarterKitFree.zip` — 6 m floor plates, 2 x 4 x 6 m wall modules, roof
## plates, door frames, consoles, pipe runs, light strips, signs, portholes. There
## is no procedural stand-in geometry: where the world needs a wall, it is a wall
## module, and where it needs a landmark, it is the pack's machinery. Sizes come
## from the measured table in `ScifiKitLibrary.EXTRA`, so a module is centred on
## its own footprint instead of being guessed at per placement.
##
## PLAN
##
##   z -38  +----------------------------------+
##          |            REACTOR HALL          |   x -13 .. 13
##   z -19  +--------------[door]--------------+
##          |                                  |
##          |              HANGAR              |   x -19 .. 19, the arena
##   z +19  +-------[gate]-------+             |
##               (Dock 07)       |             |
##   z -7   +----[door]----------+             |
##          |   CARGO BAY        |             |
##   z +7   +--------------------+             |
##   x -38  x -19                x 19   x 43   +---- CORRIDOR ----+
##
## The hangar is 36 x 36 m — the same playable envelope the existing arena has,
## because the wave spawn markers in `main.tscn` sit at +-11 and +-12 m and would
## otherwise start outside the walls. Two catwalks at 3.4 m give the room a
## second level without turning the floor into a maze, and the reactor hall is on
## the axis the player faces at spawn, so the landmark is in the first frame.

const ScifiKitLibrary = preload("res://scripts/worlds/scifi_kit_library.gd")
const ScifiBayBuilder = preload("res://scripts/worlds/scifi_bay_builder.gd")

const TILE := 6.0
const WALL_Y := 0.0
const WALL_HEIGHT := 4.0
const ROOF_Y := 4.4
const CATWALK_Y := 3.4

## Rooms, as axis-aligned rectangles on the deck. One list, read by the floor, the
## roof, the lights and the smoke test, so a room cannot be half built.
const ROOMS := {
	"hangar": {"min": Vector2(-19.0, -19.0), "max": Vector2(19.0, 19.0)},
	"reactor": {"min": Vector2(-13.0, -37.0), "max": Vector2(13.0, -19.0)},
	"cargo": {"min": Vector2(-37.0, -7.0), "max": Vector2(-19.0, 7.0)},
	"corridor": {"min": Vector2(19.0, -4.0), "max": Vector2(43.0, 4.0)},
}

var _build_stats := {}


func _ready() -> void:
	# Only one world builds. Both are instanced in `main.tscn` so the launcher can
	# name either one (and `data_source_smoke` can see both), but building the one
	# the player did not choose would double the geometry for nothing.
	if not _is_selected():
		return
	build()


static func _is_selected() -> bool:
	var progression := Engine.get_singleton("ProgressionService")
	if progression == null:
		return true
	return StringName(progression.get("selected_world_id")) == &"vanguard_station"


func build() -> Dictionary:
	var root := Node3D.new()
	root.name = "Station"
	add_child(root)

	_build_hangar_deck(root)
	_build_reactor_deck(root)
	_build_cargo_deck(root)
	_build_corridor_deck(root)
	_build_walls(root)
	_build_ceiling(root)
	_build_gatehouse(root)
	_build_reactor(root)
	_build_cargo_bay(root)
	_build_corridor_dressing(root)
	_build_catwalks(root)
	_build_lighting(root)

	_build_stats["modules"] = _count_modules(root)
	_build_stats["lights"] = 8
	print(
		(
			"VanguardStation: %d kit modules, %d omnis, %d rooms"
			% [_build_stats["modules"], _build_stats["lights"], ROOMS.size()]
		)
	)
	return _build_stats


# --- placement ------------------------------------------------------------


## One imported module, centred on its own measured footprint.
##
## `ScifiBayBuilder.place` positions a module by the pack's own origin, which for
## most pieces is a corner: a placed console floats 0.74 m above the deck and a
## placed wall sits a metre off its collider. This wrapper puts a pivot at `at`,
## turns it, and offsets the model by `-(min + size / 2)` inside that pivot, so
## "at" means the centre of the thing — and the collider, which is built from the
## same box, agrees with what is drawn.
##
## `collide` is `""` for scenery, `"box"` for anything the player bumps into, and
## `"floor"` for deck plates, which get a thin box under the origin so the player
## stands on the surface rather than inside a 6 m tall block.
func _place(
	parent: Node3D,
	key: String,
	node_name: String,
	at: Vector3,
	yaw: float = 0.0,
	scale: float = 1.0,
	collide: String = "box",
	size_scale: Vector3 = Vector3.ONE,
	room: String = ""
) -> Node3D:
	var scene := ScifiKitLibrary.model(key)
	if scene == null:
		return null
	var box: Vector3 = ScifiKitLibrary.size(key) * scale * size_scale
	var min_corner: Vector3 = ScifiKitLibrary.min_corner(key) * scale * size_scale

	var pivot := Node3D.new()
	pivot.name = node_name
	pivot.position = at
	pivot.rotation_degrees.y = yaw
	if room != "":
		pivot.set_meta("station_room", room)
	parent.add_child(pivot)

	var model := scene.instantiate() as Node3D
	model.name = "Mesh"
	model.add_to_group(&"uploaded_fbx_visual")
	ScifiKitLibrary.apply_palette(model, key)
	model.position = Vector3(
		-(min_corner.x + box.x * 0.5), -min_corner.y, -(min_corner.z + box.z * 0.5)
	)
	model.scale = Vector3.ONE * scale * size_scale
	pivot.add_child(model)

	if collide != "":
		_add_collider(pivot, box, collide)
	return pivot


func _add_collider(pivot: Node3D, box: Vector3, mode: String) -> void:
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := BoxShape3D.new()
	if mode == "floor":
		# The deck's top face is the pivot's own Y; the box hangs below it.
		shape.size = Vector3(box.x, 0.4, box.z)
		body.position = Vector3(0.0, -0.2, 0.0)
	else:
		shape.size = Vector3(maxf(box.x, 0.2), maxf(box.y, 0.2), maxf(box.z, 0.2))
		body.position = Vector3(0.0, box.y * 0.5, 0.0)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	pivot.add_child(body)


func _light(
	parent: Node3D, node_name: String, at: Vector3, color: Color, energy: float, reach: float
) -> void:
	var omni := OmniLight3D.new()
	omni.name = node_name
	omni.position = at
	omni.light_color = color
	omni.light_energy = energy
	omni.omni_range = reach
	omni.shadow_enabled = false
	parent.add_child(omni)


func _count_modules(root: Node3D) -> int:
	var total := 0
	for node in root.get_children():
		if node.name.begins_with("Body"):
			continue
		total += 1
	return total


# --- floors ---------------------------------------------------------------


## Deck plates on the 6 m grid, alternating two imported floor modules so the
## surface has a pattern instead of being one flat colour.
func _build_floor_grid(parent: Node3D, room: String, alternate: bool = true) -> int:
	var bounds: Dictionary = ROOMS[room]
	var min_x: float = bounds["min"].x
	var max_x: float = bounds["max"].x
	var min_z: float = bounds["min"].y
	var max_z: float = bounds["max"].y
	var count := 0
	var column := 0
	var z := min_z + TILE * 0.5
	while z < max_z:
		var row := 0
		var x := min_x + TILE * 0.5
		while x < max_x:
			var key := "floor"
			if alternate and (column + row) % 2 == 1:
				key = "floor_alt"
			_place(
				parent,
				key,
				"%sDeck_%02d_%02d" % [room.capitalize(), column, row],
				Vector3(x, 0.0, z),
				0.0,
				1.0,
				"floor",
				Vector3.ONE,
				room
			)
			count += 1
			row += 1
			x += TILE
		column += 1
		z += TILE
	return count


func _build_hangar_deck(parent: Node3D) -> void:
	_build_floor_grid(parent, "hangar")
	# A technical channel down the axis and a hazard strip at each threshold: the
	# pack's own grate and stripe modules, not drawn lines.
	for z in [-15.0, -9.0, -3.0, 3.0, 9.0, 15.0]:
		_place(
			parent,
			"floor_tech",
			"HangarChannel_%d" % int(z),
			Vector3(-10.5, 0.02, z),
			0.0,
			1.0,
			"",
			Vector3.ONE,
			"hangar"
		)
		_place(
			parent,
			"floor_tech",
			"HangarChannelE_%d" % int(z),
			Vector3(10.5, 0.02, z),
			0.0,
			1.0,
			"",
			Vector3.ONE,
			"hangar"
		)
	for x in [-15.0, -9.0, 9.0, 15.0]:
		_place(
			parent,
			"floor_coin",
			"HangarHazardN_%d" % int(x),
			Vector3(x, 0.03, -16.6),
			0.0,
			1.0,
			"",
			Vector3.ONE,
			"hangar"
		)
		_place(
			parent,
			"floor_coin",
			"HangarHazardS_%d" % int(x),
			Vector3(x, 0.03, 16.6),
			0.0,
			1.0,
			"",
			Vector3.ONE,
			"hangar"
		)
	# Landing markings at the gate: two hazard stripes either side of the opening.
	for side in [-1.0, 1.0]:
		_place(
			parent,
			"floor_strip",
			"GateStripe_%s" % str(side),
			Vector3(side * 4.2, 0.03, 16.0),
			90.0,
			0.55,
			"",
			Vector3.ONE,
			"hangar"
		)
	_build_floor_grid_centre(parent)


## The centre of the hangar is where the player stands, so it gets the pack's
## small circular deck marker rather than another 6 m plate on top.
func _build_floor_grid_centre(parent: Node3D) -> void:
	for offset in [Vector2(0.0, 0.0)]:
		_place(
			parent,
			"floor_coin",
			"HangarMarkingCentre",
			Vector3(offset.x, 0.03, offset.y + 8.0),
			0.0,
			1.6,
			"",
			Vector3.ONE,
			"hangar"
		)


func _build_reactor_deck(parent: Node3D) -> void:
	_build_floor_grid(parent, "reactor")
	_place(
		parent,
		"floor_strip",
		"ReactorHazardLine",
		Vector3(0.0, 0.03, -20.5),
		0.0,
		3.4,
		"",
		Vector3.ONE,
		"reactor"
	)


func _build_cargo_deck(parent: Node3D) -> void:
	_build_floor_grid(parent, "cargo", false)
	for z in [-3.0, 3.0]:
		_place(
			parent,
			"floor_strip",
			"CargoLane_%d" % int(z),
			Vector3(-28.0, 0.03, z),
			0.0,
			2.2,
			"",
			Vector3.ONE,
			"cargo"
		)


func _build_corridor_deck(parent: Node3D) -> void:
	_build_floor_grid(parent, "corridor", false)
	_place(
		parent,
		"floor_tech",
		"CorridorConduit",
		Vector3(31.0, 0.02, 2.4),
		0.0,
		4.2,
		"",
		Vector3.ONE,
		"corridor"
	)


# --- walls ----------------------------------------------------------------


## The hangar's four walls, built as runs of the pack's 6 m wall modules with a
## door frame where a route leaves the room. `Wall_Simple_01_Long` is 2 m thick
## and 6 m long, so a run along X is the same module turned 90 degrees — the bay
## builder learned this the hard way and every run here follows the same rule.
func _build_walls(parent: Node3D) -> void:
	_wall_run_x(parent, 19.0, [-15.0, -9.0, 9.0, 15.0], "HangarWallE", "wall", "hangar")
	_wall_run_x(parent, -19.0, [-15.0, -9.0, 9.0, 15.0], "HangarWallW", "wall_b", "hangar")
	# East: the corridor leaves through it. West: the cargo bay does.
	for side in [-1.0, 1.0]:
		var yaw := 90.0
		_place(
			parent,
			"doorway_large",
			"HangarDoorFrame_%s" % str(side),
			Vector3(19.0 * side, 0.0, 0.0),
			yaw,
			1.0,
			"box",
			Vector3.ONE,
			"hangar"
		)
		_place(
			parent,
			"wall_half",
			"HangarDoorJambN_%s" % str(side),
			Vector3(19.0 * side, 0.0, -4.5),
			yaw,
			1.0,
			"box",
			Vector3.ONE,
			"hangar"
		)
		_place(
			parent,
			"wall_half",
			"HangarDoorJambS_%s" % str(side),
			Vector3(19.0 * side, 0.0, 4.5),
			yaw,
			1.0,
			"box",
			Vector3.ONE,
			"hangar"
		)

	# North (reactor hall) and south (the gate) walls run along X.
	for z_side in [-1.0, 1.0]:
		var z := 19.0 * z_side
		for x in [-15.0, -9.0, 9.0, 15.0]:
			var key := "wall_c" if x < 0.0 else "wall"
			_place(
				parent,
				key,
				"HangarWallX_%d_%d" % [z_side, int(x)],
				Vector3(x, 0.0, z),
				-90.0,
				1.0,
				"box",
				Vector3.ONE,
				"hangar"
			)
		for x in [-4.5, 4.5]:
			_place(
				parent,
				"wall_half",
				"HangarWallJamb_%d_%d" % [z_side, int(x)],
				Vector3(x, 0.0, z),
				-90.0,
				1.0,
				"box",
				Vector3.ONE,
				"hangar"
			)

	_build_reactor_walls(parent)
	_build_cargo_walls(parent)
	_build_corridor_walls(parent)


func _wall_run_x(
	parent: Node3D, x: float, zs: Array, prefix: String, key: String, room: String
) -> void:
	for z in zs:
		_place(
			parent,
			key,
			"%s_%d" % [prefix, int(z)],
			Vector3(x, 0.0, z),
			0.0,
			1.0,
			"box",
			Vector3.ONE,
			room
		)


func _build_reactor_walls(parent: Node3D) -> void:
	for side in [-1.0, 1.0]:
		for z in [-22.0, -28.0, -34.0]:
			_place(
				parent,
				"wall_b",
				"ReactorWall_%s_%d" % [str(side), int(z)],
				Vector3(13.0 * side, 0.0, z),
				0.0,
				1.0,
				"box",
				Vector3.ONE,
				"reactor"
			)
	for x in [-9.0, -3.0, 3.0, 9.0]:
		_place(
			parent,
			"wall_e",
			"ReactorBackWall_%d" % int(x),
			Vector3(x, 0.0, -38.0),
			-90.0,
			1.0,
			"box",
			Vector3.ONE,
			"reactor"
		)
	# The shared wall with the hangar already exists; a frame on this side of it
	# makes the threshold read from inside the reactor hall too.
	_place(
		parent,
		"doorway_large",
		"ReactorDoorFrame",
		Vector3(0.0, 0.0, -19.0),
		90.0,
		1.0,
		"box",
		Vector3.ONE,
		"reactor"
	)


func _build_cargo_walls(parent: Node3D) -> void:
	for side in [-1.0, 1.0]:
		for x in [-34.0, -28.0, -22.0]:
			_place(
				parent,
				"wall",
				"CargoWall_%s_%d" % [str(side), int(x)],
				Vector3(x, 0.0, 7.0 * side),
				-90.0,
				1.0,
				"box",
				Vector3.ONE,
				"cargo"
			)
	for z in [-3.0, 3.0]:
		_place(
			parent,
			"wall_c",
			"CargoBackWall_%d" % int(z),
			Vector3(-38.0, 0.0, z),
			0.0,
			1.0,
			"box",
			Vector3.ONE,
			"cargo"
		)
	_place(
		parent,
		"doorway_large",
		"CargoDoorFrame",
		Vector3(-19.0, 0.0, 0.0),
		90.0,
		1.0,
		"box",
		Vector3.ONE,
		"cargo"
	)


func _build_corridor_walls(parent: Node3D) -> void:
	for x in [22.0, 28.0, 34.0, 40.0]:
		_place(
			parent,
			"wall",
			"CorridorWallN_%d" % int(x),
			Vector3(x, 0.0, -4.0),
			-90.0,
			1.0,
			"box",
			Vector3.ONE,
			"corridor"
		)
		# The south side is one wall module short: a porthole module fills it, so
		# the corridor looks out at the skybox instead of at more plating.
		if x == 28.0:
			_place(
				parent,
				"porthole",
				"CorridorPorthole",
				Vector3(x, 0.0, 4.0),
				90.0,
				1.0,
				"box",
				Vector3.ONE,
				"corridor"
			)
		else:
			_place(
				parent,
				"wall_b",
				"CorridorWallS_%d" % int(x),
				Vector3(x, 0.0, 4.0),
				90.0,
				1.0,
				"box",
				Vector3.ONE,
				"corridor"
			)
	_place(
		parent,
		"wall_c",
		"CorridorEndWall",
		Vector3(43.0, 0.0, 0.0),
		0.0,
		1.0,
		"box",
		Vector3.ONE,
		"corridor"
	)


# --- ceiling --------------------------------------------------------------


## A roof over every room, at 4.4 m: the module is 4 m tall, so a 0.4 m allowance
## keeps the truss line above head height. Four glass plates over the hangar's
## centre and two over the reactor let the sky in where the composition needs it.
func _build_ceiling(parent: Node3D) -> void:
	for room in ROOMS:
		var bounds: Dictionary = ROOMS[room]
		var z: float = bounds["min"].y + TILE * 0.5
		var column := 0
		while z < bounds["max"].y:
			var x: float = bounds["min"].x + TILE * 0.5
			var row := 0
			while x < bounds["max"].x:
				var glass := false
				if room == "hangar":
					glass = absf(x) < 4.0 and (absf(z) < 4.0 or absf(z + 12.0) < 4.0)
				elif room == "reactor":
					glass = absf(x) < 4.0 and absf(z + 27.0) < 4.0
				var key := "roof_glass" if glass else "roof"
				_place(
					parent,
					key,
					"%sRoof_%02d_%02d" % [room.capitalize(), column, row],
					Vector3(x, ROOF_Y, z),
					0.0,
					1.0,
					"",
					Vector3.ONE,
					room
				)
				row += 1
				x += TILE
			column += 1
			z += TILE


# --- landmarks and dressing ----------------------------------------------


## The gate the theatre is named for. A door frame, a lit lintel, hazard plates,
## the pack's own numerals for the dock number, and jambs deep enough to cast a
## shadow across the threshold.
func _build_gatehouse(parent: Node3D) -> void:
	_place(
		parent,
		"doorway_large",
		"DockGate",
		Vector3(0.0, 0.0, 19.0),
		90.0,
		1.0,
		"box",
		Vector3.ONE,
		"hangar"
	)
	for side in [-1.0, 1.0]:
		_place(
			parent,
			"column",
			"DockGatePillar_%s" % str(side),
			Vector3(3.4 * side, 0.0, 19.0),
			90.0,
			1.0,
			"box",
			Vector3.ONE,
			"hangar"
		)
		_place(
			parent,
			"light_strip",
			"DockGateStrip_%s" % str(side),
			Vector3(2.6 * side, 3.5, 18.3),
			0.0,
			1.5,
			"",
			Vector3.ONE,
			"hangar"
		)
	# "07" over the gate, in the pack's own numeral modules.
	_place(
		parent,
		"num_0",
		"DockNumeralZero",
		Vector3(-1.5, 2.9, 18.4),
		0.0,
		0.45,
		"",
		Vector3.ONE,
		"hangar"
	)
	_place(
		parent,
		"num_7",
		"DockNumeralSeven",
		Vector3(1.5, 2.9, 18.4),
		0.0,
		0.45,
		"",
		Vector3.ONE,
		"hangar"
	)
	_place(
		parent,
		"sign_caution",
		"GateCautionSign",
		Vector3(-6.5, 2.6, 18.3),
		0.0,
		0.5,
		"",
		Vector3.ONE,
		"hangar"
	)


## The reactor: the pack's turbine face on the back wall, a stack of fin columns
## and pipe runs around it, consoles at the base and the corridor lights washing
## the whole alcove. This is the landmark the player sees from spawn, so it is
## built from the largest modules in the pack rather than dressed with props.
func _build_reactor(parent: Node3D) -> void:
	# Turbine face, set into a recess framed by two fin columns.
	_place(
		parent,
		"gear",
		"ReactorTurbineFace",
		Vector3(0.0, 2.2, -36.6),
		0.0,
		1.7,
		"box",
		Vector3.ONE,
		"reactor"
	)
	for side in [-1.0, 1.0]:
		_place(
			parent,
			"column",
			"ReactorFin_%s" % str(side),
			Vector3(4.0 * side, 0.0, -35.4),
			0.0,
			1.0,
			"box",
			Vector3.ONE,
			"reactor"
		)
		_place(
			parent,
			"pipes_b",
			"ReactorPipeRise_%s" % str(side),
			Vector3(7.6 * side, 1.3, -33.0),
			90.0,
			1.0,
			"",
			Vector3.ONE,
			"reactor"
		)
		_place(
			parent,
			"light_corridor",
			"ReactorLightStrip_%s" % str(side),
			Vector3(6.4 * side, 3.6, -29.0),
			90.0,
			1.4,
			"",
			Vector3.ONE,
			"reactor"
		)
	# The plinth the reactor sits on, and the consoles that face it.
	for z in [-33.0, -29.0, -25.0]:
		_place(
			parent,
			"pipes_c",
			"ReactorPipeRun_%d" % int(z),
			Vector3(-10.4, 0.2, z),
			90.0,
			1.0,
			"box",
			Vector3.ONE,
			"reactor"
		)
	_place(
		parent,
		"console_large",
		"ReactorConsoleWest",
		Vector3(-11.2, 0.0, -24.0),
		90.0,
		1.0,
		"box",
		Vector3.ONE,
		"reactor"
	)
	_place(
		parent,
		"console_large",
		"ReactorConsoleEast",
		Vector3(11.2, 0.0, -24.0),
		-90.0,
		1.0,
		"box",
		Vector3.ONE,
		"reactor"
	)
	_place(
		parent,
		"table",
		"ReactorWorkBench",
		Vector3(-4.5, 0.0, -23.0),
		0.0,
		1.0,
		"box",
		Vector3.ONE,
		"reactor"
	)
	_place(
		parent,
		"word_warning",
		"ReactorWarningDecal",
		Vector3(-11.9, 2.9, -30.0),
		90.0,
		0.6,
		"",
		Vector3.ONE,
		"reactor"
	)
	_place(
		parent,
		"sign_danger",
		"ReactorDangerSign",
		Vector3(11.9, 2.6, -22.0),
		-90.0,
		0.7,
		"",
		Vector3.ONE,
		"reactor"
	)


func _build_cargo_bay(parent: Node3D) -> void:
	# Crate stacks, scaled from the pack's crate module so the bay reads as full
	# instead of as a room with four boxes in it.
	var stacks := [
		Vector3(-33.0, 0.0, -4.6),
		Vector3(-30.4, 0.0, -4.6),
		Vector3(-27.8, 0.0, -4.6),
		Vector3(-33.0, 0.0, 4.6),
		Vector3(-30.4, 0.0, 4.6),
		Vector3(-24.5, 0.0, 4.4),
	]
	for index in range(stacks.size()):
		var at: Vector3 = stacks[index]
		var height := 1.6 if index % 3 == 0 else 1.2
		_place(
			parent, "crate", "CargoCrate_%02d" % index, at, 0.0, height, "box", Vector3.ONE, "cargo"
		)
		if index % 3 == 0:
			_place(
				parent,
				"crate",
				"CargoCrateTop_%02d" % index,
				at + Vector3(0.0, height * 0.75, 0.0),
				90.0,
				height * 0.8,
				"box",
				Vector3.ONE,
				"cargo"
			)
	_place(
		parent,
		"wall_pipes",
		"CargoPipeRun",
		Vector3(-30.0, 1.05, -6.6),
		0.0,
		1.0,
		"",
		Vector3.ONE,
		"cargo"
	)
	_place(
		parent,
		"console_half",
		"CargoManifestConsole",
		Vector3(-22.5, 0.0, -5.4),
		180.0,
		0.9,
		"box",
		Vector3.ONE,
		"cargo"
	)
	_place(
		parent,
		"sign_caution",
		"CargoCautionSign",
		Vector3(-19.9, 2.6, 0.0),
		180.0,
		0.55,
		"",
		Vector3.ONE,
		"cargo"
	)
	_place(
		parent,
		"word_zone",
		"CargoZoneDecal",
		Vector3(-24.0, 2.4, 6.7),
		0.0,
		0.5,
		"",
		Vector3.ONE,
		"cargo"
	)


func _build_corridor_dressing(parent: Node3D) -> void:
	for index in range(4):
		var x := 22.0 + float(index) * 6.0
		_place(
			parent,
			"light_corridor",
			"CorridorLight_%02d" % index,
			Vector3(x, ROOF_Y - 0.2, 0.0),
			0.0,
			1.0,
			"",
			Vector3.ONE,
			"corridor"
		)
		_place(
			parent,
			"beam",
			"CorridorRib_%02d" % index,
			Vector3(x, 0.0, 0.0),
			0.0,
			1.0,
			"",
			Vector3.ONE,
			"corridor"
		)
	_place(
		parent,
		"intercom",
		"CorridorIntercom",
		Vector3(25.0, 1.6, -3.7),
		0.0,
		1.4,
		"",
		Vector3.ONE,
		"corridor"
	)
	_place(
		parent,
		"sign_danger",
		"CorridorSign",
		Vector3(38.0, 2.6, 3.7),
		180.0,
		0.6,
		"",
		Vector3.ONE,
		"corridor"
	)
	_place(
		parent,
		"word_exit",
		"CorridorExitDecal",
		Vector3(41.6, 2.4, -3.6),
		180.0,
		0.4,
		"",
		Vector3.ONE,
		"corridor"
	)
	_place(
		parent,
		"console_half",
		"CorridorConsole",
		Vector3(36.0, 0.0, -3.4),
		0.0,
		0.8,
		"box",
		Vector3.ONE,
		"corridor"
	)
	# The hangar's inner east wall gets the same treatment as the corridor, so the
	# route reads continuously from the deck the player starts on.
	_place(
		parent,
		"wall_pipes",
		"HangarPipeRunEast",
		Vector3(17.9, 1.05, -8.0),
		0.0,
		1.0,
		"",
		Vector3.ONE,
		"hangar"
	)
	_place(
		parent,
		"wall_pipes",
		"HangarPipeRunWest",
		Vector3(-17.9, 1.05, 10.0),
		0.0,
		1.0,
		"",
		Vector3.ONE,
		"hangar"
	)
	_place(
		parent,
		"console_large",
		"HangarConsoleEast",
		Vector3(17.6, 0.0, 12.0),
		-90.0,
		0.9,
		"box",
		Vector3.ONE,
		"hangar"
	)
	_place(
		parent,
		"console_half",
		"HangarConsoleWest",
		Vector3(-17.4, 0.0, -12.0),
		90.0,
		0.9,
		"box",
		Vector3.ONE,
		"hangar"
	)
	_place(
		parent,
		"intercom",
		"HangarIntercom",
		Vector3(-17.6, 1.6, 2.0),
		90.0,
		1.6,
		"",
		Vector3.ONE,
		"hangar"
	)
	_place(
		parent,
		"word_zone",
		"HangarZoneDecal",
		Vector3(17.7, 2.6, -2.0),
		-90.0,
		0.62,
		"",
		Vector3.ONE,
		"hangar"
	)
	_place(
		parent,
		"sign_danger",
		"HangarDangerSign",
		Vector3(-17.7, 2.6, -6.0),
		90.0,
		0.7,
		"",
		Vector3.ONE,
		"hangar"
	)
	for x in [-15.0, -9.0, 9.0, 15.0]:
		for side in [-1.0, 1.0]:
			_place(
				parent,
				"light_strip",
				"HangarWallLight_%d_%s" % [int(x), str(side)],
				Vector3(x, 3.3, 17.6 * side),
				180.0 if side > 0.0 else 0.0,
				1.6,
				"",
				Vector3.ONE,
				"hangar"
			)


## Two catwalks along the hangar's long walls. They are stepped, not ramped: three
## landings at 1.1 m intervals, because the pack's stair module is authored around
## its own origin with the flight running along -Z and reads wrong the moment it
## is turned to face the room. Landings are honest about what they are.
func _build_catwalks(parent: Node3D) -> void:
	for side in [-1.0, 1.0]:
		var x: float = 16.4 * side
		for z in [-12.0, -6.0, 0.0, 6.0, 12.0]:
			_place(
				parent,
				"platform_flat",
				"CatwalkDeck_%s_%d" % [str(side), int(z)],
				Vector3(x, CATWALK_Y, z),
				0.0,
				1.0,
				"floor",
				Vector3(0.36, 1.0, 1.0),
				"hangar"
			)
			_place(
				parent,
				"fence",
				"CatwalkRail_%s_%d" % [str(side), int(z)],
				Vector3(x - 1.0 * side, CATWALK_Y + 0.72, z),
				0.0,
				1.0,
				"box",
				Vector3.ONE,
				"hangar"
			)
		# Landing steps up to the walk, at the south end of each side.
		for step_index in range(3):
			var height := CATWALK_Y * float(step_index + 1) / 4.0
			_place(
				parent,
				"platform_flat",
				"CatwalkStep_%s_%d" % [str(side), step_index],
				Vector3(x, height, 15.6 + float(step_index) * 1.6),
				0.0,
				1.0,
				"floor",
				Vector3(0.36, 1.0, 0.22),
				"hangar"
			)


# --- light ----------------------------------------------------------------


## Eight unshadowed omnis in four rooms. The pack's own light modules are in every
## room as geometry, so these only lift what the emissive strips cannot reach.
func _build_lighting(parent: Node3D) -> void:
	var cold := Color(0.72, 0.86, 1.0)
	var warm := Color(1.0, 0.62, 0.28)
	_light(parent, "HangarLightNW", Vector3(-9.0, 3.7, -9.0), cold, 2.6, 26.0)
	_light(parent, "HangarLightNE", Vector3(9.0, 3.7, -9.0), cold, 2.6, 26.0)
	_light(parent, "HangarLightSW", Vector3(-9.0, 3.7, 9.0), cold, 2.6, 26.0)
	_light(parent, "HangarLightSE", Vector3(9.0, 3.7, 9.0), cold, 2.6, 26.0)
	_light(parent, "HangarGateLight", Vector3(0.0, 3.6, 16.5), warm, 2.2, 18.0)
	_light(parent, "ReactorLight", Vector3(0.0, 3.7, -28.0), Color(0.45, 0.8, 1.0), 3.2, 24.0)
	_light(parent, "CargoLight", Vector3(-28.0, 3.5, 0.0), cold, 1.8, 18.0)
	_light(parent, "CorridorLightWest", Vector3(25.0, 3.6, 0.0), cold, 1.6, 14.0)
	_light(parent, "CorridorLightEast", Vector3(37.0, 3.6, 0.0), cold, 1.6, 14.0)
	# A rim light behind the reactor, so the turbine face is not a silhouette.
	_light(parent, "ReactorRim", Vector3(0.0, 2.0, -36.0), Color(0.3, 0.7, 1.0), 1.8, 12.0)
