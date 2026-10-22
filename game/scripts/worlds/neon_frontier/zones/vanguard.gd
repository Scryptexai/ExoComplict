## ZONE A–E of WORLD 01: Vanguard Zero — the Fallen Frontier.
##
## This is the vertical slice, and it is deliberately arranged as the *approach*
## to the existing arena rather than replacing it: the player deploys through the
## gate the brief describes, crosses a breached defence line, and looks up at a
## command spire they will never reach. The arena itself keeps its layout, which
## is what protects the gameplay that already exists while the new district
## earns its place.
##
##   ZONE A  deployment gate      z +74   the checkpoint the player leaves through
##   ZONE B  outer perimeter      z +62   a wall line with one breach in it
##   ZONE C  industrial yard      z +48   containers and cover on the approach
##   ZONE D  reactor feed annex   z +60   conduits running back to the gate
##   ZONE E  distant megastructure z -196 a command spire on the horizon
##
## The district sits beyond z = +44, clear of the perimeter relay array at z = +40
## and of the arena's 42 m combat disc. The first layout overlapped both and read
## as clutter in a capture rather than as a district; `vanguard_world_smoke`
## asserts the clearance now so it cannot drift back.
##
## Coordinates are world-space metres. The gate's opening is on the arena axis
## (x = 0) so a player who spawns at (0, 0, 8) and turns around sees the way they
## came in, and the breach in the wall is offset to x ≈ +6 so it is not hidden
## behind the gate's own pylons from the spawn point.
class_name NeonFrontierVanguardZone
extends RefCounted


static func build_vanguard_frontier(world) -> void:
	# Everything this district adds is tagged as it is added, so a test can ask
	# "what did Vanguard build" instead of guessing from node names. The first
	# attempt guessed by prefix and matched `PerimeterRelayArray`, a prop that was
	# already in the world.
	var before := {}
	for child in world.get_children():
		before[child] = true

	_build_deployment_gate(world)
	_build_outer_perimeter(world)
	_build_industrial_yard(world)
	_build_reactor_feed(world)
	_build_distant_megastructure(world)
	_add_zone_lighting(world)

	for child in world.get_children():
		if before.has(child):
			continue
		child.set_meta("vanguard_district", true)


## ZONE A. The gate is the first thing behind the player and the last thing they
## see on the way out, so it carries the identification plate and the lit
## threshold rather than being a frame.
static func _build_deployment_gate(world) -> void:
	world._place_component(
		world.VANGUARD_GATE_SCENE,
		"VanguardDeploymentGate",
		Vector3(0.0, 0.0, 74.0),
		Vector3.ZERO,
		Vector3.ONE,
		3,
		1
	)
	# Checkpoint annexes either side: the gate is a *checkpoint*, and a checkpoint
	# without anywhere for the guards to stand is a doorway.
	for sign_x in [-1.0, 1.0]:
		world._place_component(
			world.VANGUARD_WALL_SCENE,
			"CheckpointWing_%s" % str(sign_x),
			Vector3(sign_x * 16.4, 0.0, 73.2),
			Vector3(0.0, 90.0, 0.0),
			Vector3.ONE,
			1,
			0
		)
	world._place_component(
		world.VANGUARD_CRATER_SCENE,
		"GateImpactScar",
		Vector3(-9.5, 0.0, 69.0),
		Vector3(0.0, 24.0, 0.0),
		Vector3.ONE,
		2,
		1
	)
	world._place_component(
		world.COVER_SCENE,
		"GateCheckpointCover",
		Vector3(6.5, 0.0, 69.5),
		Vector3(0.0, 12.0, 0.0),
		Vector3.ONE,
		5
	)


## ZONE B. One wall line, one breach, and everything else explaining the breach:
## the craters are on the outside face, the debris is thrown inward, and the
## turret that should have stopped it is the one facing the gap.
static func _build_outer_perimeter(world) -> void:
	# x positions on an 8 m grid; the two modules at +2 and +10 are missing, which
	# is the breach. Damage escalates towards it, so the line tells the story of
	# where the hit came from instead of looking uniformly weathered.
	var modules := [
		{"x": -30.0, "damage": 1, "seed": 4},
		{"x": -22.0, "damage": 0, "seed": 1},
		{"x": -14.0, "damage": 1, "seed": 2},
		{"x": -6.0, "damage": 2, "seed": 7},
		{"x": 18.0, "damage": 1, "seed": 5},
		{"x": 26.0, "damage": 0, "seed": 6},
	]
	for index in range(modules.size()):
		var entry: Dictionary = modules[index]
		# `world` is untyped here (the zone takes the composition root), so the
		# return has to be named explicitly: `:=` cannot infer through a var.
		var wall: Node3D = world._place_component(
			world.VANGUARD_WALL_SCENE,
			"PerimeterWall_%02d" % index,
			Vector3(entry["x"], 0.0, 62.0),
			Vector3.ZERO,
			Vector3.ONE,
			int(entry["seed"]),
			int(entry["damage"])
		)
		# The state is carried on the node so a test, or a later pass that wants to
		# scatter more damage, can ask the wall what it is instead of parsing a
		# name. Names that encode coordinates are what broke the first version of
		# this check.
		wall.set_meta("vanguard_family", "defense_wall")
		wall.set_meta("damage_state", int(entry["damage"]))

	# The breach itself: thrown panels inside the line, two craters outside it.
	world._place_component(
		world.VANGUARD_DEBRIS_SCENE,
		"BreachDebrisInner",
		Vector3(6.0, 0.0, 59.0),
		Vector3.ZERO,
		Vector3.ONE,
		11,
		2
	)
	world._place_component(
		world.VANGUARD_DEBRIS_SCENE,
		"BreachDebrisOuter",
		Vector3(10.5, 0.0, 65.4),
		Vector3.ZERO,
		Vector3.ONE,
		12,
		2
	)
	world._place_component(
		world.VANGUARD_CRATER_SCENE,
		"BreachCrater",
		Vector3(6.5, 0.0, 67.5),
		Vector3(0.0, 40.0, 0.0),
		Vector3.ONE,
		3,
		1
	)
	world._place_component(
		world.VANGUARD_CRATER_SCENE,
		"BreachCraterSmall",
		Vector3(13.0, 0.0, 61.0),
		Vector3(0.0, 8.0, 0.0),
		Vector3.ONE,
		4,
		0
	)

	# The turret that faced the gap, knocked out. Placed inside the line looking
	# out through the breach, which is where it would have been sited.
	world._place_component(
		world.TURRET_SCENE,
		"BreachTurretKnockedOut",
		Vector3(16.5, 0.0, 64.5),
		Vector3(0.0, -34.0, 0.0),
		Vector3.ONE,
		9
	)
	# A transport that never left the approach road.
	world._place_component(
		world.TRANSPORT_SCENE,
		"ApproachTransportWreck",
		Vector3(-18.0, 0.0, 55.0),
		Vector3(0.0, 26.0, 0.0),
		Vector3.ONE,
		8
	)
	# Structural supports that held the wall's maintenance rail, now fallen.
	world._place_component(
		world.VANGUARD_DEBRIS_SCENE,
		"FallenSupportsWest",
		Vector3(-25.0, 0.0, 58.5),
		Vector3.ZERO,
		Vector3.ONE,
		13,
		1
	)


## ZONE C. The yard between the perimeter and the arena: cover the player can
## actually use, spaced so the approach is not a corridor of crates.
static func _build_industrial_yard(world) -> void:
	var posts := [
		Vector3(-11.0, 0.0, 51.0),
		Vector3(9.0, 0.0, 50.0),
		Vector3(-3.0, 0.0, 46.0),
		Vector3(17.0, 0.0, 53.0),
	]
	for index in range(posts.size()):
		world._place_component(
			world.COVER_SCENE,
			"YardCover_%d" % index,
			posts[index],
			Vector3(0.0, 18.0 + float(index) * 24.0, 0.0),
			Vector3.ONE,
			index
		)
	# Processed cargo, in the yard where it was being unloaded.
	world._place_component(
		world.DEPOT_SCENE,
		"YardCargoDepot",
		Vector3(21.0, 0.0, 45.0),
		Vector3(0.0, 90.0, 0.0),
		Vector3.ONE,
		2
	)


## ZONE D. The feed that used to run from the reactor to the gate, and no longer
## does. The broken end points back towards the gate it fed, which is the link
## the brief asks a conduit to have.
static func _build_reactor_feed(world) -> void:
	world._place_component(
		world.VANGUARD_CONDUIT_SCENE,
		"GateFeedConduit",
		Vector3(-6.0, 0.0, 67.5),
		Vector3.ZERO,
		Vector3.ONE,
		2,
		2
	)
	world._place_component(
		world.VANGUARD_CONDUIT_SCENE,
		"ArenaFeedConduit",
		Vector3(-6.0, 0.0, 54.0),
		Vector3.ZERO,
		Vector3.ONE,
		5,
		0
	)
	# The junction the two runs meet at, knocked off its plinth.
	world._place_component(
		world.GENERATOR_SCENE,
		"FeedJunctionDamaged",
		Vector3(-15.0, 0.0, 61.0),
		Vector3(0.0, 90.0, 0.0),
		Vector3.ONE * 0.8,
		4
	)


## ZONE E. Off the playable floor entirely: no collision, no interior, sized for
## the horizon. Placed north of the boss platform so it is the backdrop to the
## direction the player fights towards.
static func _build_distant_megastructure(world) -> void:
	world._place_component(
		world.VANGUARD_SPIRE_SCENE,
		"VanguardCommandSpire",
		Vector3(26.0, -4.0, -196.0),
		Vector3(0.0, 18.0, 0.0),
		Vector3.ONE,
		0,
		1
	)
	# A second, smaller silhouette further west so the horizon has depth rather
	# than one tower placed alone in a void.
	world._place_component(
		world.VANGUARD_SPIRE_SCENE,
		"VanguardRelaySpire",
		Vector3(-96.0, -6.0, -232.0),
		Vector3(0.0, -24.0, 0.0),
		Vector3.ONE * 0.62,
		1,
		1
	)


## Light for the new district. Three fixtures, no shadow casters: the zone has
## to read at night without adding scene-wide exposure the arena did not ask for.
static func _add_zone_lighting(world) -> void:
	var fixtures := [
		{
			"name": "GateThresholdLight",
			"at": Vector3(0.0, 5.0, 72.0),
			"color": Color(0.35, 0.75, 1.0),
			"energy": 1.1,
			"range": 11.0
		},
		{
			"name": "BreachFireLight",
			"at": Vector3(7.0, 2.2, 64.0),
			"color": Color(1.0, 0.42, 0.12),
			"energy": 0.9,
			"range": 9.0
		},
		{
			"name": "FeedArcLight",
			"at": Vector3(-8.0, 2.0, 67.0),
			"color": Color(0.3, 0.85, 1.0),
			"energy": 0.8,
			"range": 8.0
		},
	]
	for fixture in fixtures:
		world._add_omni_light(
			String(fixture["name"]),
			fixture["at"] as Vector3,
			fixture["color"] as Color,
			float(fixture["energy"]),
			float(fixture["range"])
		)
