## MAIN DASHBOARD: the hub the player returns to between runs.
##
## Every number here comes from ProgressionService, which is the only owner of
## the persistent profile. There is no "profile level", no streak counter and no
## daily reward: the save file holds Battle Points, best score, completed runs,
## unlocks and the last loadout, so those five things are what the dashboard
## shows. Adding a sixth row would mean inventing data the game does not track.
##
## Every button does something:
##   DEPLOY       starts the loadout chain HERO -> WEAPON -> WORLD -> PRELOAD
##   ARMORY       the in-game shop widget, spending real BP for real unlocks
##   SETTINGS     the shared AegisSettingsMenu, which writes user://aegis.cfg
##   REPLAY INTRO clears intro_seen, which is how the cinematic can be seen
##                again without wiping a profile
extends MenuStage

var _balance: Label
var _best: Label
var _runs: Label
var _loadout: Label
var _armory: HudArmoryUi
var _settings: AegisSettingsMenu
var _armory_hint_owner: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(make_backdrop("res://assets/ui/dashboard_bg.jpg"))

	var scrim := ColorRect.new()
	scrim.color = Color(AegisTokens.VOID, 0.55)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	_margin = MarginContainer.new()
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_margin)

	var column := VBoxContainer.new()
	physical_separation(column, 18)
	_margin.add_child(column)

	var mark := TextureRect.new()
	mark.texture = try_texture("res://assets/ui/logo_wordmark.png")
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	physical_min_size(mark, 320.0, 80.0)
	column.add_child(mark)

	var stats := AegisPanel.new()
	stats.interactive = false
	stats.accent_side = "top"
	stats.accent_color = AegisTokens.INFO
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(stats)

	var stat_column := VBoxContainer.new()
	physical_separation(stat_column, 10)
	stats.add_child(stat_column)
	stat_column.add_child(make_label("PROFILE", "label", AegisTokens.INK_2))
	_balance = make_label("BATTLE POINTS  0", "mono_l", AegisTokens.ACCENT)
	stat_column.add_child(_balance)
	_best = make_label("BEST SCORE  0", "body", AegisTokens.INK)
	stat_column.add_child(_best)
	_runs = make_label("RUNS COMPLETED  0", "body", AegisTokens.INK)
	stat_column.add_child(_runs)
	_loadout = make_label("LOADOUT", "label_s", AegisTokens.INK_2)
	_loadout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stat_column.add_child(_loadout)

	# On a phone the canvas is ~3x taller than it is wide (1280x2770 at 390x844),
	# so a top-aligned column would leave two thirds of the screen empty and put
	# DEPLOY out of thumb reach. A spacer pushes the actions to the bottom and
	# DEPLOY sits last, closest to the edge the hand is already holding.
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)

	var actions := VBoxContainer.new()
	physical_separation(actions, 12)
	column.add_child(actions)

	var row := HBoxContainer.new()
	physical_separation(row, 12)
	actions.add_child(row)

	var armory := make_button("ARMORY", "round", "Unlock and equip weapons with Battle Points")
	armory.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	physical_min_size(armory, 0.0, 56.0)
	armory.pressed.connect(_on_armory_pressed)
	row.add_child(armory)

	var settings := make_button("SETTINGS", "round", "Audio, HUD and control preferences")
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	physical_min_size(settings, 0.0, 56.0)
	settings.pressed.connect(_on_settings_pressed)
	row.add_child(settings)

	var replay := make_button("REPLAY INTRO", "ghost", "Watch the opening cinematic again")
	physical_min_size(replay, 0.0, 56.0)
	replay.pressed.connect(_on_replay_pressed)
	actions.add_child(replay)

	var deploy := make_button("DEPLOY", "primary", "Choose your loadout and start a run")
	physical_min_size(deploy, 0.0, 60.0)
	deploy.pressed.connect(_on_deploy_pressed)
	actions.add_child(deploy)

	_armory = HudArmoryUi.new()
	_armory.name = "ArmoryPanel"
	_armory.visible = false
	_armory.weapon_action_requested.connect(_on_weapon_action)
	_armory.close_requested.connect(_on_armory_close)
	add_child(_armory)

	_settings = AegisSettingsMenu.new()
	_settings.name = "SettingsPanel"
	_settings.visible = false
	_settings.close_requested.connect(_on_settings_close)
	add_child(_settings)

	resized.connect(_on_resized)
	relayout()


func enter(_stage_payload: Dictionary) -> void:
	_armory.visible = false
	_settings.visible = false
	apply_safe_margins(_margin)
	_on_resized()
	refresh_profile()


## FrontEnd calls this on `profile_changed`, so an unlock made inside the armory
## updates the dashboard underneath it without reopening the screen.
func refresh_profile() -> void:
	var progression := progression_service()
	if progression == null:
		return
	_balance.text = "BATTLE POINTS  %d" % progression.balance
	_best.text = "BEST SCORE  %d" % progression.best_score
	_runs.text = "RUNS COMPLETED  %d" % progression.completed_runs
	_loadout.text = (
		"LOADOUT  %s  /  %s  /  %s"
		% [
			_hero_name(progression.selected_hero_id),
			_weapon_name(progression.selected_weapon_id),
			_world_name(progression.selected_world_id),
		]
	)
	if _armory.visible:
		_armory.refresh_profile(
			progression.balance,
			progression.best_score,
			progression.unlocked_ids,
			progression.selected_weapon_id
		)


func _on_resized() -> void:
	relayout()
	# The armory and settings panels are sized in physical pixels too: they are
	# lists of 56 px rows, and a panel authored in canvas units would be a third
	# of that on a phone.
	_armory.custom_minimum_size = Vector2(px(minf(physical_size().x * 0.92, 420.0)), px(420.0))
	_settings.custom_minimum_size = Vector2(px(minf(physical_size().x * 0.94, 520.0)), px(520.0))
	enforce_font_floor(_armory, _stretch)
	enforce_font_floor(_settings, _stretch)
	_centre(_armory)
	_centre(_settings)


func _centre(panel: Control) -> void:
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = (size - panel.size) * 0.5


func _on_deploy_pressed() -> void:
	Sfx.play_ui(&"session_clear")
	completed.emit(&"HERO", {})


func _on_armory_pressed() -> void:
	refresh_profile()
	_armory.visible = true
	_settings.visible = false
	_armory.focus_first()


func _on_armory_close() -> void:
	_armory.visible = false


func _on_settings_pressed() -> void:
	_settings.visible = true
	_armory.visible = false
	_settings.open()


func _on_settings_close() -> void:
	_settings.visible = false


func _on_replay_pressed() -> void:
	# Clearing the flag is what makes the cinematic reachable again; FrontEnd
	# re-marks it the moment the cinematic completes or is skipped.
	var progression := progression_service()
	if progression == null:
		return
	progression.reset_intro()
	completed.emit(&"CINEMATIC", {})


## Same rules as Main._on_armory_weapon_action: buying spends real BP and
## equipping only ever selects within what the profile already owns.
func _on_weapon_action(weapon_id: StringName) -> void:
	var progression := progression_service()
	if progression == null or not ProgressionService.WEAPON_IDS.has(weapon_id):
		return
	if progression.is_unlocked(weapon_id):
		progression.select_weapon(weapon_id)
		_armory.show_hint("%s EQUIPPED" % String(weapon_id).to_upper())
		return
	var missing := progression.unlock_cost(weapon_id) - progression.balance
	if missing > 0:
		_armory.show_hint("NEED %d MORE BP · FIGHT WAVES" % missing)
		return
	if progression.unlock_weapon(weapon_id):
		progression.select_weapon(weapon_id)
		Sfx.play_ui(&"session_clear")
		_armory.show_hint("%s UNLOCKED & EQUIPPED" % String(weapon_id).to_upper())
	refresh_profile()


func _hero_name(hero_id: StringName) -> String:
	match hero_id:
		&"exo_operative":
			return "EXO OPERATIVE"
	return String(hero_id).to_upper()


func _world_name(world_id: StringName) -> String:
	match world_id:
		&"neon_frontier":
			return "NEON FRONTIER"
	return String(world_id).to_upper()


func _weapon_name(weapon_id: StringName) -> String:
	match weapon_id:
		&"pulse_rifle":
			return "PULSE RIFLE"
		&"nova_launcher":
			return "NOVA LAUNCHER"
		&"arc_shooter":
			return "ARC SHOOTER"
	return String(weapon_id).to_upper()
