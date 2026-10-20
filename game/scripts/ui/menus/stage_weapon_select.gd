## WEAPON SELECTION.
##
## Every number printed here is read off the WeaponDefinition resource at
## runtime -- damage, fire rate, magazine size, reload, range, splash and chain
## -- so the screen cannot drift from the weapon the player fires. Locked
## weapons are disabled and priced from ProgressionService.COSTS; unlocking
## happens in the Armory, which is the single place that spends Battle Points.
extends MenuStage

const DEFINITIONS := {
	&"pulse_rifle": "res://resources/weapons/pulse_rifle.tres",
	&"nova_launcher": "res://resources/weapons/nova_launcher.tres",
	&"arc_shooter": "res://resources/weapons/arc_shooter.tres",
}
const PLATES := {
	&"pulse_rifle": "res://assets/ui/weapon_pulse_rifle.png",
	&"nova_launcher": "res://assets/ui/weapon_nova_launcher.png",
	&"arc_shooter": "res://assets/ui/weapon_arc_shooter.png",
}
const ORDER: Array[StringName] = [&"pulse_rifle", &"nova_launcher", &"arc_shooter"]

var _cards: Dictionary = {}
var _summary: Label
var _continue: AegisButton
var _detail: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(make_backdrop("res://assets/ui/dashboard_bg.jpg"))
	var scrim := ColorRect.new()
	scrim.color = Color(AegisTokens.VOID, 0.6)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	var column := VBoxContainer.new()
	physical_separation(column, 14)
	make_margin().add_child(column)

	var heading := card_line("SELECT WEAPON", "display_l", AegisTokens.INK)
	column.add_child(heading)
	_summary = card_line("", "label", AegisTokens.ACCENT)
	column.add_child(_summary)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	var list := VBoxContainer.new()
	physical_separation(list, 12)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var group := ButtonGroup.new()
	for weapon_id in ORDER:
		var card := _build_card(weapon_id, group)
		_cards[weapon_id] = card
		list.add_child(card)

	_detail = card_line("", "body_s", AegisTokens.INK_2)
	column.add_child(_detail)

	var footer := HBoxContainer.new()
	physical_separation(footer, 12)
	column.add_child(footer)

	var back := make_button("BACK", "ghost", "Return to operative selection")
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	physical_min_size(back, 0.0, 56.0)
	back.pressed.connect(func() -> void: completed.emit(&"HERO", {}))
	footer.add_child(back)

	_continue = make_button("CONTINUE", "primary", "Choose a world")
	_continue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	physical_min_size(_continue, 0.0, 56.0)
	_continue.pressed.connect(func() -> void: completed.emit(&"WORLD", {}))
	footer.add_child(_continue)

	resized.connect(_on_resized)
	relayout()


func enter(_stage_payload: Dictionary) -> void:
	apply_safe_margins(_margin)
	_on_resized()
	_refresh()


func refresh_profile() -> void:
	_refresh()


func _definition(weapon_id: StringName) -> WeaponDefinition:
	return load(DEFINITIONS[weapon_id]) as WeaponDefinition


func _build_card(weapon_id: StringName, group: ButtonGroup) -> Control:
	var card := AegisButton.new()
	card.name = "%sCard" % String(weapon_id).to_pascal_case()
	card.button_group = group
	card.toggle_mode = true
	card.focus_mode = Control.FOCUS_ALL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	physical_min_size(card, 0.0, 132.0)
	card.set_meta("weapon_id", String(weapon_id))
	card.pressed.connect(_on_card_pressed.bind(weapon_id))
	AegisTheme.set_button_variant(card, "round")

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	physical_separation(row, 14)
	card.add_child(row)

	var plate := TextureRect.new()
	plate.texture = try_texture(PLATES[weapon_id])
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	physical_min_size(plate, 150.0, 100.0)
	row.add_child(plate)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	physical_separation(column, 4)
	row.add_child(column)

	var definition := _definition(weapon_id)
	column.add_child(card_line(definition.display_name.to_upper(), "title", AegisTokens.INK))
	column.add_child(card_line(definition.role_description, "caption", AegisTokens.INK_2))

	var stats := card_line(_stat_line(definition), "mono_s", AegisTokens.INFO)
	stats.set_meta("stat_line", true)
	column.add_child(stats)

	var state := card_line("", "label_s", AegisTokens.OK)
	state.set_meta("state_line", true)
	column.add_child(state)
	return card


## Real values straight off the resource. `fire_rate` is shots per second in the
## definition, so it is printed as such rather than being converted into a
## number the file does not contain.
func _stat_line(definition: WeaponDefinition) -> String:
	var parts := [
		"DMG %s" % _trim(definition.damage),
		"RATE %s/s" % _trim(definition.fire_rate),
		"MAG %d" % definition.magazine_size,
		"RELOAD %ss" % _trim(definition.reload_seconds),
		"RNG %sm" % _trim(definition.max_range),
	]
	if definition.splash_damage > 0.0:
		parts.append(
			"SPLASH %s / %sm" % [_trim(definition.splash_damage), _trim(definition.splash_radius)]
		)
	if definition.chain_count > 0:
		parts.append("CHAIN %d" % definition.chain_count)
	return "  ·  ".join(parts)


func _trim(value: float) -> String:
	var text := "%.2f" % value
	while text.ends_with("0") and text.contains("."):
		text = text.substr(0, text.length() - 1)
	return text.substr(0, text.length() - 1) if text.ends_with(".") else text


func _refresh() -> void:
	var progression := progression_service()
	if progression == null:
		return
	var owned := 0
	for weapon_id in ORDER:
		var unlocked := progression.is_unlocked(weapon_id)
		if unlocked:
			owned += 1
		var card: AegisButton = _cards[weapon_id]
		var selected := progression.selected_weapon_id == weapon_id
		card.disabled = not unlocked
		card.edge_active = selected
		card.set_pressed_no_signal(selected)
		var state: Label = _find_meta(card, "state_line")
		if state == null:
			continue
		if unlocked:
			state.text = "EQUIPPED" if selected else "OWNED · TAP TO EQUIP"
			state.add_theme_color_override("font_color", AegisTokens.OK)
		else:
			var cost := progression.unlock_cost(weapon_id)
			state.text = "LOCKED · %d BP · UNLOCK IN ARMORY" % cost
			state.add_theme_color_override("font_color", AegisTokens.ACCENT)
	_summary.text = (
		"BATTLE POINTS  %d  ·  %d / %d WEAPONS" % [progression.balance, owned, ORDER.size()]
	)
	_detail.text = (
		"Battle Points are earned by defeating waves. Unlocks are permanent and "
		+ "stored in your profile."
	)


func _find_meta(root: Node, key: String) -> Label:
	if root.has_meta(key):
		return root as Label
	for child in root.find_children("*", "Label", true, false):
		if child.has_meta(key):
			return child
	return null


func _on_card_pressed(weapon_id: StringName) -> void:
	var progression := progression_service()
	if progression == null or not progression.select_weapon(weapon_id):
		return
	Sfx.play_ui(&"ui_click")
	_refresh()


func _on_resized() -> void:
	relayout()
