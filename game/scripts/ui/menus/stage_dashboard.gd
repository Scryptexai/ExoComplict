## MAIN DASHBOARD: the lobby.
##
## This screen is composed the way a AAA lobby is composed, from the references
## measured in docs/VERIFICATION_2026-10-23.md 1 rather than from taste:
##
##   * a **full-height character** in the middle, the thing the screen is about
##     (CoD Mobile's lobby, Valorant's, Apex's and Free Fire's all do this);
##   * an **edge-docked card stack** down one side -- the operative and the
##     theatre -- at 300-360 px, which is Valorant's left rail and Free Fire's
##     weapon-preset panel;
##   * a **currency chip** in the top-right corner next to the wordmark, which is
##     where all four references put the wallet;
##   * one **large amber action tile** at the bottom of the dock, the way Free
##     Fire's BATTLE ROYALE tile and Apex's READY bar work -- not a full-width
##     button in a column of buttons;
##   * a **tab row** of secondary destinations under it, the Free Fire bottom bar;
##   * the record (best score, runs) as a small strip, not a headline.
##
## Every number comes from ProgressionService, which is the only owner of the
## persistent profile. There is no "profile level", no streak and no daily
## reward: the save file holds Battle Points, best score, completed runs,
## unlocks and the last loadout, so those five things are what this screen
## shows. A sixth row would mean inventing data the game does not track.
##
## Every button does something:
##   DEPLOY     starts the loadout chain HERO -> WEAPON -> WORLD -> PRELOAD
##   ARMORY     the in-game shop, spending real BP for real unlocks
##   SETTINGS   the shared AegisSettingsMenu, writing user://aegis.cfg
##
## There is no REPLAY INTRO. The studio ident is not this game's content: it is
## the studio's mark, played at launch like a publisher card, and a dashboard
## row offering to rewatch somebody else's brand film was the wrong idea about
## what that file is (docs/VERIFICATION_2026-10-23.md 5).
extends MenuStage

const ShowcaseViewportScript = preload("res://scripts/ui/widgets/showcase_viewport.gd")
## The rig is 1.78 m tall; `ShowcaseViewport` normalises by height, so the
## lobby and the HERO screen present the same operative at the same scale.
const SHOWCASE_HEIGHT := 1.78
## How much of the character's box the model fills. The lobby box is tall and
## narrow on a phone and wide on a desktop; 0.9 reads as "standing in the room"
## at both, where 1.0 crops the feet on the short one.
const SHOWCASE_FILL := 0.9

# --- top bar ---------------------------------------------------------------- #
var _top: HBoxContainer
var _mark: TextureRect
var _status_label: Label
var _wallet: AegisPanel
## The wallet figure, in the "BATTLE POINTS  n" shape the tests and the screen
## reader read as one phrase.
var _balance: Label

# --- the three bands -------------------------------------------------------- #
var _root: VBoxContainer
## Portrait stacks cards, character, dock; landscape puts the cards and the
## dock either side of the character. Both exist as parents and the blocks are
## moved between them, so a rotation is a reconciliation rather than a rebuild.
var _body_portrait: VBoxContainer
var _body_landscape: HBoxContainer
## The edge-docked card stack.
var _cards: VBoxContainer
## The character's box. It is a Control the 3D viewport fills.
var _stage: Control
var _showcase: ShowcaseViewport
## The bottom dock: record, tabs, primary action.
var _dock: VBoxContainer
var _landscape_built := false
var _hero_id := StringName()

# --- the cards -------------------------------------------------------------- #
var _hero_panel: AegisPanel
var _hero_plate: TextureRect
var _hero_role: Label
var _hero_name_label: Label
var _hero_status: Label
var _mission_panel: AegisPanel
var _mission_plate: TextureRect
var _mission_name: Label
var _mission_brief: Label
var _mission_caption: Label

# --- the dock --------------------------------------------------------------- #
var _stats: AegisPanel
var _stat_column: VBoxContainer
var _numbers: GridContainer
var _rank_line: Label
var _best: Label
var _runs: Label
var _loadout: Label
## The secondary row: the tab bar under the primary action.
var _secondary: HBoxContainer
var _deploy: AegisButton
var _deploy_caption: Label
## The caption sits on a chip: bare type over the 3D stage was unreadable
## against a lit backdrop, and "NEON FRONTIER · READY TO DEPLOY" is the one
## line that says what the amber tile will do.
var _deploy_chip: AegisPanel

# --- the modals ------------------------------------------------------------- #
var _armory: ArmoryUi
var _settings: AegisSettingsMenu


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(make_backdrop("res://assets/ui/dashboard_bg.jpg"))

	# The lobby is lit, not dimmed: the character is the subject and a heavy
	# scrim over it is the thing that made the old screen read as a form. Only
	# the left third and the bottom dock get a shadow, and that is the cards'
	# own surface, not a full-screen wash.
	var scrim := ColorRect.new()
	scrim.color = Color(AegisTokens.VOID, 0.18)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	make_margin()
	_root = VBoxContainer.new()
	physical_separation(_root, 16)
	_margin.add_child(_root)

	_build_top_bar()
	_build_bands()
	_build_cards()
	_build_stage()
	_build_dock()
	_build_modals()

	_connect_resized(_on_resized)
	relayout()
	_apply_orientation()
	_apply_density()


# --- construction ----------------------------------------------------------- #


## Wordmark left, readiness in the middle, wallet right. This is the shape all
## four references use: identity on one corner, money on the other, and nothing
## between them competing with the character.
func _build_top_bar() -> void:
	_top = HBoxContainer.new()
	_top.name = &"LobbyTopBar"
	_top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	physical_separation(_top, 16)
	_root.add_child(_top)

	_mark = TextureRect.new()
	_mark.name = &"Wordmark"
	_mark.texture = try_texture("res://assets/ui/logo_wordmark.png")
	_mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_size_both(_mark, Vector2(230.0, 58.0), Vector2(300.0, 75.0))
	_top.add_child(_mark)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top.add_child(spacer)

	_status_label = make_label("FIELD READY", "label", AegisTokens.OK)
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.max_lines_visible = 1
	_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_top.add_child(_status_label)

	# The wallet is a chip, not a row: a borderless line of type on a lobby is
	# invisible against the backdrop, and every reference puts the currency on
	# a surface of its own.
	_wallet = AegisPanel.new()
	_wallet.name = &"WalletChip"
	_wallet.interactive = false
	_wallet.accent_side = "none"
	_wallet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wallet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_top.add_child(_wallet)
	_balance = make_label("BATTLE POINTS  0", "label", AegisTokens.ACCENT)
	# One line, and wide enough for its own text. Wrapping it was the fix for a
	# different problem (a Label's minimum width is its text width) but an
	# ellipsised wrapped label collapses to its longest *word* when the row is
	# tight, and the chip drew as a 40 px empty box beside the spacer. The width
	# now comes from `_apply_density`, which knows how much the row has.
	_balance.autowrap_mode = TextServer.AUTOWRAP_OFF
	_wallet.add_child(_balance)


func _build_bands() -> void:
	_body_portrait = VBoxContainer.new()
	_body_portrait.name = &"LobbyBandsPortrait"
	_body_portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	physical_separation(_body_portrait, 10)

	_body_landscape = HBoxContainer.new()
	_body_landscape.name = &"LobbyBandsLandscape"
	_body_landscape.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_landscape.size_flags_vertical = Control.SIZE_EXPAND_FILL
	physical_separation(_body_landscape, 18)

	_cards = VBoxContainer.new()
	_cards.name = &"LobbyCards"
	_cards.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	physical_separation(_cards, 12)

	_dock = VBoxContainer.new()
	_dock.name = &"LobbyDock"
	_dock.alignment = BoxContainer.ALIGNMENT_END
	physical_separation(_dock, 12)


## The operative: the same portrait the HERO screen sells, at the same crop, so
## the first thing the lobby shows is the character the run will use.
func _build_cards() -> void:
	_hero_panel = AegisPanel.new()
	_hero_panel.name = &"OperativeCard"
	_hero_panel.interactive = false
	_hero_panel.accent_side = "left"
	_hero_panel.accent_color = AegisTokens.INFO
	_hero_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cards.add_child(_hero_panel)

	var hero_row := HBoxContainer.new()
	physical_separation(hero_row, 14)
	_hero_panel.add_child(hero_row)

	# The path is the definition's own, loaded in `refresh_profile()`; writing
	# it here as a literal is the drift `data_source_smoke` reads this file for.
	_hero_plate = TextureRect.new()
	_hero_plate.name = &"OperativePortrait"
	_hero_plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero_plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_hero_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_size_both(_hero_plate, Vector2(84.0, 112.0), Vector2(120.0, 160.0))
	hero_row.add_child(_hero_plate)

	var hero_column := VBoxContainer.new()
	hero_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	physical_separation(hero_column, 6)
	hero_row.add_child(hero_column)

	_hero_role = make_label("OPERATIVE", "label", AegisTokens.INK_3)
	hero_column.add_child(_hero_role)
	_hero_name_label = make_label("", "title", AegisTokens.INK)
	_hero_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero_column.add_child(_hero_name_label)
	_hero_status = make_label("FIELD READY", "label", AegisTokens.OK)
	_hero_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hero_status.max_lines_visible = 1
	_hero_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hero_column.add_child(_hero_status)

	# The theatre: where DEPLOY goes.
	_mission_panel = AegisPanel.new()
	_mission_panel.name = &"TheatreCard"
	_mission_panel.interactive = false
	_mission_panel.accent_side = "left"
	_mission_panel.accent_color = AegisTokens.ACCENT
	_mission_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cards.add_child(_mission_panel)

	var mission_row := HBoxContainer.new()
	physical_separation(mission_row, 14)
	_mission_panel.add_child(mission_row)

	_mission_plate = TextureRect.new()
	_mission_plate.name = &"TheatrePlate"
	_mission_plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mission_plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_mission_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_size_both(_mission_plate, Vector2(92.0, 70.0), Vector2(132.0, 100.0))
	mission_row.add_child(_mission_plate)

	var mission_column := VBoxContainer.new()
	mission_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mission_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	physical_separation(mission_column, 6)
	mission_row.add_child(mission_column)

	_mission_caption = make_label("DEPLOYMENT THEATRE", "label", AegisTokens.INK_3)
	mission_column.add_child(_mission_caption)
	_mission_name = make_label("", "title", AegisTokens.INK)
	_mission_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_column.add_child(_mission_name)
	_mission_brief = make_label("", "label_s", AegisTokens.INK_2)
	_mission_brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_column.add_child(_mission_brief)


## The character. A plain Control so the 3D viewport can fill it while the
## cards and the dock stay in the 2D layer beside it.
func _build_stage() -> void:
	_stage = Control.new()
	_stage.name = &"LobbyStage"
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.clip_contents = false

	_showcase = ShowcaseViewportScript.new()
	_showcase.name = &"LobbyShowcase"
	_showcase.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(_showcase)


## The dock: the record, the tab row, then the one amber tile. Ordered by how
## often a player uses it, bottom-up: DEPLOY is nearest the thumb, the tabs are
## above it, and the record is the thing you read once.
func _build_dock() -> void:
	_deploy = make_button("DEPLOY", "primary", "Choose your loadout and start a run")
	physical_min_size(_deploy, 0.0, 100.0)
	_deploy.pressed.connect(_on_deploy_pressed)

	_deploy_chip = AegisPanel.new()
	_deploy_chip.name = &"DeployChip"
	_deploy_chip.interactive = false
	_deploy_chip.accent_side = "none"
	_deploy_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deploy_chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_deploy_caption = make_label("", "label_s", AegisTokens.INK_2)
	_deploy_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_deploy_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_deploy_caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_deploy_caption.max_lines_visible = 1
	_deploy_chip.add_child(_deploy_caption)

	_secondary = HBoxContainer.new()
	_secondary.name = &"LobbyTabs"
	physical_separation(_secondary, 12)

	var armory := make_button("ARMORY", "card", "Unlock and equip weapons with Battle Points")
	armory.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	physical_min_size(armory, 0.0, 68.0)
	armory.pressed.connect(_on_armory_pressed)
	_secondary.add_child(armory)

	var settings := make_button("SETTINGS", "card", "Audio, HUD and control preferences")
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	physical_min_size(settings, 0.0, 68.0)
	settings.pressed.connect(_on_settings_pressed)
	_secondary.add_child(settings)

	# The record, last and smallest. Three "CAPTION  value" labels in one panel;
	# the wallet is the only one in amber because it is the only one a player
	# acts on.
	_stats = AegisPanel.new()
	_stats.name = &"RecordPanel"
	_stats.interactive = false
	_stats.accent_side = "top"
	_stats.accent_color = AegisTokens.INFO
	_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_stat_column = VBoxContainer.new()
	physical_separation(_stat_column, 10)
	_stats.add_child(_stat_column)

	_rank_line = make_label("PROFILE", "label", AegisTokens.INK_3)
	_stat_column.add_child(_rank_line)

	_numbers = GridContainer.new()
	_numbers.columns = 3
	_numbers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_numbers.add_theme_constant_override("h_separation", roundi(px(12.0)))
	_numbers.add_theme_constant_override("v_separation", roundi(px(6.0)))
	_stat_column.add_child(_numbers)

	var best := _make_stat_cell("BEST SCORE", AegisTokens.INK)
	_numbers.add_child(best[0])
	_best = best[1]
	var runs := _make_stat_cell("RUNS COMPLETED", AegisTokens.INK)
	_numbers.add_child(runs[0])
	_runs = runs[1]

	_loadout = make_label("LOADOUT", "label_s", AegisTokens.INK_2)
	_loadout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stat_column.add_child(_loadout)

	# Bottom-up: the record is read once, the tabs are destinations, the chip
	# names the theatre, and DEPLOY is the row under the thumb.
	_dock.add_child(_stats)
	_dock.add_child(_secondary)
	_dock.add_child(_deploy_chip)
	_dock.add_child(_deploy)


func _build_modals() -> void:
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


# --- stage lifecycle -------------------------------------------------------- #


func enter(_stage_payload: Dictionary) -> void:
	_armory.visible = false
	_settings.visible = false
	apply_safe_margins(_margin)
	_on_resized()
	refresh_profile()


func exit() -> void:
	if is_instance_valid(_showcase):
		_showcase.clear_model()


## FrontEnd calls this on `profile_changed`, so an unlock made inside the armory
## updates the lobby underneath it without reopening the screen.
func refresh_profile() -> void:
	var progression := progression_service()
	if progression == null:
		return
	_balance.text = "BATTLE POINTS  %d" % progression.balance
	_best.text = "BEST SCORE  %d" % progression.best_score
	_runs.text = "RUNS COMPLETED  %d" % progression.completed_runs
	var hero := _hero_name(progression.selected_hero_id)
	var weapon := _weapon_name(progression.selected_weapon_id)
	var world := _world_name(progression.selected_world_id)
	_loadout.text = "LOADOUT  %s  /  %s  /  %s" % [hero, weapon, world]
	_hero_name_label.text = hero
	_mission_name.text = world
	_deploy_caption.text = "%s  ·  READY TO DEPLOY" % world
	# The rank is the profile's own identity line. There is no rank ladder in
	# the save file, so this states the record rather than inventing a level:
	# "NO RUNS" on a fresh profile is true, "SQUAD LEADER Lv 4" would not be.
	_rank_line.text = (
		"PROFILE  ·  FIELD READY"
		if progression.completed_runs == 0
		else "PROFILE  ·  %d RUNS" % progression.completed_runs
	)
	# Both status lines come from the definitions, not from literals here: the
	# HERO and WORLD cards print the same strings, so the lobby cannot say an
	# operative is ready when their card says otherwise.
	var hero_definition := HeroDefinition.load_definition(progression.selected_hero_id)
	_hero_status.text = (
		hero_definition.status_line.to_upper() if hero_definition != null else "FIELD READY"
	)
	_hero_plate.texture = (
		try_texture(hero_definition.portrait_path) if hero_definition != null else null
	)
	var world_definition := WorldDefinition.load_definition(progression.selected_world_id)
	if world_definition != null:
		_mission_brief.text = _first_sentence(world_definition.role_description)
		_mission_plate.texture = try_texture(world_definition.plate_path)
	else:
		_mission_brief.text = ""
		_mission_plate.texture = null
	_sync_showcase(progression.selected_hero_id)
	if _armory.visible:
		_armory.refresh_profile(
			progression.balance,
			progression.best_score,
			progression.unlocked_ids,
			progression.selected_weapon_id
		)


## The lobby shows the operative the run will use, in 3D, between the cards and
## the dock. Presentation is skipped when the definition has no rig: this game
## ships exactly one, and a placeholder capsule in the middle of the lobby would
## be worse than the empty stage.
func _sync_showcase(hero_id: StringName) -> void:
	if not is_instance_valid(_showcase):
		return
	if hero_id == _hero_id and _showcase.has_model():
		return
	_hero_id = hero_id
	var definition := HeroDefinition.load_definition(hero_id)
	if definition == null or not is_instance_valid(definition.model_scene):
		_showcase.clear_model()
		return
	if _showcase.model_path() == definition.model_scene.resource_path:
		return
	(
		_showcase
		. present(
			definition.model_scene,
			{
				"fit_axis": 1,
				"height": SHOWCASE_HEIGHT,
				# The rig faces +Z and the camera sits on +Z, so no yaw is what
				# turns the operative towards the viewer.
				"yaw": 0.0,
				"clips": definition.showcase_clips,
			}
		)
	)
	_showcase.frame_to_fill(SHOWCASE_FILL, 0.04)


## One "CAPTION  value" label per figure. Deliberately one label, not a caption
## above a value: the first cut printed every caption twice, and the data-source
## test reads this string.
func _make_stat_cell(caption: String, color: Color) -> Array:
	var label := make_label(caption, "label_s", color)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return [label, label]


# --- arrangement ------------------------------------------------------------ #


## Portrait: cards, character, dock, top to bottom. Landscape: cards and dock
## either side of the character, because a 390 px tall screen cannot stack three
## bands and still show an operative.
##
## Every block is detached before it is re-parented, so the arrangement never
## depends on the order it was first built in, and only a real orientation
## change rebuilds it -- a resize inside the same orientation is a re-scale.
func _apply_orientation() -> void:
	var landscape := is_landscape()
	# A theme change is not a rotation: the blocks only move when the orientation
	# changed, or when they are not in the tree yet (the first layout).
	var placed := (
		_body_landscape.get_parent() != null if landscape else _body_portrait.get_parent() != null
	)
	if landscape == _landscape_built and placed:
		return
	_landscape_built = landscape
	for block in [_cards, _stage, _dock]:
		if block.get_parent() != null:
			block.get_parent().remove_child(block)
	if landscape:
		if _body_portrait.get_parent() == _root:
			_root.remove_child(_body_portrait)
		if _body_landscape.get_parent() == null:
			_root.add_child(_body_landscape)
		_body_landscape.add_child(_cards)
		_body_landscape.add_child(_stage)
		_body_landscape.add_child(_dock)
		_cards.size_flags_horizontal = Control.SIZE_FILL
		_dock.size_flags_horizontal = Control.SIZE_FILL
	else:
		if _body_landscape.get_parent() == _root:
			_root.remove_child(_body_landscape)
		if _body_portrait.get_parent() == null:
			_root.add_child(_body_portrait)
		_body_portrait.add_child(_cards)
		_body_portrait.add_child(_stage)
		_body_portrait.add_child(_dock)
		_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_dock.size_flags_horizontal = Control.SIZE_EXPAND_FILL


## Four budgets, measured on the four viewports the smoke test uses. The
## character keeps whatever is left after the cards and the dock have the sizes
## they need; on a short screen the *copy* gives way, never a target.
func _apply_density() -> void:
	var landscape := is_landscape()
	var height := physical_size().y
	var width := physical_size().x
	var compact := height < (520.0 if landscape else 900.0)
	var cramped := not landscape and height < 700.0
	var desktop := not compact and height >= 600.0
	var short_landscape := landscape and compact

	apply_safe_margins(
		_margin,
		20.0 if compact else 36.0,
		8.0 if (cramped or short_landscape) else (16.0 if compact else 28.0),
		8.0 if compact else 28.0
	)
	# The card surface costs its inset twice per card in width and in height.
	for panel in [_hero_panel, _mission_panel, _stats, _wallet, _deploy_chip]:
		panel.set_surface_pad(px(4.0 if cramped else (6.0 if compact else 12.0)))

	physical_separation(_root, 8.0 if cramped else (12.0 if compact else 20.0))
	physical_separation(_cards, 8.0 if compact else 14.0)
	physical_separation(_dock, 8.0 if cramped else (10.0 if compact else 14.0))
	physical_separation(_secondary, 8.0 if cramped else (10.0 if compact else 14.0))
	physical_separation(_stat_column, 6.0 if compact else 10.0)
	physical_separation(_body_landscape, 14.0 if compact else 22.0)

	# --- typography and plate sizes -------------------------------------- #
	if desktop:
		physical_min_size(_mark, 300.0, 75.0)
		physical_min_size(_balance, 190.0, 0.0)
		physical_min_size(_hero_plate, 120.0, 160.0)
		physical_min_size(_mission_plate, 132.0, 100.0)
		physical_min_size(_deploy, 0.0, 100.0)
		for tab in _secondary.get_children():
			physical_min_size(tab as Control, 0.0, 68.0)
	elif short_landscape:
		physical_min_size(_mark, 150.0, 40.0)
		physical_min_size(_balance, 150.0, 0.0)
		physical_min_size(_hero_plate, 72.0, 96.0)
		physical_min_size(_mission_plate, 92.0, 70.0)
		physical_min_size(_deploy, 0.0, 76.0)
		for tab in _secondary.get_children():
			physical_min_size(tab as Control, 0.0, 64.0)
	elif cramped:
		physical_min_size(_mark, 168.0, 42.0)
		physical_min_size(_balance, 132.0, 0.0)
		physical_min_size(_hero_plate, 76.0, 96.0)
		physical_min_size(_mission_plate, 92.0, 70.0)
		physical_min_size(_deploy, 0.0, 88.0)
		for tab in _secondary.get_children():
			physical_min_size(tab as Control, 0.0, 64.0)
	else:
		physical_min_size(_mark, 150.0, 40.0)
		physical_min_size(_balance, 150.0, 0.0)
		physical_min_size(_hero_plate, 84.0, 112.0)
		physical_min_size(_mission_plate, 100.0, 76.0)
		physical_min_size(_deploy, 0.0, 96.0)
		for tab in _secondary.get_children():
			physical_min_size(tab as Control, 0.0, 68.0)

	# The character's box. Landscape gives it a share of the width so the cards
	# and the dock keep a readable column; portrait gives it the height that is
	# left, with a floor so it is never a sliver.
	if landscape:
		_cards.custom_minimum_size.x = px(300.0 if compact else 340.0)
		_dock.custom_minimum_size.x = px(300.0 if compact else 360.0)
		_stage.custom_minimum_size = Vector2(0.0, px(120.0))
		_cards.size_flags_vertical = Control.SIZE_FILL
		# The primary action belongs in the bottom thumb arc, not at the top of
		# the column: Apex's READY bar and Free Fire's start tile are both
		# bottom-anchored, and DEPLOY was drawing level with the operative's
		# shoulder.
		_dock.size_flags_vertical = Control.SIZE_SHRINK_END
	else:
		_cards.custom_minimum_size.x = 0.0
		_dock.custom_minimum_size.x = 0.0
		_cards.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_dock.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_stage.custom_minimum_size = Vector2(
			0.0, px(80.0 if cramped else (140.0 if compact else 220.0))
		)

	# Three cells share a row on a desktop; a phone gets one column, because two
	# leave a lone third and "RUNS COMPLETED  0" then wraps its figure onto the
	# next line -- the number orphaned in the margin of the row below it.
	var dock_width := width if not landscape else maxf(width * 0.4, 280.0)
	_numbers.columns = 1 if dock_width < 620.0 else 3

	# Copy that gives way on a short screen. Every one of these is a restatement
	# of something still on the screen: the role is the card above the name, the
	# brief is the WORLD card, the loadout is the three cards themselves.
	_hero_role.visible = not cramped
	_mission_caption.visible = not cramped
	# The brief is the WORLD card's paragraph. On a phone the theatre's *name*
	# is the information; the sentence is what pays for the character's height.
	_mission_brief.visible = not (cramped or (compact and not landscape))
	_limit_lines(_mission_brief, 2)
	_loadout.visible = not (cramped or compact or short_landscape)
	# The record is the last thing a player reads and the first thing that goes
	# when the dock has to fit: the profile line duplicates the counts under it.
	_rank_line.visible = not compact
	# The operative card already says FIELD READY, so the header's copy of it is
	# the first thing to go when the bar has to share 390 px with the wordmark
	# and the wallet.
	_status_label.visible = width >= 560.0 and not cramped
	_deploy_chip.visible = not cramped
	_limit_lines(_deploy_caption, 1)

	if is_instance_valid(_showcase) and _showcase.has_model():
		_showcase.frame_to_fill(SHOWCASE_FILL, 0.04)
	_apply_armory_and_settings_sizes()


func _apply_armory_and_settings_sizes() -> void:
	# The armory and settings panels are sized in physical pixels too: they are
	# lists of 56 px rows, and a panel authored in canvas units would be a third
	# of that on a phone.
	_armory.custom_minimum_size = Vector2(px(minf(physical_size().x * 0.92, 470.0)), px(470.0))
	_settings.custom_minimum_size = Vector2(px(minf(physical_size().x * 0.94, 560.0)), px(560.0))
	enforce_font_floor(_armory, _stretch)
	enforce_font_floor(_settings, _stretch)
	_centre(_armory)
	_centre(_settings)


func _on_resized() -> void:
	relayout()
	_orient_nodes([_mark, _hero_plate, _mission_plate])
	_apply_orientation()
	_apply_density()


func _centre(panel: Control) -> void:
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = (size - panel.size) * 0.5


# --- actions ---------------------------------------------------------------- #


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


# --- naming ----------------------------------------------------------------- #


## The theatre's own blurb, cut to its first sentence. The WORLD screen prints
## the whole paragraph; a lobby line is a reminder of where you are going.
func _first_sentence(text: String) -> String:
	var trimmed := text.strip_edges()
	var stop := trimmed.find(".")
	if stop <= 0:
		return trimmed
	return trimmed.substr(0, stop)


## Heroes and worlds have no *numeric* model -- there is no per-hero health or
## speed -- but they do have a name, and it lives in the registry exactly as a
## weapon's does. Reading it from there instead of typing it out here is what
## stops the lobby calling the loadout something the HERO and WORLD cards do not.
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
## the selection card prints, so the lobby cannot call it something else.
func _weapon_name(weapon_id: StringName) -> String:
	var definition := WeaponDefinition.load_definition(weapon_id)
	if definition != null and not definition.display_name.strip_edges().is_empty():
		return definition.display_name.to_upper()
	return String(weapon_id).to_upper()
