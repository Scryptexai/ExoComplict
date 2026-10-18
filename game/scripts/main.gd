extends Node3D

enum SessionMode { EXPLORE, PREPARING, DEFENSE, RESULTS }

const PlayerControllerScript = preload("res://scripts/player/player_controller.gd")
const TrainingDroneScript = preload("res://scripts/enemies/training_drone.gd")
const WaveDirectorScript = preload("res://scripts/waves/wave_director.gd")
const TouchControlsScript = preload("res://scripts/ui/touch_controls.gd")
const RunStatsScript = preload("res://scripts/progression/run_stats.gd")
const RewardServiceScript = preload("res://scripts/progression/reward_service.gd")
const ProgressionServiceScript = preload("res://scripts/progression/progression_service.gd")

## Test/authoring override only. The shipped scene starts in safe Explore; the
## player must explicitly choose Defense before the WaveDirector can run.
@export var start_wave_session_on_ready: bool = false
@export_range(2.0, 10.0, 0.5) var defense_preparation_seconds: float = 5.0

var session_mode: SessionMode = SessionMode.EXPLORE
var _preparation_remaining: float = 0.0
var _retry_defense: bool = false
var _shots_fired: int = 0
var _is_paused: bool = false
var _base_look_sensitivity: float = 0.0

@onready var player: PlayerControllerScript = $Player
@onready var training_drone: TrainingDroneScript = $TrainingDrone
@onready var wave_director: WaveDirectorScript = $WaveDirector
@onready var run_stats: RunStatsScript = $RunStats
@onready var reward_service: RewardServiceScript = $RewardService
@onready var progression_service: ProgressionServiceScript = $ProgressionService
@onready var touch_controls: TouchControlsScript = $HUD/TouchControls


func _ready() -> void:
	touch_controls.movement_changed.connect(player.set_touch_movement)
	touch_controls.look_delta.connect(player.apply_touch_look)
	touch_controls.fire_changed.connect(player.set_touch_fire_pressed)
	touch_controls.aim_changed.connect(player.set_touch_aim_held)
	touch_controls.weapon_switch_requested.connect(_on_weapon_switch_requested)
	touch_controls.armory_requested.connect(_open_armory)
	touch_controls.armory_weapon_action_requested.connect(_on_armory_weapon_action)
	touch_controls.armory_close_requested.connect(_close_armory)
	touch_controls.skill_requested.connect(player.activate_skill)
	touch_controls.pause_requested.connect(_toggle_pause)
	touch_controls.sound_mute_requested.connect(_on_sound_mute_requested)
	_base_look_sensitivity = player.camera_rig.look_sensitivity
	if not FileAccess.file_exists(AegisPreferences.PATH):
		touch_controls._settings_menu.set_mute_from_game(Sfx.is_muted())
	touch_controls.settings_changed.connect(_on_settings_changed)
	touch_controls._apply_preferences(touch_controls._settings_menu.values)
	player.weapon_changed.connect(touch_controls.set_weapon_label)
	player.weapon_changed.connect(_on_weapon_equipped)
	player.weapon_controller.ammo_changed.connect(touch_controls._update_weapon_ammo)
	player.skill_cooldown_changed.connect(touch_controls.set_skill_cooldown)
	player.skill_used.connect(_on_skill_used)
	progression_service.profile_changed.connect(_on_profile_changed)
	_on_profile_changed()
	touch_controls._update_weapon_ammo(
		player.weapon_controller.get_current_ammo(),
		player.weapon_controller.get_current_magazine_size(),
		player.weapon_controller.is_reloading()
	)
	touch_controls.set_skill_cooldown(0.0, player.emp_pulse_cooldown)
	touch_controls.retry_requested.connect(_reset_session)
	touch_controls.defense_start_requested.connect(_request_defense)
	touch_controls.return_to_explore_requested.connect(_return_to_explore)
	touch_controls.finish_run_requested.connect(_finish_run)
	player.aim_changed.connect(touch_controls.set_aim_state)
	player.shot_fired.connect(_on_shot_fired)
	player.health_changed.connect(_on_combatant_health_changed)
	player.damage_received.connect(_on_player_damage_received)
	player.defeated.connect(_on_player_defeated)
	training_drone.health_changed.connect(_on_combatant_health_changed)
	training_drone.damage_received.connect(_on_target_damage_received)
	wave_director.progress_changed.connect(_update_status)
	run_stats.stats_changed.connect(_update_status)
	wave_director.wave_started.connect(_on_wave_started)
	wave_director.wave_completed.connect(_on_wave_completed)
	wave_director.wave_completed.connect(reward_service.award_wave_completion)
	reward_service.wave_rewarded.connect(_on_wave_rewarded)
	wave_director.enemy_spawned.connect(_on_wave_enemy_spawned)
	wave_director.enemy_defeated.connect(reward_service.award_enemy_defeat)
	wave_director.session_ended.connect(_on_wave_session_ended)
	wave_director.spawn_blocked.connect(_on_wave_spawn_blocked)
	touch_controls._set_play_phase("explore")
	_update_status()
	print("Encounter: Explore safe; activate Start Defense when ready")
	# One line per session so the browser console proves audio came up in the
	# exported build, not only in the editor.
	print(Sfx.describe())
	if start_wave_session_on_ready:
		# Explicit opt-in for automated fixtures; never enabled in main.tscn.
		_request_defense()


func _process(delta: float) -> void:
	touch_controls.set_aim_state(player.is_aiming())
	if session_mode == SessionMode.PREPARING:
		var before := ceili(_preparation_remaining)
		_preparation_remaining = maxf(_preparation_remaining - delta, 0.0)
		if _preparation_remaining <= 0.0:
			session_mode = SessionMode.DEFENSE
			touch_controls._set_play_phase("defense")
			print("Encounter: Defense started")
			wave_director.start_session()
		elif ceili(_preparation_remaining) != before:
			touch_controls._set_play_phase("preparing", ceili(_preparation_remaining))
	if Input.is_action_just_pressed("start_defense"):
		_request_defense()
	if Input.is_action_just_pressed("reset_session"):
		_reset_session()
	if Input.is_action_just_pressed("toggle_sound"):
		_on_sound_mute_requested()
	if Input.is_action_just_pressed("emp_pulse"):
		player.activate_skill()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if event is InputEventKey and event.echo:
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_toggle_pause()
	get_viewport().set_input_as_handled()


## Audio mute is owned here rather than in the HUD: the button and the M key go
## through the same path, and the label is updated from the real audio state
## instead of being flipped blindly.
func _on_sound_mute_requested() -> void:
	var muted := Sfx.toggle_muted()
	touch_controls.set_sound_muted(muted)
	touch_controls._settings_menu.set_mute_from_game(muted)
	Sfx.play_ui(&"ui_click")


func _on_settings_changed(values: Dictionary) -> void:
	player.camera_rig.look_sensitivity = _base_look_sensitivity * float(values["sensitivity"])
	player.camera_rig.set_reduced_motion(bool(values.get("reduce_motion", false)))
	var muted := bool(values["muted"])
	if Sfx.is_muted() != muted:
		Sfx.set_muted(muted)
	touch_controls.set_sound_muted(muted)


func _on_profile_changed() -> void:
	player.weapon_controller.set_available_weapon_ids(progression_service.unlocked_ids)
	HudArmoryBridge.refresh(
		touch_controls,
		progression_service.balance,
		progression_service.best_score,
		progression_service.unlocked_ids,
		player.weapon_controller.get_current_definition().weapon_id
	)
	touch_controls.set_weapon_label(player.get_current_weapon_name())


func _on_weapon_equipped(_display_name: String) -> void:
	_on_profile_changed()


func _on_weapon_switch_requested() -> void:
	if player.weapon_controller.available_weapon_count() > 1:
		player.select_next_weapon()
	else:
		_open_armory()


func _open_armory() -> void:
	if session_mode == SessionMode.RESULTS or player.is_defeated() or _is_paused:
		return
	_toggle_pause()
	HudArmoryBridge.show_panel(touch_controls)


func _close_armory() -> void:
	HudArmoryBridge.hide_panel(touch_controls)
	if _is_paused:
		_toggle_pause()


func _on_armory_weapon_action(weapon_id: StringName) -> void:
	var weapon_index := -1
	for index in range(player.weapon_controller.weapon_definitions.size()):
		if player.weapon_controller.weapon_definitions[index].weapon_id == weapon_id:
			weapon_index = index
			break
	if weapon_index < 0 or not touch_controls._armory_panel.visible:
		return
	var weapon_name := player.weapon_controller.weapon_definitions[weapon_index].display_name
	if progression_service.is_unlocked(weapon_id):
		player.select_weapon(weapon_index)
		touch_controls._armory_panel.show_hint(
			"%s EQUIPPED · READY TO PLAY" % weapon_name.to_upper()
		)
		return
	var missing := progression_service.unlock_cost(weapon_id) - progression_service.balance
	if missing > 0:
		touch_controls._armory_panel.show_hint("NEED %d MORE BP · FIGHT WAVES" % missing)
		return
	if progression_service.unlock_weapon(weapon_id):
		player.select_weapon(weapon_index)
		Sfx.play_ui(&"session_clear")
		touch_controls._armory_panel.show_hint("%s UNLOCKED & EQUIPPED" % weapon_name.to_upper())


func _toggle_pause() -> void:
	if player.is_defeated():
		_reset_session()
		return
	_is_paused = not _is_paused
	get_tree().paused = _is_paused
	touch_controls.set_paused(_is_paused)
	print("HUD: paused" if _is_paused else "HUD: resumed")


## Separate exploration from a survival encounter. Starting a run only enters
## preparation; no enemies may spawn before the player sees the countdown.
func _request_defense() -> void:
	if session_mode != SessionMode.EXPLORE or player.is_defeated() or _is_paused:
		return
	session_mode = SessionMode.PREPARING
	_preparation_remaining = defense_preparation_seconds
	touch_controls.hide_help()
	touch_controls._set_play_phase("preparing", ceili(_preparation_remaining))
	print("Encounter: Preparing Defense (%d s)" % ceili(_preparation_remaining))
	_update_status()


## Retry preserves the encounter intent; returning to Explore does not. Both
## routes clear remaining enemies and reset health/ammo before the HUD unlocks.
func _reset_session() -> void:
	var restart_defense := (
		session_mode == SessionMode.PREPARING
		or session_mode == SessionMode.DEFENSE
		or (session_mode == SessionMode.RESULTS and _retry_defense)
	)
	_return_to_explore()
	if restart_defense:
		_request_defense()


func _return_to_explore() -> void:
	_is_paused = false
	get_tree().paused = false
	_preparation_remaining = 0.0
	_retry_defense = false
	wave_director.reset_session()
	player.reset_player()
	training_drone.reset()
	_shots_fired = 0
	run_stats.reset_run()
	reward_service.reset_run()
	session_mode = SessionMode.EXPLORE
	touch_controls.hide_results()
	touch_controls.set_player_down(false)
	touch_controls.set_paused(false)
	touch_controls._set_play_phase("explore")
	_update_status()
	print("Encounter: Returned to Explore")


## Pause offers a deliberate cash-out path; a player need not die or leave
## their BP behind to see the outcome and choose another run.
func _finish_run() -> void:
	if session_mode != SessionMode.DEFENSE:
		return
	_is_paused = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	touch_controls.set_paused(false)
	wave_director.end_session()


func _on_shot_fired() -> void:
	_shots_fired += 1
	_update_status()


func _on_player_damage_received(_amount: float, _current: float, _maximum: float) -> void:
	touch_controls.show_damage_received()
	_update_status()


func _on_player_defeated() -> void:
	Sfx.play_ui(&"defeat")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	touch_controls.set_player_down(true)
	wave_director.end_session()
	_update_status()


func _on_target_damage_received(_amount: float, _current: float, _maximum: float) -> void:
	Sfx.play_ui(&"hit_confirm")
	touch_controls.show_hit_confirmed()


func _on_skill_used(targets_hit: int, _cooldown_seconds: float) -> void:
	Sfx.play_3d(&"skill_pulse", player.global_position)
	touch_controls.show_skill_feedback(targets_hit)


func _on_combatant_health_changed(_current: float, _maximum: float) -> void:
	_update_status()


func _on_wave_started(_wave_index: int, _enemy_count: int) -> void:
	# Also covers smoke fixtures that call WaveDirector.start_session() directly.
	session_mode = SessionMode.DEFENSE
	touch_controls._set_play_phase("defense")
	Sfx.play_ui(&"wave_start")
	run_stats.start_run()
	_update_status()


func _on_wave_completed(_wave_index: int) -> void:
	_update_status()


func _on_wave_rewarded(wave_index: int, bp_reward: int) -> void:
	# Only show the award once it was actually applied, not before the reward
	# service has checked its per-wave duplicate guard.
	touch_controls._feedback_panel.show_message(
		"WAVE %02d CLEAR · +%d BP" % [wave_index, bp_reward]
	)


func _on_wave_enemy_spawned(enemy: Node3D) -> void:
	if enemy.has_signal("damage_received"):
		enemy.connect("damage_received", _on_target_damage_received)


func _on_wave_session_ended(wave_index: int, _total_defeated: int) -> void:
	if session_mode != SessionMode.DEFENSE:
		return
	_retry_defense = true
	session_mode = SessionMode.RESULTS
	touch_controls._set_play_phase("results")
	if not player.is_defeated():
		Sfx.play_ui(&"session_clear")
	run_stats.end_run()
	var run_time := run_stats.get_survival_time_text()
	var run_kos := run_stats.eliminations
	var run_score := run_stats.run_score
	var run_bp := run_stats.bp_earned
	progression_service.bank_run(run_score, run_bp)
	(
		touch_controls
		. show_results(
			wave_index,
			run_time,
			run_kos,
			run_score,
			run_bp,
			progression_service.balance,
			progression_service.best_score,
		)
	)
	_update_status()
	print("Encounter: Results after wave %d" % wave_index)


func _on_wave_spawn_blocked(reason: String) -> void:
	push_warning("Defense could not spawn: " + reason)
	_return_to_explore()


func _update_status() -> void:
	var player_health := roundi(player.current_health)
	var player_maximum := roundi(player.max_health)
	var target_health := roundi(training_drone.current_health)
	var target_maximum := roundi(training_drone.max_health)
	var status := (
		"Score: %d · BP earned: %d\nKOs: %d · Time: %s\nTarget %d / %d · Shots %d"
		% [
			run_stats.run_score,
			run_stats.bp_earned,
			run_stats.eliminations,
			run_stats.get_survival_time_text(),
			target_health,
			target_maximum,
			_shots_fired,
		]
	)
	touch_controls.set_hud_health(player_health, player_maximum)
	var wave_number := wave_director.current_wave
	var active_enemies := wave_director.active_enemy_count
	var remaining_enemies := wave_director.enemies_remaining
	var wave_state := wave_director.get_state_label()
	(
		touch_controls
		. set_run_summary(
			run_stats.run_score,
			run_stats.bp_earned,
			run_stats.eliminations,
			run_stats.get_survival_time_text(),
			_shots_fired,
		)
	)
	touch_controls.set_wave_status(wave_number, active_enemies, remaining_enemies, wave_state)
	touch_controls.set_status(status)
