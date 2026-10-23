## The lobby's shared chrome: one dock across every lobby page.
##
## Before this existed each stage drew its own header, so DASHBOARD had a
## wordmark and a wallet chip, HERO had a BACK button and a heading, and WORLD
## had neither -- three different top bars on one journey, and the empty band
## above the page content is exactly what a player reads as "not finished".
##
## The dock therefore carries what a lobby must always answer, on every page:
##
##   * where am I        -- the wordmark, and which of HOME / OPERATIVE / WORLD
##                          is live (amber edge, bright icon, others at 60 %);
##   * who am I         -- the operative plate: portrait, name, ready state;
##   * what do I have   -- the two figures the save file actually stores:
##                          battle points and completed runs, each with an icon
##                          and a numeral. Nothing here is invented: a third
##                          currency would be decoration lying about the
##                          profile;
##   * where do I go    -- the gear, which opens settings over any lobby page.
##
## Sizes are authored in *physical* pixels through `MenuStage.physical_min_size`
## and re-authored on every resize, so the same dock is 56 px tall on a phone
## held upright and 64 px on a desktop, not "whatever the theme happened to use
## at 1280x720".
class_name LobbyChrome
extends RefCounted

signal navigate(stage_name: StringName)
signal settings_requested

const TAB_HOME := &"HOME"
const TAB_OPERATIVE := &"OPERATIVE"
const TAB_WORLD := &"WORLD"

## tab id -> [label, icon]
const TABS := {
	TAB_HOME: ["HOME", "house"],
	TAB_OPERATIVE: ["OPERATIVE", "shield"],
	TAB_WORLD: ["THEATRE", "target"],
}

## Compressed below this physical width the tabs keep their icons and lose
## their words: a dock whose labels are clipped is worse than one that reads as
## a row of glyphs, and the glyphs are distinct.
const LABEL_MIN_WIDTH := 560.0

var bar: AegisPanel
var row: HBoxContainer
var _stage: MenuStage
var _active: StringName
var _tabs: Array[AegisButton] = []
var _labels: Array[Label] = []
var _nav: HBoxContainer
var _plate: HBoxContainer
var _plate_state: Label
var _balance_chip: AegisPanel
var _balance_value: Label
var _runs_chip: AegisPanel
var _runs_value: Label
var _avatar: TextureRect
var _with_settings := true


## `with_settings` is false on pages that do not own the settings overlay: a
## gear that does nothing is worse than no gear, and DASHBOARD is where the
## overlay lives.
static func build(
	stage: MenuStage, active_tab: StringName, with_settings: bool = true
) -> LobbyChrome:
	var chrome := LobbyChrome.new()
	chrome._stage = stage
	chrome._active = active_tab
	chrome._with_settings = with_settings
	chrome._build()
	chrome.set_active(active_tab)
	return chrome


func _build() -> void:
	bar = AegisPanel.new()
	bar.name = &"LobbyDock"
	bar.accent_side = "top"
	bar.accent_color = AegisTokens.ACCENT
	bar.surface_alpha = 0.94
	bar.show_brackets = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	row = HBoxContainer.new()
	row.name = &"LobbyDockRow"
	row.add_theme_constant_override("separation", 0)
	bar.add_child(row)

	_build_wordmark()
	_build_nav()
	_build_resources()
	_build_plate()
	_build_settings()
	_apply_density()


func _build_wordmark() -> void:
	var mark := TextureRect.new()
	mark.name = &"DockWordmark"
	mark.texture = _stage.try_texture("res://assets/ui/logo_wordmark.png")
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_stage.physical_min_size(mark, 168.0, 40.0)
	row.add_child(mark)
	row.add_child(_spacer(16.0))


func _build_nav() -> void:
	_nav = HBoxContainer.new()
	_nav.name = &"DockNav"
	_nav.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_stage.physical_separation(_nav, 4.0)
	for tab_id in [TAB_HOME, TAB_OPERATIVE, TAB_WORLD]:
		var spec: Array = TABS[tab_id]
		var button := AegisButton.new()
		button.name = "DockTab%s" % String(tab_id).capitalize()
		button.text = ""
		button.icon = AegisTheme.icon(spec[1], true)
		button.expand_icon = false
		button.focus_mode = Control.FOCUS_ALL
		button.tooltip_text = spec[0]
		button.set_meta("tab_id", tab_id)
		button.add_theme_constant_override("icon_max_width", 22)
		button.pressed.connect(_on_tab_pressed.bind(tab_id))
		AegisTheme.set_button_variant(button, "ghost")
		_nav.add_child(button)
		_tabs.append(button)
	row.add_child(_nav)
	row.add_child(_spacer(16.0))


func _build_resources() -> void:
	_balance_chip = _make_chip(&"DockBalance", "trophy", AegisTokens.ACCENT)
	_balance_value = _balance_chip.get_meta("value_label")
	_runs_chip = _make_chip(&"DockRuns", "chart-bar", AegisTokens.INFO)
	_runs_value = _runs_chip.get_meta("value_label")
	row.add_child(_balance_chip)
	row.add_child(_runs_chip)
	row.add_child(_spacer(12.0))


func _make_chip(node_name: StringName, icon_name: String, tint: Color) -> AegisPanel:
	var chip := AegisPanel.new()
	chip.name = node_name
	chip.show_brackets = false
	chip.surface_alpha = 0.92
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 0)
	chip.add_child(line)
	var glyph := TextureRect.new()
	glyph.texture = AegisTheme.icon(icon_name, true)
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.modulate = tint
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_stage.physical_min_size(glyph, 18.0, 18.0)
	line.add_child(glyph)
	line.add_child(_spacer(8.0))
	var value := _stage.make_label("0", "label", AegisTokens.INK)
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	value.add_theme_constant_override("outline_size", 0)
	line.add_child(value)
	chip.set_meta("value_label", value)
	return chip


func _build_plate() -> void:
	_plate = HBoxContainer.new()
	_plate.name = &"DockProfile"
	_plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_stage.physical_separation(_plate, 8.0)
	_avatar = TextureRect.new()
	_avatar.texture = _stage.try_texture("res://assets/ui/portrait_hero.png")
	_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_stage.physical_min_size(_avatar, 36.0, 36.0)
	_plate.add_child(_avatar)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var name_label := _stage.make_label("OPERATIVE", "label", AegisTokens.INK)
	_plate_state = _stage.make_label("FIELD READY", "label_s", AegisTokens.OK)
	text.add_child(name_label)
	text.add_child(_plate_state)
	_plate.add_child(text)
	row.add_child(_plate)
	row.add_child(_spacer(6.0))


func _build_settings() -> void:
	var gear := AegisButton.new()
	gear.name = &"DockSettings"
	gear.text = ""
	gear.icon = AegisTheme.icon("gear-six", true)
	gear.focus_mode = Control.FOCUS_ALL
	gear.tooltip_text = "SETTINGS"
	gear.add_theme_constant_override("icon_max_width", 20)
	gear.pressed.connect(func() -> void: settings_requested.emit())
	AegisTheme.set_button_variant(gear, "ghost")
	gear.name = &"DockSettings"
	gear.visible = _with_settings
	row.add_child(gear)


func _spacer(physical_width: float) -> Control:
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage.physical_min_size(spacer, physical_width, 0.0)
	spacer.custom_minimum_size.y = 0.0
	return spacer


func _on_tab_pressed(tab_id: StringName) -> void:
	if tab_id == _active:
		return
	navigate.emit(tab_id)


## Re-authored on every resize. `MenuStage._reapply_physical_sizes()` walks the
## tree and restores the `px_w`/`px_h` metadata, so this only has to switch the
## *shape* of the dock when the screen is too narrow for words.
func _apply_density() -> void:
	var width := _stage.physical_size().x
	var compact := width < LABEL_MIN_WIDTH
	# A phone in portrait cannot hold the wordmark, three tabs, two chips and a
	# profile: the runs chip and the plate's state line go first, then the tab
	# words. Nothing is removed from the *information* the dock carries -- the
	# runs figure is on the DASHBOARD record already -- only from the dock.
	_runs_chip.visible = width >= 720.0
	_plate_state.visible = not compact
	for tab in _tabs:
		if compact:
			tab.text = ""
		else:
			tab.text = str(TABS[tab.get_meta("tab_id")][0])
		tab.add_theme_font_override("font", AegisTheme.font(AegisTokens.FAMILY_UI_M))
		tab.add_theme_font_size_override("font_size", 15)
	_stage.physical_min_size(_tabs[0], 40.0 if compact else 96.0, 40.0 if compact else 44.0)
	for tab in _tabs:
		_stage.physical_min_size(tab, 40.0 if compact else 96.0, 40.0 if compact else 44.0)
	_stage.physical_min_size(_avatar, 30.0 if compact else 36.0, 30.0 if compact else 36.0)


func set_active(tab_id: StringName) -> void:
	_active = tab_id
	for tab in _tabs:
		var live: bool = tab.get_meta("tab_id") == tab_id
		tab.edge_active = live
		tab.modulate = Color(1, 1, 1, 1.0 if live else 0.55)
		tab.queue_redraw()


func refresh(progression: ProgressionService) -> void:
	if progression == null:
		return
	_balance_value.text = _thousands(progression.balance)
	_runs_value.text = _thousands(progression.completed_runs)
	var hero := HeroDefinition.load_definition(progression.selected_hero_id)
	if hero != null and not hero.display_name.is_empty():
		var label := _plate.get_child(1).get_child(0) as Label
		if label != null:
			label.text = hero.display_name.to_upper()
	_plate_state.text = "FIELD READY" if (hero == null or hero.field_ready) else "OFFLINE"
	_plate_state.add_theme_color_override(
		"font_color", AegisTokens.OK if (hero == null or hero.field_ready) else AegisTokens.INK_3
	)


static func _thousands(value: int) -> String:
	var digits := str(maxi(value, 0))
	var out := ""
	var count := 0
	for index in range(digits.length() - 1, -1, -1):
		out = digits[index] + out
		count += 1
		if count % 3 == 0 and index > 0:
			out = "," + out
	return out
