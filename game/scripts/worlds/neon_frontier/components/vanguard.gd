## The Vanguard Zero asset families.
##
## WORLD 01 — "Vanguard Zero: The Fallen Frontier". These are the pieces the
## deployment gate, the outer defence line, the conduit runs and the reactor
## breach are built from. They are *designed*, not primitives: every family has
## a repeating structural grammar (plinth → armour panels → trim rail →
## emissive marker) so a player can tell a Vanguard wall from a rock at gameplay
## distance, and so the damage variants are recognisably the same object.
##
## The three-state damage family is a parameter, not three files:
##
##   0 INTACT     — all panels in place, trim rail emissive
##   1 DAMAGED    — one panel gone, ribs exposed, trim dark on that side
##   2 DESTROYED  — stub + fallen panels on the deck, no emissive
##
## `NeonFrontierAsset.damage_state` selects it, and the same seed drives where
## the gaps fall, so a wall line reads as one wall that was hit in one place
## rather than twelve random objects.
##
## Everything here is static and takes the asset node, per the module rules in
## `neon_frontier/README.md`: shapes come from `NeonFrontierGeometry`, surfaces
## come from the asset's own palette.
class_name NeonFrontierVanguard
extends RefCounted

const GEOMETRY = preload("res://scripts/worlds/neon_frontier/geometry.gd")

## Wall module footprint. The zone places these on an 8 m grid; the collision
## box is the armour body only, so a player can stand in the gaps between
## modules instead of being stopped by an invisible seam.
const WALL_LENGTH := 8.0
const WALL_HEIGHT := 4.2
const WALL_THICKNESS := 0.9


## One modular defence-wall segment, 8 m long, running along X.
static func build_defense_wall(
	parent: Node3D, materials: Dictionary, damage_state: int, seed: int
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var silver: Material = materials["silver"]
	var ceramic: Material = materials["ceramic"]
	var dark: Material = materials["dark_trim"]
	var glow: Material = materials["cyan"] if damage_state == 0 else materials["reactor_spine"]

	# Plinth: wider than the wall so the module reads as planted, not resting.
	GEOMETRY.box(
		parent,
		"Plinth",
		Vector3(0.0, 0.16, 0.0),
		Vector3(WALL_LENGTH, 0.32, WALL_THICKNESS + 0.5),
		dark,
		Vector3.ZERO,
		true
	)
	GEOMETRY.box(
		parent,
		"PlinthLip",
		Vector3(0.0, 0.35, 0.0),
		Vector3(WALL_LENGTH + 0.24, 0.08, WALL_THICKNESS + 0.62),
		silver
	)

	if damage_state >= 2:
		# A destroyed module is the stub that is left when the armour is gone:
		# plinth, the two end pillars, and the fallen panels on the deck. The
		# fallen panels are the *same* panel shape as the intact wall, which is
		# what ties the ruin to the structure it came from.
		_build_end_pillars(parent, silver, dark, ceramic)
		GEOMETRY.box(
			parent,
			"TornStub",
			Vector3(0.0, 0.72, 0.0),
			Vector3(WALL_LENGTH - 0.6, 0.5, WALL_THICKNESS * 0.8),
			ceramic
		)
		_fall_panel(parent, Vector3(rng.randf_range(-1.6, 1.6), 0.42, 1.35), rng, ceramic, silver)
		_fall_panel(parent, Vector3(rng.randf_range(1.8, 3.0), 0.4, -1.2), rng, ceramic, silver)
		GEOMETRY.box(
			parent,
			"SnappedRebar",
			Vector3(rng.randf_range(-0.8, 0.8), 1.05, 0.0),
			Vector3(0.06, 0.55, 0.06),
			dark,
			Vector3(rng.randf_range(-16.0, 16.0), 0.0, rng.randf_range(-12.0, 12.0))
		)
		return

	_build_end_pillars(parent, silver, dark, ceramic)

	# Three armour panels with shadow gaps between them. The gap is what makes
	# the wall read as engineered at 10 m; a single 8 m box reads as a fence.
	var panel_width := 2.42
	for index in range(3):
		var centre_x := (float(index) - 1.0) * 2.6
		var missing := damage_state == 1 and index == (seed % 3)
		if missing:
			# Exposed structure where the panel used to be: ribs and a bent plate.
			for rib in range(4):
				GEOMETRY.box(
					parent,
					"ExposedRib_%d" % rib,
					Vector3(centre_x, 0.95 + float(rib) * 0.72, 0.0),
					Vector3(panel_width, 0.09, WALL_THICKNESS * 0.55),
					dark
				)
			GEOMETRY.box(
				parent,
				"BentPanel",
				Vector3(centre_x - 0.55, 2.3, 0.62),
				Vector3(1.7, 1.9, 0.14),
				ceramic,
				Vector3(-24.0, 18.0, 8.0)
			)
			continue
		GEOMETRY.box(
			parent,
			"ArmourPanel_%d" % index,
			Vector3(centre_x, 2.15, 0.0),
			Vector3(panel_width, 2.6, WALL_THICKNESS),
			ceramic,
			Vector3.ZERO,
			index == 1 and damage_state == 0
		)
		# Angle brace: the piece that most makes a flat panel look manufactured.
		GEOMETRY.box(
			parent,
			"Brace_%d" % index,
			Vector3(centre_x, 1.05, WALL_THICKNESS * 0.62),
			Vector3(0.16, 1.5, 0.16),
			silver,
			Vector3(0.0, 0.0, 34.0)
		)

	# Trim rail: the emissive line the whole Vanguard family shares. It is the
	# cheapest way to say "this is one faction's hardware" across 20 objects.
	GEOMETRY.box(
		parent,
		"TrimRail",
		Vector3(0.0, 3.55, WALL_THICKNESS * 0.52),
		Vector3(WALL_LENGTH - 0.5, 0.09, 0.05),
		glow
	)
	# Crenellation: short blocks over the rail, so the silhouette is not a line.
	for index in range(4):
		var centre_x := -3.0 + float(index) * 2.0
		GEOMETRY.box(
			parent,
			"Crenel_%d" % index,
			Vector3(centre_x, 3.86, 0.0),
			Vector3(1.1, 0.5, WALL_THICKNESS * 0.85),
			silver
		)
	if damage_state == 0:
		GEOMETRY.bolts(parent, "WallBolt", Vector3.ZERO, Vector2(3.6, 0.0), 0.4, dark)


static func _build_end_pillars(
	parent: Node3D, silver: Material, dark: Material, ceramic: Material
) -> void:
	for sign_x in [-1.0, 1.0]:
		GEOMETRY.box(
			parent,
			"Pillar_%s" % str(sign_x),
			Vector3(sign_x * (WALL_LENGTH * 0.5 - 0.22), 1.6, 0.0),
			Vector3(0.44, 3.2, WALL_THICKNESS + 0.3),
			silver,
			Vector3.ZERO,
			true
		)
		GEOMETRY.box(
			parent,
			"PillarCap_%s" % str(sign_x),
			Vector3(sign_x * (WALL_LENGTH * 0.5 - 0.22), 3.32, 0.0),
			Vector3(0.56, 0.16, WALL_THICKNESS + 0.42),
			dark
		)
		# Buttress fin leaning back into the module: reads from the inside face,
		# which is the side the player actually walks along.
		GEOMETRY.box(
			parent,
			"Buttress_%s" % str(sign_x),
			Vector3(sign_x * 2.4, 1.2, -0.85),
			Vector3(0.3, 2.1, 1.0),
			ceramic,
			Vector3(-22.0, 0.0, 0.0)
		)


static func _fall_panel(
	parent: Node3D, at: Vector3, rng: RandomNumberGenerator, ceramic: Material, silver: Material
) -> void:
	GEOMETRY.box(
		parent,
		"FallenPanel",
		at,
		Vector3(2.3, 0.16, 1.1),
		ceramic,
		Vector3(rng.randf_range(-8.0, 8.0), rng.randf_range(0.0, 180.0), rng.randf_range(-6.0, 6.0))
	)
	GEOMETRY.box(
		parent,
		"FallenBrace",
		at + Vector3(0.6, 0.12, 0.9),
		Vector3(0.14, 0.14, 1.6),
		silver,
		Vector3(0.0, rng.randf_range(0.0, 180.0), 0.0)
	)


## The security checkpoint gate. Two pylons, a header beam, a half-open blast
## door and a lit threshold — the last thing a player walks through before the
## frontier, so it carries the faction's identity rather than being a doorway.
static func build_security_gate(
	parent: Node3D, materials: Dictionary, damage_state: int, seed: int
) -> void:
	var silver: Material = materials["silver"]
	var ceramic: Material = materials["ceramic"]
	var blue: Material = materials["blue"]
	var dark: Material = materials["dark_trim"]
	var glow: Material = materials["cyan"] if damage_state == 0 else materials["orange"]

	var half_span := 7.0
	for sign_x in [-1.0, 1.0]:
		var x: float = sign_x * half_span
		# Pylon: three stacked masses, each inset, with a light slot down the face.
		GEOMETRY.box(
			parent,
			"GateFoot_%s" % str(sign_x),
			Vector3(x, 0.35, 0.0),
			Vector3(3.4, 0.7, 3.4),
			dark,
			Vector3.ZERO,
			true
		)
		GEOMETRY.box(
			parent,
			"GateBody_%s" % str(sign_x),
			Vector3(x, 3.4, 0.0),
			Vector3(2.7, 5.4, 2.7),
			ceramic,
			Vector3.ZERO,
			true
		)
		GEOMETRY.box(
			parent,
			"GateShoulder_%s" % str(sign_x),
			Vector3(x, 6.4, 0.0),
			Vector3(3.1, 0.9, 3.1),
			silver
		)
		GEOMETRY.box(
			parent,
			"GateSlot_%s" % str(sign_x),
			Vector3(x + sign_x * 1.36, 3.5, 0.0),
			Vector3(0.07, 4.4, 0.34),
			glow
		)
		# Ribs across the face: manufactured armour, not a plastic column.
		for rib in range(5):
			GEOMETRY.box(
				parent,
				"GateRib_%s_%d" % [str(sign_x), rib],
				Vector3(x, 1.3 + float(rib) * 1.05, 1.38),
				Vector3(2.3, 0.12, 0.1),
				blue
			)

	# Header beam with an identification plate and two lamps under it.
	GEOMETRY.box(
		parent,
		"GateHeader",
		Vector3(0.0, 7.35, 0.0),
		Vector3(half_span * 2.0 + 1.6, 1.1, 1.5),
		ceramic
	)
	GEOMETRY.box(
		parent,
		"GateHeaderTrim",
		Vector3(0.0, 7.95, 0.0),
		Vector3(half_span * 2.0 + 1.9, 0.16, 1.7),
		silver
	)
	GEOMETRY.box(parent, "IdPlate", Vector3(0.0, 7.3, 0.78), Vector3(4.2, 0.62, 0.08), blue)
	GEOMETRY.box(parent, "IdPlateGlow", Vector3(0.0, 7.3, 0.83), Vector3(3.0, 0.1, 0.03), glow)
	for sign_x in [-1.0, 1.0]:
		GEOMETRY.cylinder(
			parent,
			"HeaderLamp_%s" % str(sign_x),
			Vector3(sign_x * 3.2, 6.72, 0.55),
			0.16,
			0.16,
			0.12,
			glow,
			Vector3(90.0, 0.0, 0.0)
		)

	# Blast door, half open. The leaves are offset so the gap is where the player
	# walks, and the deck threshold is lit on both sides of it.
	var door_gap := 3.1
	for sign_x in [-1.0, 1.0]:
		GEOMETRY.box(
			parent,
			"BlastDoor_%s" % str(sign_x),
			Vector3(sign_x * (door_gap + 2.0), 3.1, 0.0),
			Vector3(3.6, 5.6, 0.5),
			blue
		)
		for stripe in range(3):
			GEOMETRY.box(
				parent,
				"DoorStripe_%s_%d" % [str(sign_x), stripe],
				Vector3(sign_x * (door_gap + 2.0), 1.2 + float(stripe) * 1.6, 0.28),
				Vector3(3.2, 0.12, 0.04),
				dark
			)
	GEOMETRY.box(
		parent, "Threshold", Vector3(0.0, 0.04, 0.0), Vector3(door_gap * 2.0 + 0.4, 0.08, 4.4), dark
	)
	for sign_x in [-1.0, 1.0]:
		GEOMETRY.box(
			parent,
			"ThresholdGlow_%s" % str(sign_x),
			Vector3(sign_x * (door_gap - 0.2), 0.09, 0.0),
			Vector3(0.12, 0.02, 4.2),
			glow
		)

	if damage_state >= 1:
		# The gate took the hit that started the fall: one shoulder is sheared and
		# the debris is at its foot, not somewhere else in the arena. Which side
		# depends on the seed, so two gates in one world do not fail identically.
		var hit_side := -1.0 if seed % 2 == 0 else 1.0
		GEOMETRY.box(
			parent,
			"ShearedShoulder",
			Vector3(hit_side * (half_span + 1.2), 4.6, 1.4),
			Vector3(2.2, 0.5, 2.4),
			ceramic,
			Vector3(12.0, 26.0, -18.0)
		)


## A run of energy conduit: two charged pipes on trestles.
##
## `damage_state` 2 breaks the run at its far end and leaves the two open ends
## arcing, which is the visual link to whatever the conduit was feeding.
static func build_conduit_run(
	parent: Node3D, materials: Dictionary, damage_state: int, seed: int
) -> void:
	var silver: Material = materials["silver"]
	var dark: Material = materials["dark_trim"]
	var core: Material = materials["cyan"] if damage_state < 2 else materials["reactor_coils"]
	var length := 12.0
	# The break sits somewhere in the last third of the run; a row of conduits all
	# snapping at the same metre reads as a pattern instead of as damage.
	var broken_at := 6.4 + float(seed % 3) * 0.9

	for sign_z in [-1.0, 1.0]:
		var z: float = sign_z * 0.62
		var pipe_length := length if damage_state < 2 else broken_at
		var centre_x := pipe_length * 0.5 - length * 0.5
		GEOMETRY.cylinder(
			parent,
			"ConduitPipe_%s" % str(sign_z),
			Vector3(centre_x, 1.15, z),
			0.34,
			0.34,
			pipe_length,
			silver,
			Vector3(0.0, 0.0, 90.0),
			16
		)
		# The charged core line only shows where the run is intact.
		GEOMETRY.box(
			parent,
			"ConduitCore_%s" % str(sign_z),
			Vector3(centre_x, 1.52, z),
			Vector3(pipe_length - 0.4, 0.06, 0.1),
			core
		)
		if damage_state >= 2:
			# Snapped end: a short pipe leaning down into the dust, and a glow at
			# the break so the player can see where the feed died.
			GEOMETRY.cylinder(
				parent,
				"ConduitStub_%s" % str(sign_z),
				Vector3(broken_at - 0.9, 0.72, z),
				0.3,
				0.34,
				1.7,
				silver,
				Vector3(0.0, 0.0, 66.0),
				16
			)
			GEOMETRY.sphere(
				parent,
				"ArcNode_%s" % str(sign_z),
				Vector3(broken_at - 0.05, 1.18, z),
				Vector3(0.16, 0.16, 0.16),
				materials["red"]
			)

	# Trestles: the pipe has to be held up by something, at a believable interval.
	var trestles := 4 if damage_state < 2 else 3
	for index in range(trestles):
		var x := -length * 0.5 + float(index) * 3.4
		GEOMETRY.box(
			parent,
			"Trestle_%d" % index,
			Vector3(x, 0.5, 0.0),
			Vector3(0.28, 1.0, 1.9),
			dark,
			Vector3.ZERO,
			index == 0
		)
		GEOMETRY.box(
			parent, "TrestleCap_%d" % index, Vector3(x, 1.05, 0.0), Vector3(0.4, 0.12, 2.1), silver
		)


## Fallen structure, classed by what it came from.
##
## This is the family the brief is strict about: not generic rocks. Each piece
## is a slab, a brace or a rail from the wall and gate grammar above, so a
## debris field next to a breached wall reads as that wall.
static func build_structural_debris(
	parent: Node3D, materials: Dictionary, damage_state: int, seed: int
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var ceramic: Material = materials["ceramic"]
	var silver: Material = materials["silver"]
	var dark: Material = materials["dark_trim"]
	var pieces := 9 + damage_state * 4
	for index in range(pieces):
		var kind := index % 3
		var at := Vector3(rng.randf_range(-3.4, 3.4), 0.0, rng.randf_range(-3.4, 3.4))
		var yaw := rng.randf_range(0.0, 180.0)
		match kind:
			0:
				# Armour slab, lying where it fell.
				GEOMETRY.box(
					parent,
					"DebrisSlab_%d" % index,
					at + Vector3(0.0, 0.12, 0.0),
					Vector3(rng.randf_range(1.1, 2.2), 0.18, rng.randf_range(0.7, 1.2)),
					ceramic,
					Vector3(rng.randf_range(-6.0, 6.0), yaw, rng.randf_range(-4.0, 4.0)),
					index < 2
				)
			1:
				# Bent length of brace steel, propped up at an angle.
				GEOMETRY.box(
					parent,
					"DebrisBrace_%d" % index,
					at + Vector3(0.0, 0.45, 0.0),
					Vector3(rng.randf_range(1.4, 2.6), 0.16, 0.16),
					silver,
					Vector3(rng.randf_range(30.0, 70.0), yaw, rng.randf_range(-10.0, 10.0))
				)
			_:
				# Chunk of the plinth or the trim rail, dark and dense.
				GEOMETRY.box(
					parent,
					"DebrisChunk_%d" % index,
					at + Vector3(0.0, 0.2, 0.0),
					Vector3(
						rng.randf_range(0.4, 1.0),
						rng.randf_range(0.3, 0.7),
						rng.randf_range(0.4, 0.9)
					),
					dark,
					Vector3(0.0, yaw, 0.0)
				)


## Impact crater with a scorch plate and a rim of thrown deck.
##
## Built from flat cylinders rather than a decal so it works in the Compatibility
## renderer on the web target, and so the rim can catch the key light.
static func build_crater(
	parent: Node3D, materials: Dictionary, damage_state: int, seed: int
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var scorch: Material = materials["crater"]
	var rim: Material = materials["rock"]
	var radius := 1.9 + float(damage_state) * 0.9
	GEOMETRY.cylinder(
		parent,
		"CraterPlate",
		Vector3(0.0, 0.02, 0.0),
		radius,
		radius,
		0.04,
		scorch,
		Vector3.ZERO,
		24
	)
	GEOMETRY.cylinder(
		parent,
		"CraterCore",
		Vector3(0.0, 0.03, 0.0),
		radius * 0.55,
		radius * 0.55,
		0.05,
		materials["crater_core"],
		Vector3.ZERO,
		20
	)
	for index in range(10):
		var angle := TAU * float(index) / 10.0 + rng.randf_range(-0.12, 0.12)
		var distance := radius * rng.randf_range(0.92, 1.15)
		GEOMETRY.box(
			parent,
			"CraterRim_%d" % index,
			Vector3(cos(angle) * distance, 0.09, sin(angle) * distance),
			Vector3(
				rng.randf_range(0.5, 1.1), rng.randf_range(0.1, 0.26), rng.randf_range(0.3, 0.6)
			),
			rim,
			Vector3(rng.randf_range(-10.0, 10.0), rad_to_deg(angle), 0.0)
		)


## The distant megastructure: a command spire built at background detail.
##
## No collision, no interior, no small parts — it exists to give the horizon a
## scale the playable space cannot. It is a landmark, and the brief's ZONE E.
static func build_command_spire(
	parent: Node3D, materials: Dictionary, damage_state: int, seed: int
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var ceramic: Material = materials["ceramic"]
	var silver: Material = materials["silver"]
	var dark: Material = materials["dark_trim"]
	var glow: Material = materials["cyan"] if damage_state == 0 else materials["orange"]

	# Stacked, tapering masses — 96 m tall, so it clears everything on the deck.
	GEOMETRY.box(parent, "SpireRoot", Vector3(0.0, 6.0, 0.0), Vector3(30.0, 12.0, 30.0), dark)
	GEOMETRY.box(parent, "SpireBase", Vector3(0.0, 22.0, 0.0), Vector3(22.0, 22.0, 22.0), ceramic)
	GEOMETRY.box(parent, "SpireWaist", Vector3(0.0, 42.0, 0.0), Vector3(15.0, 20.0, 15.0), silver)
	GEOMETRY.box(parent, "SpireHead", Vector3(0.0, 60.0, 0.0), Vector3(11.0, 18.0, 11.0), ceramic)
	GEOMETRY.box(parent, "SpireCrown", Vector3(0.0, 74.0, 0.0), Vector3(6.0, 10.0, 6.0), silver)

	# Window bands. Two emissive boxes per tier instead of a texture: at 150 m
	# what reads is the band, not the windows in it.
	for tier in range(4):
		var y := 16.0 + float(tier) * 15.0
		var width := 22.0 - float(tier) * 4.6
		for sign_x in [-1.0, 1.0]:
			GEOMETRY.box(
				parent,
				"SpireBand_%d_%s" % [tier, str(sign_x)],
				Vector3(sign_x * width * 0.5, y, 0.0),
				Vector3(0.12, 0.5, width * 0.8),
				glow if tier % 2 == 0 else dark
			)

	# Antenna mast, and the navigation light that makes it a landmark at night.
	GEOMETRY.cylinder(
		parent, "SpireMast", Vector3(0.0, 88.0, 0.0), 0.6, 0.25, 18.0, silver, Vector3.ZERO, 8
	)
	GEOMETRY.sphere(
		parent,
		"SpireBeacon",
		Vector3(0.0, 97.5, 0.0),
		Vector3(0.5, 0.5, 0.5),
		materials["red"] if damage_state >= 1 else glow
	)

	# A collapsed bridge section tied to the spire: the structure that connected
	# it to the rest of the complex and no longer does.
	var deck_y := 34.0
	var span := 46.0
	GEOMETRY.box(
		parent,
		"BridgeSpan",
		Vector3(-span * 0.5 - 14.0, deck_y, 0.0),
		Vector3(span, 2.4, 8.0),
		ceramic,
		Vector3(0.0, 0.0, -4.0)
	)
	GEOMETRY.box(
		parent,
		"BridgeFallenEnd",
		Vector3(-span - 16.0, deck_y - 9.0, 4.0),
		Vector3(18.0, 2.2, 7.0),
		ceramic,
		Vector3(-14.0, 6.0, -26.0)
	)
	for index in range(5):
		GEOMETRY.box(
			parent,
			"BridgeRib_%d" % index,
			Vector3(-18.0 - float(index) * 8.0, deck_y - 1.6, rng.randf_range(-2.6, 2.6)),
			Vector3(0.5, 1.1, 8.0),
			dark
		)
