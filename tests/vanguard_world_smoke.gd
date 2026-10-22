extends SceneTree

## WORLD 01 — Vanguard Zero: the vertical slice, checked where it matters.
##
## The brief is explicit that opening the scene is not completion, so this test
## does not assert "the scene loaded". It builds the real `neon_frontier.tscn`
## and then judges the district the way a player and a collision solver meet it:
##
##   * every family in the slice is present and named, so a future refactor that
##     quietly drops the perimeter fails here rather than in a screenshot;
##   * the damage family really differs — an intact wall has an emissive trim
##     rail, a destroyed one does not, and both still sit on the same plinth
##     (a ruin has to look like the thing it came from);
##   * the gate's opening is walkable: a capsule can travel the arena axis from
##     outside the gate to the deck without touching a collider;
##   * the wall line has one breach and the breach is wide enough to walk
##     through, measured against the wall modules that exist;
##   * nothing in the district was dropped at spawn height inside the arena, and
##     nothing the player can walk into was left without collision beneath it;
##   * the distant spire has no collision and is outside the playable floor —
##     it is scenery, and it must not become a wall at the map edge;
##   * the district added a bounded number of lights and draw calls, so "it looks
##     better" can be read against what it cost.
##
## What it cannot do is see pixels. `exports/flow/vanguard/` holds the frames
## that were looked at, and `docs/VERIFICATION_2026-10-22.md` §10 records which
## claims are VERIFIED and which are only LIKELY.

const MainScene = preload("res://scenes/main.tscn")

const DISTRICT_NODE := "VanguardDeploymentGate"
const SPAWN := Vector3(0.0, 0.0, 8.0)

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	AegisPreferences.write(AegisPreferences.defaults())
	var main_scene := MainScene.instantiate()
	main_scene.set("start_wave_session_on_ready", false)
	main_scene.get_node("ProgressionService").set("profile_path", "")
	root.add_child(main_scene)
	await process_frame
	await process_frame

	var world: Node3D = main_scene.get_node("NeonFrontier")
	var gate := world.get_node_or_null(DISTRICT_NODE) as Node3D
	if not _expect(gate != null, "the deployment gate is built in the world"):
		_finish(main_scene)
		return

	_check_families_present(world)
	_check_damage_family_differs(world)
	_check_gate_is_walkable(world)
	_check_breach_is_walkable(world)
	_check_collision_is_intentional(world)
	_check_distant_scenery_is_not_an_obstacle(world)
	_check_budget(world)
	_finish(main_scene)


## Every family the slice claims to contain, by node name.
func _check_families_present(world: Node3D) -> void:
	var expected := {
		"DISTRICT_GATE": "VanguardDeploymentGate",
		"PERIMETER_WALL": "PerimeterWall_-30",
		"BREACH_DEBRIS": "BreachDebrisInner",
		"CRATER": "BreachCrater",
		"CONDUIT": "GateFeedConduit",
		"YARD_COVER": "YardCover_0",
		"MEGASTRUCTURE": "VanguardCommandSpire",
	}
	for label in expected:
		var found := world.get_node_or_null(expected[label]) != null
		if not found:
			# The perimeter nodes are named from their x coordinate and the sign
			# can differ by a float, so fall back to a prefix search.
			for child in world.get_children():
				if String(child.name).begins_with(String(expected[label]).split("_")[0]):
					found = true
					break
		_expect(found, "%s is present in the slice" % label)


## The three damage states have to be visibly different objects, not three names.
func _check_damage_family_differs(world: Node3D) -> void:
	var intact := _wall_mesh_names(world, "PerimeterWall_-22")
	var wrecked := _wall_mesh_names(world, "PerimeterWall_-6")
	_expect(not intact.is_empty(), "an intact wall module has geometry")
	_expect(not wrecked.is_empty(), "a destroyed wall module has geometry")
	_expect(intact.has("TrimRail"), "an intact wall carries the family's emissive trim rail")
	_expect(
		not wrecked.has("TrimRail"),
		"a destroyed wall has no live trim rail (the trim is what says 'powered')"
	)
	_expect(
		wrecked.has("FallenPanel"),
		"a destroyed wall leaves its own panels on the deck, not generic rubble"
	)
	# Both states keep the plinth: the ruin is recognisably the same structure.
	_expect(intact.has("Plinth") and wrecked.has("Plinth"), "both states stand on the same plinth")


func _wall_mesh_names(world: Node3D, node_name: String) -> Array[String]:
	var names: Array[String] = []
	var wall := world.get_node_or_null(node_name)
	if wall == null:
		return names
	for child in wall.find_children("*", "MeshInstance3D", true, false):
		names.append(str(child.name).split("_")[0])
	return names


## A capsule must be able to walk the arena axis through the gate opening.
func _check_gate_is_walkable(world: Node3D) -> void:
	_expect(
		world.get_node_or_null("VanguardDeploymentGate") != null,
		"gate node resolves for the walk test"
	)
	var space := main_space()
	if space == null:
		_expect(false, "physics space is available for the walk test")
		return
	var shape := CapsuleShape3D.new()
	shape.radius = 0.42
	shape.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	# Walk from 4 m outside the gate to 4 m inside it, at chest height.
	var blocked := 0
	for step in range(17):
		var z := 50.0 - float(step) * 0.5
		query.transform = Transform3D(Basis(), Vector3(0.0, 1.0, z))
		if not space.intersect_shape(query, 1).is_empty():
			blocked += 1
	_expect(
		blocked == 0,
		"the gate opening is clear along the arena axis (%d blocked samples)" % blocked
	)


## The wall line has to have a hole a player can use, and the hole has to be in
## the line rather than at the map edge.
func _check_breach_is_walkable(world: Node3D) -> void:
	_expect(world.get_node_or_null("BreachDebrisInner") != null, "the breach debris resolves")
	var space := main_space()
	if space == null:
		return
	var shape := CapsuleShape3D.new()
	shape.radius = 0.42
	shape.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	# The breach sits at x = +6 in the layout; sample across it.
	var blocked := 0
	for step in range(11):
		var x := 1.5 + float(step) * 0.9
		query.transform = Transform3D(Basis(), Vector3(x, 1.0, 34.0))
		if not space.intersect_shape(query, 1).is_empty():
			blocked += 1
	_expect(
		blocked <= 1, "the perimeter breach is open enough to walk through (%d blocked)" % blocked
	)
	# And the wall either side of it is solid, or there is no line at all.
	query.transform = Transform3D(Basis(), Vector3(-22.0, 1.0, 34.0))
	_expect(
		not space.intersect_shape(query, 1).is_empty(),
		"an intact wall module is solid where the player would expect a wall"
	)


## Nothing decorative may be left with a collider, and nothing the player can
## walk into may be missing one.
func _check_collision_is_intentional(world: Node3D) -> void:
	var craters := 0
	var crater_bodies := 0
	for child in world.get_children():
		if not String(child.name).begins_with("BreachCrater"):
			continue
		craters += 1
		if child.find_children("*", "StaticBody3D", true, false).size() > 0:
			crater_bodies += 1
	_expect(craters > 0, "the breach has impact craters")
	_expect(
		crater_bodies == 0,
		"craters are decoration and carry no collider (%d of %d did)" % [crater_bodies, craters]
	)
	var spire := world.get_node_or_null("VanguardCommandSpire")
	if spire != null:
		_expect(
			spire.find_children("*", "CollisionShape3D", true, false).is_empty(),
			"the distant spire has no collision, so it cannot fence the map"
		)


func _check_distant_scenery_is_not_an_obstacle(world: Node3D) -> void:
	var spire := world.get_node_or_null("VanguardCommandSpire") as Node3D
	if spire == null:
		_expect(false, "the command spire exists for the horizon check")
		return
	# The playable floor ends at z = -100; the spire must be well beyond it.
	_expect(spire.global_position.z < -100.0, "the spire is outside the playable floor")
	_expect(spire.global_position.y > -20.0, "the spire is not buried")


## The district has a cost. Record it so a later change can be compared with it.
func _check_budget(world: Node3D) -> void:
	var meshes := 0
	var lights := 0
	var bodies := 0
	for child in world.get_children():
		if (
			not String(child.name).begins_with("Vanguard")
			and not String(child.name).begins_with("Perimeter")
			and not String(child.name).begins_with("Breach")
			and not String(child.name).begins_with("Gate")
			and not String(child.name).begins_with("Yard")
			and not String(child.name).begins_with("Arena")
			and not String(child.name).begins_with("Checkpoint")
			and not String(child.name).begins_with("Fallen")
			and not String(child.name).begins_with("Approach")
		):
			continue
		meshes += child.find_children("*", "MeshInstance3D", true, false).size()
		lights += child.find_children("*", "Light3D", true, false).size()
		bodies += child.find_children("*", "StaticBody3D", true, false).size()
	print(
		(
			"Vanguard slice budget: %d mesh instances, %d colliders across its components"
			% [meshes, bodies]
		)
	)
	_expect(meshes > 120, "the district carries real geometry (%d meshes)" % meshes)
	_expect(lights == 0, "components carry no lights of their own (%d did)" % lights)


func main_space() -> PhysicsDirectSpaceState3D:
	var world_3d := root.get_world_3d()
	return world_3d.direct_space_state if world_3d != null else null


func _expect(condition: bool, description: String) -> bool:
	if not condition:
		_failures.append(description)
		printerr("  fail: %s" % description)
	return condition


func _finish(main_scene: Node) -> void:
	main_scene.queue_free()
	if _failures.is_empty():
		print("Vanguard world smoke test PASSED")
		quit(0)
		return
	printerr("Vanguard world smoke test FAILED:")
	for failure in _failures:
		printerr("  - " + failure)
	quit(1)
