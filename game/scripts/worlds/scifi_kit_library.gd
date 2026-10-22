class_name ScifiKitLibrary
extends RefCounted

## The uploaded `3DScifiStarterKitFree.zip` pack, imported as GLB.
##
## `tools/convert_fbx_pack.py` runs on a GitHub runner (the archive is a Git LFS
## object that this machine cannot download) and commits the converted models.
## This class is the only place that knows their paths, their measured footprint
## and how far each one has to be lifted so it sits on the floor instead of
## floating or sinking.
##
## The pack ships **named materials with no texture links** (Orange, HD_Wall_02,
## Stuff_01, Glass, ...), so the look comes from a palette applied here rather
## than from the 4K texture set. That is also what keeps the committed models at
## 2.4 MB instead of a few hundred.

const ROOT := "res://assets/world/scifi_starter_kit/models/"
const DECK_TEXTURE: Texture2D = preload(
	"res://assets/world/scifi_starter_kit/materials/fbx_deck.png"
)
const CAUTION_TEXTURE: Texture2D = preload(
	"res://assets/world/scifi_starter_kit/materials/fbx_deck_caution.png"
)

## Models this level uses. Everything else stays on disk for future rounds.
const MODELS := {
	"floor": "Floor_Squared_01_6x6",
	"floor_alt": "Floor_Angle_01_6x6",
	"floor_grate": "Floor_Pipes_01",
	"wall": "Wall_Simple_01_Long",
	"wall_b": "Wall_Simple_02_Long",
	"wall_c": "Wall_Simple_03_Long",
	"wall_cube": "Wall_Cube_01_Long",
	"wall_low": "Wall_Cube_01_Flat",
	"doorway": "DoorWay_01_Large",
	"column": "Column_01_Big",
	"pillar": "Wall_Cube_01_Round",
	"crate": "Crate_01",
	"console": "Wall_Console_01_Half",
	"console_large": "Wall_Console_01_Large",
	"light_strip": "Light_SideLight_01",
	"light_corridor": "Light_Corridor_01",
	"pipes": "Pipes_03",
	"wall_pipes": "Wall_Pipes_01_Large",
	"fence": "Fence_Long_01",
	"sign_danger": "Sign_Danger_01",
	"word_zone": "Word_Zone",
	"beam": "Beam_01",
}

## Measured with `game/tests/_kit_probe.gd`: a model whose mesh starts below zero
## would otherwise sink into the floor, and one that starts above it would float.
const BASE_OFFSET := {
	"floor": 0.0,
	"floor_alt": 0.0,
	"floor_grate": 0.28,
	"wall": 0.0,
	"wall_b": 0.0,
	"wall_c": 0.0,
	"wall_cube": 0.0,
	"wall_low": 0.0,
	"doorway": 0.0,
	"column": 0.0,
	"pillar": 0.0,
	"crate": 0.0,
	"console": -0.74,
	"console_large": -0.74,
	"light_strip": 0.19,
	"light_corridor": 0.28,
	"pipes": 0.34,
	"wall_pipes": -1.34,
	"fence": 0.0,
	"sign_danger": 0.0,
	"word_zone": 0.0,
	"beam": 0.0,
}

## Footprint used for box colliders, in metres, before the placement scale.
const SIZE := {
	"floor": Vector3(6.0, 0.05, 6.0),
	"floor_alt": Vector3(6.0, 0.05, 6.0),
	"floor_grate": Vector3(1.5, 0.5, 5.0),
	"wall": Vector3(2.0, 4.0, 6.0),
	"wall_b": Vector3(2.0, 4.0, 6.0),
	"wall_c": Vector3(2.0, 4.0, 6.0),
	"wall_cube": Vector3(2.0, 4.0, 6.0),
	"wall_low": Vector3(2.0, 1.0, 6.0),
	"doorway": Vector3(5.0, 4.0, 1.0),
	"column": Vector3(4.0, 4.0, 0.5),
	"pillar": Vector3(2.0, 4.0, 2.0),
	"crate": Vector3(1.0, 0.75, 2.0),
	"console": Vector3(3.3, 2.8, 2.8),
	"console_large": Vector3(1.5, 2.8, 5.5),
	"light_strip": Vector3(0.9, 0.2, 0.1),
	"light_corridor": Vector3(1.0, 0.3, 3.5),
	"pipes": Vector3(1.7, 0.7, 4.0),
	"wall_pipes": Vector3(1.1, 1.6, 5.5),
	"fence": Vector3(0.25, 1.3, 5.0),
	"sign_danger": Vector3(0.02, 1.2, 2.4),
	"word_zone": Vector3(0.02, 1.2, 6.0),
	"beam": Vector3(0.25, 4.0, 4.4),
}

## Palette: cool dark plating contrasts with sparse warm route markers and
## cyan energy fixtures. Model-aware policy retains the user's FBX silhouettes.
## The world's palette, derived from the same tokens the UI is built from.
##
## This is the fix for the largest visual defect the audit found (docs/
## UX_AUDIT_2026-10-22.md 5.1): the menus were near-black cinematic and the
## arena was bright pastel, because the world kept a private palette that had
## never been compared with `AegisTokens`.
##
## The values below are `AegisTokens.LINE / ACCENT / INFO` darkened by the
## amount written next to each one. They are literals only because GDScript
## constant expressions cannot call `Color.darkened()`; `palette_drift()`
## recomputes the derivation from the tokens and returns every key that no
## longer matches, and `world_palette_smoke.gd` fails if it returns anything.
## That is the part that keeps this honest -- editing a token cannot silently
## leave the world behind, which is how the two palettes drifted apart before.
##
## Albedo here is much darker than the UI's on purpose: these surfaces fill the
## whole screen at close range under a lit sky, while a UI panel is seen as a
## flat rectangle lit by nothing.
const COLORS := {
	# ACCENT.darkened(0.18) -- hazard paint; only ever a stripe, never a wall.
	"hazard": Color(0.82, 0.56596, 0.10290),
	# LINE.darkened(0.22) -- the world's structural metal.
	"steel": Color(0.11929, 0.17130, 0.22635),
	# LINE.darkened(0.02) -- machined edges and grates, the lightest structure.
	"steel_light": Color(0.14988, 0.21522, 0.28440),
	# LINE.darkened(0.42) -- recessed panels and crates.
	"panel": Color(0.08870, 0.12737, 0.16832),
	# LINE.darkened(0.62) -- the darkest structural trim, door frames.
	"trim": Color(0.05812, 0.08345, 0.11028),
	# LINE.darkened(0.34) -- deck plates (tinted over the panel texture).
	"floor": Color(0.10094, 0.14494, 0.19153),
	# LINE.darkened(0.46) -- the alternate deck plate.
	"floor_alt": Color(0.08259, 0.11859, 0.15671),
	# INFO.darkened(0.24) -- reactor and window glass.
	"glass": Color(0.25035, 0.59608, 0.76000),
	# INFO, undarkened -- every emissive strip. The only saturated hue that is
	# allowed to be bright, because it is the light source in the composition.
	"light": Color(0.32941, 0.78431, 1.00000),
}

## The derivation, in one place, for `palette_drift()`. Keys map to
## [token colour, darken amount]; the smoke test recomputes and compares.
const COLOR_DERIVATION := {
	"hazard": ["ACCENT", 0.18],
	"steel": ["LINE", 0.22],
	"steel_light": ["LINE", 0.02],
	"panel": ["LINE", 0.42],
	"trim": ["LINE", 0.62],
	"floor": ["LINE", 0.34],
	"floor_alt": ["LINE", 0.46],
	"glass": ["INFO", 0.24],
	"light": ["INFO", 0.0],
}

## Per-model policy, because the pack's material names are not reliable on their
## own: every floor tile, wall and crate shares a material literally named
## "Orange". Mapping that name straight to orange painted the whole arena orange,
## so the *model* decides what its "Orange" surface means.
## Colours on a wall follow the audit's composition rule rather than the model's
## material names: structure is steel, the pack's "Orange" surface is the trim
## band, and the only thing painted hazard amber is the crate/sign family. In
## the shipped build every wall surface was orange, which made the arena's
## perimeter the brightest thing on screen and pulled the eye away from the
## reactor -- the landmark the world is built around.
##
## The band is `trim`, not `hazard`, and that is load-bearing: painting the
## "Orange" surface of every wall amber is exactly the defect above with a
## narrower brush, since that surface covers most of the wall's face.
## `world_palette_smoke.gd` fails if any `wall*` policy names hazard, so the
## rule cannot quietly come back when someone re-tints a room.
const POLICY := {
	"floor": {"all": "floor"},
	"floor_alt": {"all": "floor_alt"},
	"floor_grate": {"all": "steel_light"},
	"wall": {"Orange": "trim", "all": "steel"},
	"wall_b": {"Orange": "trim", "all": "steel"},
	"wall_c": {"Orange": "trim", "all": "steel"},
	"wall_cube": {"Orange": "trim", "all": "steel"},
	"wall_low": {"Orange": "trim", "all": "panel"},
	"doorway": {"Orange": "trim", "all": "trim"},
	"column": {"all": "steel"},
	"pillar": {"all": "steel"},
	"crate": {"Orange": "hazard", "all": "panel"},
	"console": {"Orange": "light", "all": "panel"},
	"console_large": {"Orange": "light", "all": "panel"},
	"light_strip": {"all": "light"},
	"light_corridor": {"all": "light"},
	"pipes": {"all": "steel_light"},
	"wall_pipes": {"all": "steel"},
	"fence": {"all": "steel"},
	"sign_danger": {"all": "hazard"},
	"word_zone": {"all": "light"},
	"beam": {"all": "steel"},
}

## Modules the station world uses beyond the bay's own set.
##
## One entry per model: the file name, the measured bounding-box **size** and the
## measured **minimum corner**. Everything else is derived — the vertical base
## offset is `-min.y`, exactly as the hand-measured `BASE_OFFSET` table above, and
## the composer centres a module on its footprint from `min + size / 2`.
##
## Measured by reading the POSITION accessors out of each committed GLB, not by
## eye (`tools/kit_measure.py`). The pack authors several modules off-origin —
## `Wall_Console_01_Half` starts 1.76 m to its own left and 0.74 m up — and the
## first bay placed them by hand, so consoles hovered and walls sat a metre out of
## line with their colliders. Measuring removes the guess.
const EXTRA := {
	"floor_b": ["Floor_Squared_02_6x6", Vector3(6, 0.75, 6), Vector3(-3, -0.75, -3)],
	"floor_strip": ["Floor_Third_01_Strip_2x6", Vector3(3.975, 0, 6), Vector3(0, 0, -3)],
	"floor_tech": ["Floor_Pipes_01", Vector3(1.48, 0.475, 5.002), Vector3(2.299, -0.277, 0.499)],
	"floor_hole": ["Floor_Hole_01", Vector3(6, 1, 12), Vector3(-3, -1, -9)],
	"floor_coin": ["Floor_Coin_01_Small", Vector3(2, 0, 2), Vector3(0, 0, 0)],
	"wall_d": ["Wall_Simple_04_Long", Vector3(2.718, 5.147, 8.651), Vector3(-2.0, -1.147, -0.0)],
	"wall_e": ["Wall_Simple_05_Long", Vector3(2.384, 4.0, 6.0), Vector3(-2.0, -0.0, -0.0)],
	"wall_half": ["Wall_Simple_01_Half", Vector3(2.0, 4.0, 4.0), Vector3(-2.0, -0.0, -0.0)],
	"wall_coin": ["Wall_Simple_01_Coin", Vector3(2.0, 4.0, 2.0), Vector3(-2.0, -0.0, -0.0)],
	"wall_round": ["Wall_Cube_01_Round", Vector3(2.0, 4.0, 2.0), Vector3(-0.0, -0.0, -0.0)],
	"wall_thin": ["Wall_Cube_01_Thin", Vector3(2.0, 4.0, 2.0), Vector3(0, -0.0, -0.0)],
	"wall_flat": ["Wall_Cube_02_Flat", Vector3(2.003, 1.0, 4.0), Vector3(0.0, -0.0, -0.0)],
	"wall_inclined": ["Wall_Inclined_01_Long", Vector3(4.0, 4.0, 6.0), Vector3(-4.0, -0.0, -0.0)],
	"wall_broken":
	["Wall_Inclined_02_Long", Vector3(4.0, 4.984, 8.456), Vector3(-2.0, -0.984, -2.456)],
	"wall_up": ["Wall_Up_01_Long", Vector3(2.0, 4.0, 6.0), Vector3(-2.0, -0.0, -0.0)],
	"wall_down": ["Wall_Down_01_Long", Vector3(2.0, 4.0, 6.0), Vector3(-2.0, -0.0, -0.0)],
	"wall_pipes": ["Wall_Pipes_02_Large", Vector3(1.178, 1.57, 5.496), Vector3(0.322, 2.22, 0.254)],
	"console_half":
	["Wall_Console_01_Half", Vector3(3.259, 2.77, 2.745), Vector3(-1.759, 0.74, 0.255)],
	"console_large":
	["Wall_Console_01_Large", Vector3(1.47, 2.77, 5.495), Vector3(-1.97, 0.74, 0.255)],
	"gear": ["Wall_Gear_01_Half", Vector3(1.689, 4.525, 4.109), Vector3(-0.189, -1.016, -1.11)],
	"table": ["Wall_Table_01", Vector3(2.872, 1.352, 3.004), Vector3(-0.773, -0.0, -1.5)],
	"bed": ["Wall_Bed_01", Vector3(2.414, 0.577, 5.498), Vector3(-1.0, 0.74, 0.252)],
	"doorway_large": ["DoorWay_01_Large", Vector3(5.0, 4.0, 1.0), Vector3(-5.5, -0.0, -0.5)],
	"door_left": ["Door_Left_01", Vector3(3.569, 1.045, 3.94), Vector3(-3.694, 22.025, -2.015)],
	"door_right": ["Door_Right_01", Vector3(5.916, 1.058, 3.94), Vector3(-2.471, 22.011, -2.015)],
	"door_vert": ["Door_Vert_01", Vector3(0.822, 3.364, 5.127), Vector3(-1.036, -0.0, 0.439)],
	"roof": ["Roof_Squared_01_6x6", Vector3(6, 0.5, 6), Vector3(-3, -0.5, -3)],
	"roof_alt": ["Roof_Squared_02_6x6", Vector3(6, 0, 6), Vector3(-3, 0, -3)],
	"roof_glass": ["Roof_Glass_01_6x6", Vector3(1.904, 6.001, 6.0), Vector3(0.0, -2.001, -0.0)],
	"roof_angle": ["Roof_Angle_01_6x6", Vector3(6.0, 0.502, 6.0), Vector3(-1.13, -0.293, -4.876)],
	"crate": ["Crate_01", Vector3(1.0, 0.75, 2), Vector3(-0.5, 0, -1)],
	"column": ["Column_01_Big", Vector3(4.0, 4.0, 0.5), Vector3(-4.5, 0, -0.25)],
	"pipes_a": ["Pipes_01", Vector3(1.11, 0.99, 5.178), Vector3(0.322, 2.238, 0.415)],
	"pipes_b": ["Pipes_02", Vector3(0.548, 1.455, 4.0), Vector3(0.428, 1.34, 1.103)],
	"pipes_c": ["Pipes_03", Vector3(1.669, 0.707, 4.0), Vector3(2.173, -0.341, 0.419)],
	"beam": ["Beam_01", Vector3(0.25, 4.0, 4.423), Vector3(-0.125, -0.0, -2.211)],
	"beam_b": ["Beam_02", Vector3(2.412, 4.0, 2.26), Vector3(-0.201, -0.0, -2.135)],
	"fence": ["Fence_Long_01", Vector3(0.25, 1.304, 5.0), Vector3(2.5, 0.0, -8.5)],
	"fence_short": ["Fence_Short_01", Vector3(0.25, 1.304, 2.5), Vector3(2.5, 0.0, -9)],
	"fence_corner":
	["Fence_Turn_90_Large_01", Vector3(3.125, 1.304, 3.125), Vector3(3.736, 0.0, -8.375)],
	"grid": ["Grid_01", Vector3(0.128, 3.251, 2.0), Vector3(-0.064, -0.0, -1.0)],
	"air_grid": ["Air_Grid_01", Vector3(0.144, 0.849, 1.188), Vector3(-0.143, -0.37, -0.594)],
	"airing": ["Airing_01", Vector3(8.5, 1.5, 8.5), Vector3(-4.25, -1.5, -4.25)],
	"intercom": ["Intercom_01", Vector3(0.069, 0.746, 0.5), Vector3(-0.069, -0.373, -0.25)],
	"intercom_b": ["Intercom_02", Vector3(0.069, 0.398, 0.5), Vector3(-0.069, -0.199, -0.25)],
	"light_strip":
	["Light_SideLight_01", Vector3(0.89, 0.195, 0.09), Vector3(-0.445, -0.194, 1.75)],
	"light_corridor": ["Light_Corridor_01", Vector3(1.0, 0.281, 3.5), Vector3(-0.5, -0.28, -1.75)],
	"porthole": ["Porthole_01_Long", Vector3(3.654, 4.0, 6.0), Vector3(-1.75, -0.0, -0.0)],
	"sign_caution": ["Sign_Caution_01", Vector3(0.0, 3.995, 8.563), Vector3(-0.0, -1.998, -4.281)],
	"sign_danger": ["Sign_Danger_01", Vector3(0.0, 4.323, 8.563), Vector3(-0.0, -2.162, -4.281)],
	"word_zone": ["Word_Zone", Vector3(0.0, 3.995, 21.947), Vector3(-0.0, -1.998, -10.973)],
	"word_warning": ["Word_Warning", Vector3(0.0, 3.995, 37.094), Vector3(-0.0, -1.998, -18.547)],
	"word_exit": ["Word_Exit", Vector3(0.0, 3.995, 18.256), Vector3(-0.0, -1.998, -9.128)],
	"arrow": ["Symb_Arrow", Vector3(3.995, 0, 3.995), Vector3(-1.998, 0, -1.998)],
	"num_0": ["Num_0", Vector3(0.0, 3.995, 5.387), Vector3(-0.0, -1.998, -2.694)],
	"num_7": ["Num_7", Vector3(0.0, 3.995, 5.387), Vector3(-0.0, -1.998, -2.694)],
	"platform": ["Stairway_Plateform_01", Vector3(6.0, 1.449, 6), Vector3(-3.125, -0.21, -9)],
	"platform_flat": ["Stairway_Plateform_00", Vector3(6.0, 0.145, 6), Vector3(-3.125, -0.21, -9)],
	"stairs": ["Stairway_Slope_45_01", Vector3(6.0, 5.385, 6), Vector3(-3.125, -4.145, -9)],
	"step": ["Stairway_Step_01", Vector3(7.195, 4.21, 15), Vector3(-3.125, -0.21, -9)],
}

## Palette policy for the modules above, keyed the same way as `POLICY`.
## Structure stays steel, the pack's "Orange" surface stays trim, and only the
## fixture families (light, decal, hazard sign) are allowed to be bright.
const POLICY_EXTRA := {
	"floor_b": {"all": "floor_alt"},
	"floor_strip": {"all": "hazard"},
	"floor_tech": {"all": "steel_light"},
	"floor_hole": {"all": "steel_light"},
	"floor_coin": {"all": "hazard"},
	"wall_d": {"Orange": "trim", "all": "steel"},
	"wall_e": {"Orange": "trim", "all": "steel"},
	"wall_half": {"Orange": "trim", "all": "steel"},
	"wall_coin": {"Orange": "trim", "all": "steel"},
	"wall_round": {"Orange": "trim", "all": "steel"},
	"wall_thin": {"Orange": "trim", "all": "steel"},
	"wall_flat": {"Orange": "trim", "all": "panel"},
	"wall_inclined": {"Orange": "trim", "all": "steel"},
	"wall_broken": {"Orange": "trim", "all": "panel"},
	"wall_up": {"Orange": "trim", "all": "steel"},
	"wall_down": {"Orange": "trim", "all": "steel"},
	"wall_pipes": {"all": "steel"},
	"console_half": {"Orange": "light", "all": "panel"},
	"console_large": {"Orange": "light", "all": "panel"},
	"gear": {"Orange": "trim", "all": "steel"},
	"table": {"all": "panel"},
	"bed": {"all": "panel"},
	"doorway_large": {"Orange": "trim", "all": "trim"},
	"door_vert": {"all": "trim"},
	"roof": {"all": "steel"},
	"roof_alt": {"all": "panel"},
	"roof_glass": {"all": "glass"},
	"roof_angle": {"all": "steel"},
	"crate": {"Orange": "hazard", "all": "panel"},
	"column": {"all": "steel"},
	"pipes_a": {"all": "steel_light"},
	"pipes_b": {"all": "steel_light"},
	"pipes_c": {"all": "steel_light"},
	"beam": {"all": "steel"},
	"beam_b": {"all": "steel"},
	"fence": {"all": "steel_light"},
	"fence_short": {"all": "steel_light"},
	"fence_corner": {"all": "steel_light"},
	"grid": {"all": "steel_light"},
	"air_grid": {"all": "steel"},
	"airing": {"all": "steel"},
	"intercom": {"Orange": "light", "all": "panel"},
	"intercom_b": {"Orange": "light", "all": "panel"},
	"light_strip": {"all": "light"},
	"light_corridor": {"all": "light"},
	"porthole": {"all": "glass"},
	"sign_caution": {"all": "hazard"},
	"sign_danger": {"all": "hazard"},
	"word_zone": {"all": "light"},
	"word_warning": {"all": "light"},
	"word_exit": {"all": "light"},
	"arrow": {"all": "light"},
	"num_0": {"all": "light"},
	"num_7": {"all": "light"},
	"platform": {"all": "steel_light"},
	"platform_flat": {"all": "steel_light"},
	"stairs": {"all": "steel"},
	"step": {"all": "steel"},
}

const DEFAULT_MATERIAL_KEYS := {
	"orange": "hazard",
	"glass": "glass",
	"light": "light",
	"hd_wall": "steel",
	"stuff": "panel",
	"alpha": "trim",
	"wall": "trim",
	"floor": "floor",
	"toto": "floor",
}

## A class reference in GDScript is a `GDScript` resource, not an instance, so
## `AegisTokens.get("LINE")` would ask the resource object and return null.
## Static access by name, resolved at compile time, is the only reliable way to
## read a constant from another class.
static var _scenes: Dictionary = {}
static var _materials: Dictionary = {}

## A class reference in GDScript is a `GDScript` resource, not an instance, so
## `AegisTokens.get("LINE")` would ask the resource object and return null.
## Static access by name, resolved at compile time, is the only reliable way to
## read a constant from another class.
static var _scenes: Dictionary = {}


static func token_color(token_name: String) -> Color:
	match token_name:
		"ACCENT":
			return AegisTokens.ACCENT
		"LINE":
			return AegisTokens.LINE
		"INFO":
			return AegisTokens.INFO
		"VOID":
			return AegisTokens.VOID
		"OK":
			return AegisTokens.OK
		"DANGER":
			return AegisTokens.DANGER
	push_error("ScifiKitLibrary: unknown design token '%s'" % token_name)
	return Color.MAGENTA


## Recomputes the palette from `AegisTokens` and returns the keys that no
## longer match `COLORS`. Empty means the world and the UI are still one
## palette; an entry means someone changed a token and did not carry the world
## with it.
static func palette_drift() -> Array[String]:
	var drifted: Array[String] = []
	for key in COLOR_DERIVATION:
		var spec: Array = COLOR_DERIVATION[key]
		var expected := token_color(spec[0]).darkened(float(spec[1]))
		var actual: Color = COLORS[key]
		if not expected.is_equal_approx(actual):
			drifted.append("%s: world %s vs token %s" % [key, actual, expected])
	return drifted


static func color_key_for(material_name: String) -> String:
	var lower := material_name.to_lower()
	for prefix in DEFAULT_MATERIAL_KEYS:
		if lower.begins_with(prefix):
			return DEFAULT_MATERIAL_KEYS[prefix]
	return "steel"


static func model(key: String) -> PackedScene:
	if _scenes.has(key):
		return _scenes[key]
	var file := _file_for(key)
	if file == "":
		push_error("ScifiKitLibrary has no model registered for '%s'" % key)
		return null
	var scene: PackedScene = load(ROOT + file + ".glb")
	_scenes[key] = scene
	return scene


## The file name behind a key, from either table.
static func _file_for(key: String) -> String:
	if MODELS.has(key):
		return String(MODELS[key])
	if EXTRA.has(key):
		return String(EXTRA[key][0])
	return ""


## The measured minimum corner of a module, in its own space. Keys from the bay's
## original table return zero, which is what its hand-measured offsets assume.
static func min_corner(key: String) -> Vector3:
	if EXTRA.has(key):
		return Vector3(EXTRA[key][2])
	return Vector3.ZERO


static func base_offset(key: String) -> float:
	if BASE_OFFSET.has(key):
		return float(BASE_OFFSET[key])
	return -min_corner(key).y


static func size(key: String) -> Vector3:
	if SIZE.has(key):
		return Vector3(SIZE[key])
	if EXTRA.has(key):
		return Vector3(EXTRA[key][1])
	return Vector3.ONE


## One shared material per palette colour: the imported GLB materials are all
## plain white, so without this every surface in the bay renders the same.
static func material(color_key: String) -> StandardMaterial3D:
	if _materials.has(color_key):
		return _materials[color_key]
	var material := StandardMaterial3D.new()
	material.resource_name = "SciFi_" + color_key
	match color_key:
		"glass":
			material.albedo_color = Color(COLORS.glass, 0.24)
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.metallic = 0.1
			material.roughness = 0.08
			material.emission_enabled = true
			material.emission = COLORS.glass
			material.emission_energy_multiplier = 0.35
		"light":
			material.albedo_color = COLORS.light
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.emission_enabled = true
			material.emission = COLORS.light
			material.emission_energy_multiplier = 0.95
		"orange", "hazard":
			material.albedo_color = COLORS.hazard
			material.metallic = 0.05
			material.roughness = 0.55
		"floor", "floor_alt":
			# Both original FBX floor meshes have UVs but lost texture links on
			# export. Apply a restrained manufactured-panel map on those same
			# imported surfaces, not a substitute floor mesh or glowing decal.
			#
			# The map is a light blue-grey, and rendering it untinted (albedo
			# WHITE) made it the brightest surface in the game -- the arena read
			# as graph paper and the cinematic key art's deep navy had no
			# counterpart in play. The tint is the palette colour, so the deck
			# darkens with everything else while keeping its panel detail.
			material.albedo_color = COLORS[color_key].lightened(0.34)
			material.albedo_texture = (DECK_TEXTURE if color_key == "floor" else CAUTION_TEXTURE)
			material.metallic = 0.16
			material.roughness = 0.62
		_:
			material.albedo_color = COLORS.get(color_key, COLORS.steel)
			material.metallic = 0.06
			material.roughness = 0.62
	_materials[color_key] = material
	return material


## Resolves one surface's palette colour for one model, honouring the
## per-model policy first and the material-name fallback second.
static func surface_color_key(model_key: String, material_name: String) -> String:
	var policy: Dictionary = POLICY_EXTRA.get(model_key, POLICY.get(model_key, {}))
	if policy.has(material_name):
		return policy[material_name]
	if policy.has("all"):
		return policy["all"]
	return color_key_for(material_name)


## Replaces the blank imported materials surface by surface. Keeping the
## per-surface structure matters: a wall is plating plus an orange stripe, and a
## single material override would flatten it.
static func apply_palette(node: Node, model_key: String, emissive: bool = true) -> void:
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		var mesh := mesh_instance.mesh
		if mesh == null:
			continue
		for index in range(mesh.get_surface_count()):
			var source := mesh_instance.get_active_material(index)
			var material_name := ""
			if source != null:
				material_name = source.resource_name
			var key := surface_color_key(model_key, material_name)
			if key == "light" and not emissive:
				key = "steel_light"
			mesh_instance.set_surface_override_material(index, material(key))
