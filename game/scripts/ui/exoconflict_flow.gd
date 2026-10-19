class_name ExoconflictFlow
extends Node

## State machine untuk alur EXOCONFLICT: Stell Horizon
## BOOT -> LOADING -> CINEMATIC -> DASHBOARD -> HERO -> WEAPON -> WORLD -> LOADING_ASSET -> GAMEPLAY

enum Step { BOOT, LOADING, CINEMATIC, DASHBOARD, HERO_SELECT, WEAPON_SELECT, WORLD_SELECT, LOADING_ASSET, GAMEPLAY }

signal step_changed(new_step: Step)
signal selection_complete(hero_id: String, weapon_id: String, world_id: String)

var current_step: Step = Step.BOOT
var selected_hero: String = "nexus01"
var selected_weapon: String = "pulse_rifle"
var selected_world: String = "neon_frontier"
var world_options := ["neon_frontier", "crystal_caverns", "wrecked_sector"]

# --- hero/weapon definitions (1 unlock, 2 locked) ---
var hero_defs := [
	{
		"id": "nexus01",
		"name": "NEXUS-01",
		"class": "ASSAULT / BALANCED",
		"locked": false,
		"image": "res://assets/ui/exoconflict/images/hero_nexus01_card.png",
		"stats": {"damage": 75, "shield": 60, "speed": 80, "utility": 65},
		"desc": "Unit serbaguna dengan mobilitas tinggi. Cocok untuk pemula."
	},
	{
		"id": "fortress",
		"name": "FORTRESS",
		"class": "TANK / DEFENDER",
		"locked": true,
		"image": "res://assets/ui/exoconflict/images/hero_locked_variants.png",
		"stats": {"damage": 60, "shield": 95, "speed": 40, "utility": 50},
		"desc": "Perisai berat. Tahan lama di garis depan."
	},
	{
		"id": "vex",
		"name": "VEX",
		"class": "SCOUT / SNIPER",
		"locked": true,
		"image": "res://assets/ui/exoconflict/images/hero_locked_variants.png",
		"stats": {"damage": 90, "shield": 45, "speed": 95, "utility": 80},
		"desc": "Cepat dan mematikan dari jauh."
	},
]

var weapon_defs := [
	{
		"id": "pulse_rifle",
		"name": "PULSE RIFLE",
		"locked": false,
		"image": "res://assets/ui/exoconflict/images/weapon_pulse_rifle_card.png",
		"stats": {"dps": 82, "rate": 78, "mag": 24, "range": 70},
		"desc": "Senjata serbaguna, reload cepat."
	},
	{
		"id": "nova_launcher",
		"name": "NOVA LAUNCHER",
		"locked": true,
		"image": "res://assets/ui/exoconflict/images/weapon_locked_variants.png",
		"stats": {"dps": 95, "rate": 35, "mag": 6, "range": 85},
		"desc": "Ledakan area, lambat tapi mematikan."
	},
	{
		"id": "arc_shooter",
		"name": "ARC SHOOTER",
		"locked": true,
		"image": "res://assets/ui/exoconflict/images/weapon_locked_variants.png",
		"stats": {"dps": 70, "rate": 90, "mag": 30, "range": 55},
		"desc": "Rapid fire dengan chain damage."
	},
]

var world_defs := [
	{
		"id": "neon_frontier",
		"name": "NEON FRONTIER",
		"sub": "INDUSTRIAL ARENA",
		"locked": false,
		"image": "res://assets/ui/exoconflict/images/world_select_three.png",
		"stats": {"risk": 3, "reward": 3},
		"desc": "Reaktor hexagonal, musuh Runner/Shooter."
	},
	{
		"id": "crystal_caverns",
		"name": "CRYSTAL CAVERNS",
		"sub": "NATURAL WONDER",
		"locked": true,
		"image": "res://assets/ui/exoconflict/images/world_select_three.png",
		"stats": {"risk": 4, "reward": 4},
		"desc": "Crystal cliffs, jalur vertikal."
	},
	{
		"id": "wrecked_sector",
		"name": "WRECKED SECTOR",
		"sub": "STARSHIP GRAVEYARD",
		"locked": true,
		"image": "res://assets/ui/exoconflict/images/world_select_three.png",
		"stats": {"risk": 5, "reward": 5},
		"desc": "Wrecked transport, zero-g."
	},
]


func advance_to(step: Step) -> void:
	current_step = step
	step_changed.emit(step)
	print("ExoconflictFlow: -> %s" % Step.keys()[step])


func go_next() -> void:
	match current_step:
		Step.BOOT:
			advance_to(Step.LOADING)
		Step.LOADING:
			advance_to(Step.CINEMATIC)
		Step.CINEMATIC:
			advance_to(Step.DASHBOARD)
		Step.DASHBOARD:
			advance_to(Step.HERO_SELECT)
		Step.HERO_SELECT:
			advance_to(Step.WEAPON_SELECT)
		Step.WEAPON_SELECT:
			advance_to(Step.WORLD_SELECT)
		Step.WORLD_SELECT:
			advance_to(Step.LOADING_ASSET)
		Step.LOADING_ASSET:
			advance_to(Step.GAMEPLAY)
			selection_complete.emit(selected_hero, selected_weapon, selected_world)
		_:
			pass


func skip_cinematic() -> void:
	if current_step == Step.CINEMATIC:
		advance_to(Step.DASHBOARD)


func select_hero(id: String) -> bool:
	for h in hero_defs:
		if h["id"] == id and not h["locked"]:
			selected_hero = id
			return true
	return false


func select_weapon(id: String) -> bool:
	for w in weapon_defs:
		if w["id"] == id and not w["locked"]:
			selected_weapon = id
			return true
	return false


func select_world(id: String) -> bool:
	for w in world_defs:
		if w["id"] == id and not w["locked"]:
			selected_world = id
			return true
	return false
