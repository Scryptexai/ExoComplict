## WEAPON SELECTION — a 3D showcase of the rifle the player will actually hold.
##
## The cards this replaces quoted the right numbers from the right resources, but
## the weapon itself was a 110 px plate. What a player equips here is
## `WeaponDefinition.model_scene`, and today all three definitions point at the
## same mesh: there is one rifle in this build. The showcase says that out loud
## instead of implying three silhouettes -- `showcase_smoke.gd` prints the count
## of distinct mesh files, and the screen shows the mesh the currently selected
## weapon will be held as.
##
## Layout follows the brief: the model is the subject, statistics sit beside it,
## and the primary action is a single CONTINUE at the bottom. There is no upgrade
## button, because this project has no upgrade system: a button that only changed
## a number on screen would be the exact lie the brief forbids.
extends MenuStage

const ShowcaseViewportScript = preload("res://scripts/ui/widgets/showcase_viewport.gd")

## Weapon plates for the carousel. UI art, not models: they exist so the row is
## recognisable at a glance. Kept here rather than in the definition because they
## are decoration, and `ui_art_smoke` checks every path declared in a stage that
## is a real file.
const PLATE_PATHS := {
	&"pulse_rifle": "res://assets/ui/weapon_pulse_rifle.png",
	&"nova_launcher": "res://assets/ui/weapon_nova_launcher.png",
	&"arc_shooter": "res://assets/ui/weapon_arc_shooter.png",
}

## Model length in showcase metres. The rifle's measured `barrel_length_m` is
## 0.9995, so this is the mesh at roughly life size, seen close.
const SHOWCASE_LENGTH := 1.15

var _cards: Array[AegisButton] = []
var _showcase: ShowcaseViewport
var _carousel: ScrollContainer
var _name_label: Label
var _class_label: Label
var _state_label: Label
var _stat_lines: Array[Label] = []
var _detail_label: Label
var _continue: AegisButton
var _selected := WeaponDefinition.DEFAULT_WEAPON_ID

var _stack: VBoxContainer
var _header: HBoxContainer
var _body: HBoxContainer
var _col_model: VBoxContainer
var _col_info: VBoxContainer
var _showcase_holder: Control
var _panel: AegisPanel
var _carousel_wrap: VBoxContainer
var _heading: Label
var _landscape_built := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(make_backdrop("res://assets/ui/dashboard_bg.jpg"))
	var scrim := ColorRect.new()
	scrim.color = Color(AegisTokens.VOID, 0.76)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	_stack = VBoxContainer.new()
	physical_separation(_stack, 10)
	make_margin().add_child(_stack)

	_build_header()
	_body = HBoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	physical_separation(_body, 14)
	_stack.add_child(_body)

	_col_model = VBoxContainer.new()
	_col_model.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_col_model.size_flags_vertical = Control.SIZE_EXPAND_FILL
	physical_separation(_col_model, 8)
	_body.add_child(_col_model)

	_col_info = VBoxContainer.new()
	_col_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	physical_separation(_col_info, 8)
	_body.add_child(_col_info)

	_build_carousel()
	_build_showcase()
	_build_panel()
	_build_actions()

	_connect_resized(_on_resized)
	relayout()


func enter(_stage_payload: Dictionary) -> void:
	apply_safe_margins(_margin)
	var progression := progression_service()
	_selected = (
		progression.selected_weapon_id
		if progression != null
		else WeaponDefinition.DEFAULT_WEAPON_ID
	)
	if not WeaponDefinition.DEFINITION_PATHS.has(_selected):
		_selected = WeaponDefinition.DEFAULT_WEAPON_ID
	_on_resized()
	_refresh()
	_present_selected(true)


func exit() -> void:
	if is_instance_valid(_showcase):
		_showcase.clear_model()


func refresh_profile() -> void:
	_refresh()


# --- construction ----------------------------------------------------------- #


func _build_header() -> void:
	_header = HBoxContainer.new()
	physical_separation(_header, 12)
	_stack.add_child(_header)

	var back := make_button("BACK", "ghost", "Return to operative selection")
	physical_min_size(back, 120.0, AegisTokens.MIN_TOUCH_PX)
	back.pressed.connect(func() -> void: completed.emit(&"HERO", {}))
	_header.add_child(back)

	_heading = make_label("SELECT WEAPON", "display_m", AegisTokens.INK)
	_heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_child(_heading)

	_state_label = make_label("", "label", AegisTokens.OK)
	_state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_header.add_child(_state_label)


func _build_carousel() -> void:
	_carousel_wrap = VBoxContainer.new()
	physical_separation(_carousel_wrap, 4)
	_col_model.add_child(_carousel_wrap)

	_carousel = ScrollContainer.new()
	_carousel.name = &"WeaponCarousel"
	_carousel.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_carousel.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_carousel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	physical_min_size(_carousel, 0.0, 72.0)
	_carousel_wrap.add_child(_carousel)
	# Register the carousel with MenuStage so a thumb swipe scrolls it; the base
	# class only knows the scroll container it built itself.
	_card_scroll = _carousel

	var row := HBoxContainer.new()
	physical_separation(row, 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_carousel.add_child(row)

	var group := ButtonGroup.new()
	for definition in WeaponDefinition.load_all_definitions():
		row.add_child(_build_chip(definition, group))


## One small plate per weapon, carrying the registry id the data-source test
## reads. The plate is how a player recognises a weapon; the model is how they
## judge it.
func _build_chip(definition: WeaponDefinition, group: ButtonGroup) -> Control:
	var chip := AegisButton.new()
	chip.name = "%sChip" % String(definition.weapon_id).to_pascal_case()
	chip.button_group = group
	chip.toggle_mode = true
	chip.focus_mode = Control.FOCUS_ALL
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.tooltip_text = definition.display_name
	chip.set_meta("weapon_id", String(definition.weapon_id))
	_size_both(chip, Vector2(88.0, 64.0), Vector2(88.0, 64.0))
	AegisTheme.set_button_variant(chip, "round")
	chip.pressed.connect(_on_chip_pressed.bind(definition.weapon_id))
	_cards.append(chip)

	var plate := TextureRect.new()
	plate.texture = try_texture(PLATE_PATHS.get(definition.weapon_id, ""))
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(plate)

	# The chip is a plate; the name and state sit under it, where there is room
	# for them. A locked weapon is still named and priced here -- a player is
	# allowed to see what they are saving for -- but the chip is disabled, so it
	# cannot be equipped.
	var item := VBoxContainer.new()
	physical_separation(item, 2)
	item.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var name_label := make_label(definition.display_name.to_upper(), "label_s", AegisTokens.INK)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.clip_text = true
	item.add_child(name_label)
	var state := make_label("", "caption", AegisTokens.INK_3)
	state.name = "StateLabel"
	state.set_meta("weapon_state", String(definition.weapon_id))
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state.autowrap_mode = TextServer.AUTOWRAP_OFF
	state.clip_text = true
	item.add_child(state)

	# The chip and its caption travel together as one carousel item.
	var holder := VBoxContainer.new()
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	physical_separation(holder, 2)
	holder.add_child(chip)
	holder.add_child(item)
	chip.set_meta("weapon_item", holder)
	return holder


func _build_showcase() -> void:
	_showcase_holder = Control.new()
	_showcase_holder.name = &"ShowcaseHolder"
	_showcase_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_showcase_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_showcase_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_col_model.add_child(_showcase_holder)

	_showcase = ShowcaseViewportScript.new()
	_showcase.name = &"WeaponShowcase"
	_showcase.set_anchors_preset(Control.PRESET_FULL_RECT)
	_showcase_holder.add_child(_showcase)


func _build_panel() -> void:
	_panel = AegisPanel.new()
	_panel.interactive = false
	_panel.accent_side = "left"
	_panel.accent_color = AegisTokens.ACCENT
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_col_info.add_child(_panel)

	var column := VBoxContainer.new()
	physical_separation(column, 6)
	_panel.add_child(column)

	_class_label = make_label("", "label", AegisTokens.INK_3)
	_class_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_class_label.clip_text = true
	column.add_child(_class_label)

	_name_label = make_label("", "title", AegisTokens.INK)
	_name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_name_label.clip_text = true
	column.add_child(_name_label)

	# One Label per stat group, single-line with an ellipsis. Every value here is
	# read from the same resource the weapon fires from, and the `stat_line`
	# marker is what `data_source_smoke` matches on -- it reads them all.
	for index in range(3):
		var line := make_label("", "mono_s", AegisTokens.INFO if index == 0 else AegisTokens.INK_2)
		line.autowrap_mode = TextServer.AUTOWRAP_OFF
		line.clip_text = true
		line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		line.set_meta("stat_line", true)
		column.add_child(line)
		_stat_lines.append(line)

	_detail_label = make_label("", "caption", AegisTokens.INK_3)
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_detail_label.clip_text = true
	_detail_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(_detail_label)


func _build_actions() -> void:
	_continue = make_button("CONTINUE", "primary", "Choose a theatre")
	physical_min_size(_continue, 0.0, AegisTokens.MIN_TOUCH_PX)
	_continue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_continue.pressed.connect(_on_continue_pressed)
	_col_info.add_child(_continue)


# --- state ------------------------------------------------------------------ #


func _refresh() -> void:
	var progression := progression_service()
	for card in _cards:
		var id := StringName(str(card.get_meta("weapon_id", "")))
		var unlocked := progression != null and progression.is_unlocked(id)
		var selected := id == _selected
		# A locked weapon can be inspected -- a player is allowed to see what they
		# are saving for -- but it cannot be equipped, so selecting it does not
		# write to the profile and CONTINUE reports it.
		card.edge_active = selected
		card.set_pressed_no_signal(selected)
		# Locked content is disabled, not merely labelled: the model and numbers
		# stay visible, the control cannot equip it.
		card.disabled = not unlocked
	for child in find_children("*", "Label", true, false):
		var label := child as Label
		if label == null or not label.has_meta("weapon_state"):
			continue
		var id := StringName(str(label.get_meta("weapon_state")))
		if progression == null:
			label.text = ""
		elif progression.is_unlocked(id):
			label.text = "EQUIPPED" if progression.selected_weapon_id == id else "OWNED"
		else:
			label.text = "%d BP" % progression.unlock_cost(id)
	_continue.disabled = progression == null or not progression.is_unlocked(_selected)
	_continue.text = "CONTINUE" if not _continue.disabled else "LOCKED IN ARMORY"


func _present_selected(reveal: bool) -> void:
	var definition := WeaponDefinition.load_definition(_selected)
	if definition == null or not is_instance_valid(definition.model_scene):
		_showcase.clear_model()
		return
	var already := _showcase.model_path() == definition.model_scene.resource_path
	if not already:
		(
			_showcase
			. present(
				definition.model_scene,
				{
					# A rifle is longer than it is tall: fit on its longest axis, not
					# its height, or the barrel leaves the frame.
					"fit_axis": 2,
					"height": SHOWCASE_LENGTH,
					# The mesh is authored barrel down -Z with the grip at the origin;
					# a quarter turn shows profile and stock without hiding the barrel.
					"yaw": 148.0,
					# No clips: rifle.glb has no animations (measured, not assumed).
					"clips": [],
				}
			)
		)
		_showcase.frame_model(SHOWCASE_LENGTH, true)
		if not reveal:
			_showcase.skip_reveal()
	_name_label.text = definition.display_name.to_upper()
	_class_label.text = _class_of(_selected)
	var progression := progression_service()
	var unlocked := progression != null and progression.is_unlocked(_selected)
	if unlocked:
		var equipped := progression != null and progression.selected_weapon_id == _selected
		_state_label.text = "EQUIPPED" if equipped else "OWNED"
		_state_label.add_theme_color_override("font_color", AegisTokens.OK)
	else:
		var cost := progression.unlock_cost(_selected) if progression != null else 0
		_state_label.text = "LOCKED · %d BP" % cost
		_state_label.add_theme_color_override("font_color", AegisTokens.ACCENT)
	var numbers := _stat_groups(definition)
	for index in range(_stat_lines.size()):
		_stat_lines[index].text = numbers[index] if index < numbers.size() else ""
	_detail_label.text = _detail_of(_selected)


## Weapon "class" is not a field in `WeaponDefinition`: it has no such concept,
## and inventing one would be a label with nothing behind it. What the resource
## does say is how it delivers damage, so that is what is printed.
func _class_of(weapon_id: StringName) -> String:
	var definition := WeaponDefinition.load_definition(weapon_id)
	if definition == null:
		return ""
	if definition.chain_count > 0:
		return "ENERGY · CHAIN"
	if definition.splash_damage > 0.0:
		return "EXPLOSIVE · AREA"
	return "ENERGY · SINGLE TARGET"


## What the resource itself can say about handling, plus the price the service
## charges for this weapon -- read from the service, never typed here.
func _detail_of(weapon_id: StringName) -> String:
	var definition := WeaponDefinition.load_definition(weapon_id)
	if definition == null:
		return ""
	var progression := progression_service()
	var cost := progression.unlock_cost(weapon_id) if progression != null else 0
	return "%s · %d BP" % [_class_of(weapon_id), cost]


## The same three groups the card version printed, each short enough for one
## line at this column width. Values come from the definition, never from here.
func _stat_groups(definition: WeaponDefinition) -> Array[String]:
	var groups: Array[String] = [
		(
			"DMG %s · RATE %s/s · MAG %d"
			% [_trim(definition.damage), _trim(definition.fire_rate), definition.magazine_size]
		),
		"RELOAD %ss · RNG %sm" % [_trim(definition.reload_seconds), _trim(definition.max_range)],
	]
	var extra: Array[String] = []
	if definition.splash_damage > 0.0:
		extra.append(
			"SPLASH %s / %sm" % [_trim(definition.splash_damage), _trim(definition.splash_radius)]
		)
	if definition.chain_count > 0:
		extra.append("CHAIN %d" % definition.chain_count)
	groups.append(" · ".join(extra) if not extra.is_empty() else "")
	return groups


func _trim(value: float) -> String:
	var text := "%.2f" % value
	while text.ends_with("0") and text.contains("."):
		text = text.substr(0, text.length() - 1)
	return text.substr(0, text.length() - 1) if text.ends_with(".") else text


# --- interaction ------------------------------------------------------------ #


func _on_chip_pressed(weapon_id: StringName) -> void:
	if weapon_id == _selected:
		return
	_selected = weapon_id
	Sfx.play_ui(&"ui_click")
	var progression := progression_service()
	# Equipping writes to the service, which is what DEPLOY reads. A locked weapon
	# is shown but not saved.
	if progression != null and progression.is_unlocked(weapon_id):
		progression.select_weapon(weapon_id)
	_refresh()
	_present_selected(true)


func _on_continue_pressed() -> void:
	var progression := progression_service()
	if progression == null or not progression.is_unlocked(_selected):
		return
	progression.select_weapon(_selected)
	completed.emit(&"WORLD", {})


# --- layout ----------------------------------------------------------------- #


func _on_resized() -> void:
	relayout()
	_orient_nodes(_cards)
	_apply_orientation()
	_apply_density()


func _apply_orientation() -> void:
	var landscape := is_landscape()
	if landscape == _landscape_built:
		return
	_landscape_built = landscape
	for block in [_carousel_wrap, _showcase_holder, _panel, _continue]:
		if block.get_parent() != null:
			block.get_parent().remove_child(block)
	if landscape:
		# Landscape: model left, everything readable right. A 390 px tall screen
		# cannot stack a carousel and a model above a panel.
		if _col_info.get_parent() != _body:
			_body.add_child(_col_info)
		_col_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_col_model.add_child(_carousel_wrap)
		_col_model.add_child(_showcase_holder)
		_col_info.add_child(_panel)
		_col_info.add_child(_continue)
	else:
		# Portrait: the model on top, the information panel and CONTINUE beneath.
		if _col_info.get_parent() == _body:
			_body.remove_child(_col_info)
		if _col_model.get_parent() == _body:
			_body.remove_child(_col_model)
		_stack.add_child(_col_model)
		_stack.add_child(_col_info)
		_col_model.add_child(_carousel_wrap)
		_col_model.add_child(_showcase_holder)
		_col_info.add_child(_panel)
		_col_info.add_child(_continue)
	# The columns are children of a different parent in portrait, so their sizing
	# flags have to follow.
	_col_model.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_col_model.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_col_info.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _apply_density() -> void:
	var short_screen := physical_size().y < (520.0 if is_landscape() else 760.0)
	_heading.text = "SELECT WEAPON" if is_landscape() or short_screen else "LOADOUT"
	physical_min_size(_carousel, 0.0, 64.0 if short_screen else 72.0)
	physical_separation(_stack, 6.0 if short_screen else 10.0)
	physical_separation(_col_model, 6.0 if short_screen else 8.0)
	physical_separation(_col_info, 6.0 if short_screen else 8.0)
