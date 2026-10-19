## The only owner of persistent Battle Points and weapon ownership. A run's
## BP is provisional in RunStats; Main banks it *once* at Results, then retries
## can reset the run without wiping the player's wallet. The weapon controller
## never writes saves or subtracts currency itself.
class_name ProgressionService
extends Node

signal profile_changed

const PROFILE_PATH := "user://progression.cfg"
const PROFILE_SECTION := "profile"
const COSTS := {"pulse_rifle": 0, "nova_launcher": 120, "arc_shooter": 250}
const MAX_VALUE := 99999999

## Empty for isolated smoke fixtures; the shipped scene uses PROFILE_PATH.
@export var profile_path: String = PROFILE_PATH

var balance: int = 0
var best_score: int = 0
var completed_runs: int = 0
var unlocked_ids: Dictionary = {"pulse_rifle": true}


func _ready() -> void:
	load_profile()


func load_profile() -> void:
	balance = 0
	best_score = 0
	completed_runs = 0
	unlocked_ids = {"pulse_rifle": true}
	if profile_path.is_empty():
		profile_changed.emit()
		return
	var config := ConfigFile.new()
	if config.load(profile_path) == OK:
		balance = _bounded_int(config.get_value(PROFILE_SECTION, "balance", 0))
		best_score = _bounded_int(config.get_value(PROFILE_SECTION, "best_score", 0))
		completed_runs = _bounded_int(config.get_value(PROFILE_SECTION, "completed_runs", 0))
		var saved_ids = config.get_value(PROFILE_SECTION, "unlocked_ids", [])
		if saved_ids is Array or saved_ids is PackedStringArray:
			for id in saved_ids:
				var key := str(id)
				if COSTS.has(key):
					unlocked_ids[key] = true
	profile_changed.emit()


func is_unlocked(weapon_id: StringName) -> bool:
	return unlocked_ids.has(String(weapon_id))


func unlock_cost(weapon_id: StringName) -> int:
	return int(COSTS.get(String(weapon_id), -1))


## An invalid/repeated purchase has no side effects, including on disk.
func unlock_weapon(weapon_id: StringName) -> bool:
	var cost := unlock_cost(weapon_id)
	if cost <= 0 or is_unlocked(weapon_id) or balance < cost:
		return false
	balance -= cost
	unlocked_ids[String(weapon_id)] = true
	_save_profile()
	profile_changed.emit()
	return true


## Only Main calls this on DEFENSE -> RESULTS. Neither returning to Explore nor
## pressing RETRY awards twice; a completed wave's 100 BP is already in bp.
func bank_run(run_score: int, earned_bp: int) -> void:
	balance = mini(balance + _bounded_int(earned_bp), MAX_VALUE)
	best_score = maxi(best_score, _bounded_int(run_score))
	completed_runs = mini(completed_runs + 1, MAX_VALUE)
	_save_profile()
	profile_changed.emit()


func _bounded_int(value: Variant) -> int:
	if value is int or value is float or value is String:
		return clampi(int(value), 0, MAX_VALUE)
	return 0


func _save_profile() -> void:
	if profile_path.is_empty():
		return
	var config := ConfigFile.new()
	config.set_value(PROFILE_SECTION, "balance", balance)
	config.set_value(PROFILE_SECTION, "best_score", best_score)
	config.set_value(PROFILE_SECTION, "completed_runs", completed_runs)
	config.set_value(PROFILE_SECTION, "unlocked_ids", unlocked_ids.keys())
	var result := config.save(profile_path)
	if result != OK:
		push_warning("Could not save Battle Points and unlocks: %s" % error_string(result))
