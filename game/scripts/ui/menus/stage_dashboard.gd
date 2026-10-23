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
##
## The screen is ordered the way a player decides, not the way a profile is
## stored (docs/UX_AUDIT_2026-10-22.md 5.2 had the old order as DEPLOY last,
## with no hero and no mission on the screen at all):
##
##   1. the operative, with the portrait the HERO screen will also show
##   2. the theatre this run will be deployed into
##   3. DEPLOY -- the only amber control on the screen
##   4. profile: rank line + best score + runs
##   5. resources: the Battle Points wallet, which ARMORY spends
##   6. secondary navigation: ARMORY, SETTINGS, REPLAY INTRO
##
## Everything above reads from ProgressionService / the definition registries.
## The portrait and the theatre plate are the same files the selection screens
## use, so the dashboard cannot promise art the next screen does not have.
extends MenuStage

var _balance: Label
var _best: Label
var _runs: Label
var _loadout: Label
var _armory: ArmoryUi
var _settings: AegisSettingsMenu
var _armory_hint_owner: bool = false
## The four blocks the layout is built from. Portrait stacks them in `_stack`;
## landscape moves them into `_split` so the stats sit beside the actions
## instead of above them -- the stack is ~500 px tall and a landscape phone is
## 390 px, which is what pushed DEPLOY past the bottom edge.
var _stack: VBoxContainer
var _split: HBoxContainer
var _left: VBoxContainer
var _right: VBoxContainer
var _mark: TextureRect
var _stats: AegisPanel
## The folder inside the stats panel, kept so a short screen can tighten it.
var _stat_column: VBoxContainer
## The primary action, kept so the compact arrangement can give 12 px back.
var _deploy: AegisButton
var _actions: VBoxContainer
var _spacer: Control
var _landscape_built := false
## Screen 1: the operative. Portrait, name, role, status.
var _hero_panel: AegisPanel
var _hero_plate: TextureRect
var _hero_name_label: Label
var _hero_role: Label
var _hero_status: Label
## Screen 2: the theatre and the chapter this run belongs to.
var _mission_panel: AegisPanel
var _mission_plate: TextureRect
var _mission_name: Label
var _mission_brief: Label
## The three profile figures, in a grid whose column count follows the width.
var _numbers: GridContainer
## Rank line, above the numbers: the profile's own identity.
var _rank_line: Label
## Secondary navigation, grouped so it can move as one block.
var _secondary: VBoxContainer


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

	_stack = VBoxContainer.new()
	physical_separation(_stack, 22)
	_margin.add_child(_stack)

	_split = HBoxContainer.new()
	_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	physical_separation(_split, 22)
	_left = VBoxContainer.new()
	physical_separation(_left, 22)
	_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right = VBoxContainer.new()
	physical_separation(_right, 16)
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_split.add_child(_left)
	_split.add_child(_right)

	_mark = TextureRect.new()
	_mark.texture = try_texture("res://assets/ui/logo_wordmark.png")
	_mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_size_both(_mark, Vector2(300.0, 75.0), Vector2(470.0, 118.0))
	_stack.add_child(_mark)

	# --- 1. the operative ------------------------------------------------ #
	# Portrait on the left, identity on the right. This is the same portrait
	# file the HERO screen sells, at the same crop, so the first thing the
	# dashboard shows is the character the run will actually use.
	_hero_panel = AegisPanel.new()
	_hero_panel.interactive = false
	_hero_panel.accent_side = "left"
	_hero_panel.accent_color = AegisTokens.INFO
	_hero_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.add_child(_hero_panel)

	var hero_row := HBoxContainer.new()
	physical_separation(hero_row, 18)
	_hero_panel.add_child(hero_row)

	# The portrait and the theatre plate are the definitions' own files, loaded
	# in `refresh_profile()` from `portrait_path` / `plate_path`. Writing the
	# path here as a literal is the drift `data_source_smoke` reads this file
	# for: a renamed portrait would break the dashboard while the HERO card,
	# which reads the registry, kept working.
	_hero_plate = TextureRect.new()
	_hero_plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero_plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_hero_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A 3:4 portrait at 92 px wide is 123 px tall, which leaves the identity
	# column room for three lines inside a 150 px panel on a 390 px screen.
	_size_both(_hero_plate, Vector2(128.0, 170.0), Vector2(96.0, 128.0))
	hero_row.add_child(_hero_plate)

	var hero_column := VBoxContainer.new()
	hero_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	physical_separation(hero_column, 8)
	hero_row.add_child(hero_column)

	_hero_role = make_label("OPERATIVE", "label", AegisTokens.INK_3)
	hero_column.add_child(_hero_role)
	_hero_name_label = make_label("", "title", AegisTokens.INK)
	_hero_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero_column.add_child(_hero_name_label)
	_hero_status = make_label("FIELD READY", "label", AegisTokens.OK)
	hero_column.add_child(_hero_status)

	# --- 2. the theatre --------------------------------------------------- #
	_mission_panel = AegisPanel.new()
	_mission_panel.interactive = false
	_mission_panel.accent_side = "left"
	_mission_panel.accent_color = AegisTokens.ACCENT
	_mission_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.add_child(_mission_panel)

	var mission_row := HBoxContainer.new()
	physical_separation(mission_row, 18)
	_mission_panel.add_child(mission_row)

	_mission_plate = TextureRect.new()
	_mission_plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mission_plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_mission_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_size_both(_mission_plate, Vector2(146.0, 124.0), Vector2(112.0, 96.0))
	mission_row.add_child(_mission_plate)

	var mission_column := VBoxContainer.new()
	mission_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	physical_separation(mission_column, 8)
	mission_row.add_child(mission_column)

	mission_column.add_child(make_label("DEPLOYMENT THEATRE", "label", AegisTokens.INK_3))
	_mission_name = make_label("", "title", AegisTokens.INK)
	_mission_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_column.add_child(_mission_name)
	_mission_brief = make_label("", "label_s", AegisTokens.INK_2)
	_mission_brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_column.add_child(_mission_brief)

	# --- 3. DEPLOY -------------------------------------------------------- #
	# A spacer above it, not below: the primary action sits in the lower thumb
	# arc but never at the very edge, and nothing scrolls off a short screen.
	_spacer = Control.new()
	_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stack.add_child(_spacer)

	var actions := VBoxContainer.new()
	physical_separation(actions, 14)
	_stack.add_child(actions)
	_actions = actions

	_deploy = make_button("DEPLOY", "primary", "Choose your loadout and start a run")
	var deploy := _deploy
	physical_min_size(deploy, 0.0, 78.0)
	deploy.pressed.connect(_on_deploy_pressed)
	actions.add_child(deploy)

	# --- 4/5. profile and resources --------------------------------------- #
	# One panel, ordered: identity, then the wallet, then the record. Three
	# numbers side by side instead of four stacked lines -- the old column spent
	# 130 px of a 844 px phone screen on four single-value rows.
	_stats = AegisPanel.new()
	_stats.interactive = false
	_stats.accent_side = "top"
	_stats.accent_color = AegisTokens.INFO
	_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.add_child(_stats)

	var stat_column := VBoxContainer.new()
	physical_separation(stat_column, 12)
	_stat_column = stat_column
	_stats.add_child(stat_column)

	_rank_line = make_label("PROFILE", "label", AegisTokens.INK_3)
	stat_column.add_child(_rank_line)

	# A grid, not a row: three "CAPTION  value" labels are 95-110 px each at the
	# font floor, and a phone's third of 306 px is narrower than that, so the row
	# wrapped into ragged two-line cells. Two columns fit every label on one line
	# and leave the third cell alone on its row, which reads as a list; a wide
	# screen goes back to one row of three.
	_numbers = GridContainer.new()
	_numbers.columns = 3
	_numbers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_numbers.add_theme_constant_override("h_separation", roundi(px(10.0)))
	_numbers.add_theme_constant_override("v_separation", roundi(px(6.0)))
	stat_column.add_child(_numbers)

	# The wallet is the only number a player acts on, so it is the only one in
	# amber; score and runs are the record and stay neutral.
	var wallet := _make_stat_cell("BATTLE POINTS", AegisTokens.ACCENT)
	_numbers.add_child(wallet[0])
	_balance = wallet[1]
	var best := _make_stat_cell("BEST SCORE", AegisTokens.INK)
	_numbers.add_child(best[0])
	_best = best[1]
	var runs := _make_stat_cell("RUNS COMPLETED", AegisTokens.INK)
	_numbers.add_child(runs[0])
	_runs = runs[1]

	_loadout = make_label("LOADOUT", "label_s", AegisTokens.INK_2)
	_loadout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stat_column.add_child(_loadout)

	# --- 6. secondary navigation ------------------------------------------ #
	_secondary = VBoxContainer.new()
	physical_separation(_secondary, 12)
	actions.add_child(_secondary)

	var row := HBoxContainer.new()
	physical_separation(row, 14)
	_secondary.add_child(row)

	# Every secondary control clears AegisTokens.MIN_TOUCH_PX. They were 52 px
	# and 44 px, which is under the floor the rest of the front end holds and
	# under a thumb: `menu_layout_smoke` measures button heights in physical
	# pixels on four screens and failed on exactly these three.
	var armory := make_button("ARMORY", "round", "Unlock and equip weapons with Battle Points")
	armory.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	physical_min_size(armory, 0.0, AegisTokens.MIN_TOUCH_PX)
	armory.pressed.connect(_on_armory_pressed)
	row.add_child(armory)

	var settings := make_button("SETTINGS", "round", "Audio, HUD and control preferences")
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	physical_min_size(settings, 0.0, AegisTokens.MIN_TOUCH_PX)
	settings.pressed.connect(_on_settings_pressed)
	row.add_child(settings)

	var replay := make_button("REPLAY INTRO", "ghost", "Watch the opening cinematic again")
	physical_min_size(replay, 0.0, AegisTokens.MIN_TOUCH_PX)
	replay.pressed.connect(_on_replay_pressed)
	_secondary.add_child(replay)

	_armory = ArmoryUi.new()
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

	_connect_resized(_on_resized)
	relayout()


func enter(_stage_payload: Dictionary) -> void:
	_armory.visible = false
	_settings.visible = false
	apply_safe_margins(_margin)
	_on_resized()
	refresh_profile()


## FrontEnd calls this on `profile_changed`, so an unlock made inside the armory
## updates the dashboard underneath it without reopening the screen.
## One number, sized to a third of the row. Returns [container, label] because
## the caller needs both: the container goes into the row, the label is what
## `refresh_profile()` writes.
##
## It is deliberately *one* label holding "CAPTION  value". The first cut had a
## caption above a value, and `refresh_profile()` wrote the caption again inside
## the value -- so the screen read "BATTLE POINTS" over "BATTLE POINTS 0" and
## printed every label twice. The two-space string is what the data-source test
## reads and what a screen reader reads as one phrase, so it belongs in one
## label; a third of a phone is too narrow for caption-and-number columns, and
## the wrapping at the double space reads as a caption and a figure anyway.
func _make_stat_cell(caption: String, color: Color) -> Array:
	var label := make_label(caption, "label_s", color)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Bottom-aligned so the three figures share one baseline: "BATTLE POINTS"
	# wraps to two lines on a phone and "BEST SCORE" does not, and centring the
	# short one left its number floating between the other two lines.
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return [label, label]


func refresh_profile() -> void:
	var progression := progression_service()
	if progression == null:
		return
	# The labels keep the "CAPTION  value" shape they have always had: the
	# smoke tests and the data-source test both assert on that string, and it is
	# also what a screen reader reads as one phrase. What changed is the
	# arrangement -- three cells side by side instead of four stacked rows.
	_balance.text = "BATTLE POINTS  %d" % progression.balance
	_best.text = "BEST SCORE  %d" % progression.best_score
	_runs.text = "RUNS COMPLETED  %d" % progression.completed_runs
	var hero := _hero_name(progression.selected_hero_id)
	var weapon := _weapon_name(progression.selected_weapon_id)
	var world := _world_name(progression.selected_world_id)
	_loadout.text = "LOADOUT  %s  /  %s  /  %s" % [hero, weapon, world]
	_hero_name_label.text = hero
	_mission_name.text = world
	# The rank is the profile's own identity line. There is no rank ladder in
	# the save file, so this states the operative's readiness and the record
	# rather than inventing a level: "NO RUNS" on a fresh profile is true, and
	# "SQUAD LEADER Lv 4" would not be.
	_rank_line.text = (
		"PROFILE  ·  FIELD READY"
		if progression.completed_runs == 0
		else "PROFILE  ·  %d RUNS" % progression.completed_runs
	)
	# Both status lines come from the definitions, not from literals here: the
	# HERO and WORLD cards print the same strings, so the dashboard cannot say an
	# operative is ready when their card says otherwise.
	var hero_definition := HeroDefinition.load_definition(progression.selected_hero_id)
	_hero_status.text = (
		hero_definition.status_line.to_upper() if hero_definition != null else "FIELD READY"
	)
	_hero_plate.texture = (
		try_texture(hero_definition.portrait_path) if hero_definition != null else null
	)
	# The brief is the theatre's own first sentence. The WORLD screen prints the
	# whole description; a dashboard line is a reminder of where you are going,
	# not a briefing document.
	var world_definition := WorldDefinition.load_definition(progression.selected_world_id)
	if world_definition != null:
		_mission_brief.text = _first_sentence(world_definition.role_description)
		_mission_plate.texture = try_texture(world_definition.plate_path)
	else:
		_mission_brief.text = ""
		_mission_plate.texture = null
	if _armory.visible:
		_armory.refresh_profile(
			progression.balance,
			progression.best_score,
			progression.unlocked_ids,
			progression.selected_weapon_id
		)


## Picks the arrangement that fits the screen: one column in portrait, stats
## beside actions in landscape. Only runs when the orientation actually
## changes, so a resize inside the same orientation is a re-scale, not a
## rebuild, and every block is detached before being re-added in reading order
## so the arrangement never depends on the order it was first built in.
func _apply_orientation() -> void:
	var landscape := is_landscape()
	if landscape == _landscape_built:
		return
	_landscape_built = landscape
	for block in [_mark, _hero_panel, _mission_panel, _spacer, _actions]:
		if block.get_parent() != null:
			block.get_parent().remove_child(block)
	if landscape:
		# A landscape phone is 390 px tall in physical terms, so the hero and
		# the theatre go side by side with DEPLOY beneath them instead of in one
		# 700 px column that would push the primary action off the screen.
		_stack.add_child(_split)
		_left.add_child(_mark)
		_left.add_child(_hero_panel)
		_left.add_child(_mission_panel)
		_right.add_child(_spacer)
		_right.add_child(_actions)
	else:
		_stack.remove_child(_split)
		_stack.add_child(_mark)
		_stack.add_child(_hero_panel)
		_stack.add_child(_mission_panel)
		_stack.add_child(_spacer)
		_stack.add_child(_actions)


## Two height budgets, one rule: the stack has to fit what it is given.
##
## Portrait below 700 px (a 360x640 phone) has no room for the full card set in
## one column -- the stack measured 754 px -- and landscape is always short (a
## rotated phone is 390 px tall), so both get the same treatment: tighter
## margins and gaps, smaller wordmark and plates, the redundant PROFILE header
## dropped, and the two descriptive lines held to one line each with an
## ellipsis. Nothing is reworded, DEPLOY keeps its size, and the hierarchy is
## identical -- the screen gets shorter, not different.
func _apply_density() -> void:
	var landscape := is_landscape()
	# A portrait phone is always the compact arrangement. The threshold used to
	# be 700 px, which left a 390x844 phone on the full stack -- and the stack
	# is 915 px tall at the sizes this screen now uses, 70 px past the bottom
	# of the display. 900 keeps every phone portrait compact and leaves a
	# tablet or a desktop on the full layout.
	var compact := physical_size().y < (520.0 if landscape else 900.0)
	# A 360x640 phone is the smallest surface the front end is tested on, and the
	# compact stack still measured 60 px past its bottom: REPLAY INTRO sat at
	# y=636 with a 64 px height (menu_layout_smoke). `cramped` is the last step
	# before the layout would have to drop content -- it takes 72 px back out of
	# margins, the wordmark, three gaps, DEPLOY and the one line that is already
	# an ellipsis ("LOADOUT: EXO-OPERATIVE / PULSE…"), and leaves every control
	# at or above the touch floor.
	var cramped := not landscape and physical_size().y < 700.0
	# The safe margins also come in on a short screen: 8 px top and bottom is
	# worth more to the content than to the composition at that size.
	# A landscape phone is 390 px tall. The web shell already reserves 30 px at
	# the top for its own bar, so the stage's own top inset is cut to 8 there --
	# 28 px of air above a wordmark is a desktop luxury, and it was the
	# difference between DEPLOY fitting and REPLAY INTRO hanging off the bottom
	# edge (menu_layout_smoke, 844x390).
	apply_safe_margins(
		_margin,
		20.0 if compact else 36.0,
		8.0 if cramped else (16.0 if compact else 28.0),
		8.0 if compact else 28.0
	)
	# The card surface costs its inset twice per card in width and height, and a
	# 360 px phone has neither: at 12 px the DEPLOY row measured 352 px of a 360
	# px screen and the stack ran 44 px past the bottom (menu_layout_smoke).
	for panel in [_hero_panel, _mission_panel, _stats]:
		panel.set_surface_pad(px(4.0 if cramped else (6.0 if compact else 12.0)))
	physical_separation(_stack, 8.0 if cramped else (12.0 if compact else 22.0))
	physical_separation(_left, 12.0 if compact else 22.0)
	physical_separation(_right, 10.0 if compact else 16.0)
	physical_separation(_actions, 10.0 if compact else 14.0)
	# "PROFILE . FIELD READY" restates what the three cells below it already say
	# on a screen this short; the header is the one line that can go.
	# Three "CAPTION  value" cells. On a 390 px phone two columns leave one of
	# them alone on its row, and "RUNS COMPLETED  0" then wraps its figure onto
	# a second line -- the number you came to read, orphaned in the margin of
	# the row below it (seen in the 390x844 capture). One column is three short
	# rows and reads as a list, which is what it is.
	var width := physical_size().x
	_numbers.columns = 1 if width < 480.0 else (2 if width < 560.0 else 3)
	physical_separation(_stat_column, 8.0 if compact else 12.0)
	# 78 px is the desktop DEPLOY. On a 390 px tall screen it is one of three
	# blocks that have to fit under a 30 px browser bar, and 66 is still above
	# the 64 px touch floor and twice the height of the old button.
	# 66, not 60: this is a primary action and menu_layout_smoke holds every
	# button to within a pixel of AegisTokens.MIN_TOUCH_PX ("DEPLOY is only 60 px
	# tall, under the 63 px touch floor"). The 6 px comes out of the wordmark
	# instead.
	physical_min_size(_deploy, 0.0, 66.0 if compact else 78.0)
	# Already trimmed to one line with an ellipsis on a compact screen, and the
	# first thing to lose its place when a stacked arrangement runs out of one.
	_loadout.visible = not cramped
	_rank_line.visible = not compact
	_limit_lines(_mission_brief, 1 if compact else 2)
	_limit_lines(_loadout, 1 if compact else 2)
	# Only the compact sizes are set here. Every other size comes from
	# `_orient_nodes()`, so a rotation back to a tall screen restores the
	# authored values instead of keeping whatever this pass last wrote.
	if landscape:
		if compact:
			physical_min_size(_mark, 260.0, 65.0)
			physical_min_size(_hero_plate, 84.0, 112.0)
			physical_min_size(_mission_plate, 96.0, 82.0)
		elif physical_size().y >= 600.0:
			# A desktop has the height a phone does not. The plates were authored
			# at 78x104 for a rotated phone and looked undersized on a 720 px
			# canvas, in a card with room to spare.
			physical_min_size(_mark, 470.0, 118.0)
			physical_min_size(_hero_plate, 128.0, 170.0)
			physical_min_size(_mission_plate, 146.0, 124.0)
	elif compact:
		if cramped:
			physical_min_size(_mark, 236.0, 58.0)
		else:
			physical_min_size(_mark, 310.0, 78.0)
		physical_min_size(_hero_plate, 96.0, 128.0)
		physical_min_size(_mission_plate, 108.0, 92.0)


func _on_resized() -> void:
	relayout()
	_orient_nodes([_mark, _hero_plate, _mission_plate])
	_apply_orientation()
	_apply_density()
	# The armory and settings panels are sized in physical pixels too: they are
	# lists of 56 px rows, and a panel authored in canvas units would be a third
	# of that on a phone.
	_armory.custom_minimum_size = Vector2(px(minf(physical_size().x * 0.92, 470.0)), px(470.0))
	_settings.custom_minimum_size = Vector2(px(minf(physical_size().x * 0.94, 560.0)), px(560.0))
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


## The theatre's own blurb, cut to its first sentence. The WORLD screen prints
## the whole paragraph; a dashboard line is a reminder of where you are going,
## not a briefing document.
func _first_sentence(text: String) -> String:
	var trimmed := text.strip_edges()
	var stop := trimmed.find(".")
	if stop <= 0:
		return trimmed
	return trimmed.substr(0, stop)


## Heroes and worlds have no *numeric* model -- there is no per-hero health or
## speed -- but they do have a name, and it lives in the `HeroDefinition` /
## `WorldDefinition` registries exactly as a weapon's does. Reading it from
## there instead of typing it out here is what stops the dashboard calling the
## loadout something the HERO and WORLD cards do not.
func _hero_name(hero_id: StringName) -> String:
	var definition := HeroDefinition.load_definition(hero_id)
	if definition != null:
		return definition.display_name.to_upper()
	return String(hero_id).replace("_", " ").to_upper()


func _world_name(world_id: StringName) -> String:
	var definition := WorldDefinition.load_definition(world_id)
	if definition != null:
		return definition.display_name.to_upper()
	return String(world_id).replace("_", " ").to_upper()


## The weapon names itself: `WeaponDefinition.display_name` is the same string
## the selection card prints, so the dashboard cannot call it something else.
func _weapon_name(weapon_id: StringName) -> String:
	var definition := WeaponDefinition.load_definition(weapon_id)
	if definition != null and not definition.display_name.strip_edges().is_empty():
		return definition.display_name.to_upper()
	return String(weapon_id).to_upper()
