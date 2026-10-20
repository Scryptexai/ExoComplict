## WORLD SELECTION.
##
## One world exists: `scenes/worlds/neon_frontier.tscn`, the arena the game
## actually loads. The remaining slots are marked IN DEVELOPMENT. A launch
## button that looked playable but loaded nothing would be the exact failure
## this project is trying to avoid, so the placeholders are disabled and never
## hand an id to the preloader.
extends MenuStage

const WORLD_PLATE := "res://assets/ui/world_neon_frontier.jpg"
const FRONTIER_ID := &"neon_frontier"
const LOCKED_SLOTS := 2

var _cards: Array[AegisButton] = []
var _summary: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(make_backdrop(WORLD_PLATE))
	var scrim := ColorRect.new()
	scrim.color = Color(AegisTokens.VOID, 0.55)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	var column := VBoxContainer.new()
	physical_separation(column, 14)
	make_margin().add_child(column)

	column.add_child(make_label("SELECT THEATRE", "display_l", AegisTokens.INK))
	_summary = make_label("", "label", AegisTokens.ACCENT)
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
	list.add_child(_build_world_card(group))
	for index in range(LOCKED_SLOTS):
		list.add_child(_build_locked_card(index))

	var footer := HBoxContainer.new()
	physical_separation(footer, 12)
	column.add_child(footer)

	var back := make_button("BACK", "ghost", "Return to weapon selection")
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	physical_min_size(back, 0.0, 56.0)
	back.pressed.connect(func() -> void: completed.emit(&"WEAPON", {}))
	footer.add_child(back)

	var launch := make_button("LAUNCH", "primary", "Load the arena and start the run")
	launch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	physical_min_size(launch, 0.0, 56.0)
	launch.pressed.connect(_on_launch_pressed)
	footer.add_child(launch)

	resized.connect(_on_resized)
	relayout()


func enter(_stage_payload: Dictionary) -> void:
	apply_safe_margins(_margin)
	_on_resized()
	_refresh()


func refresh_profile() -> void:
	_refresh()


func _build_world_card(group: ButtonGroup) -> Control:
	var card := AegisButton.new()
	card.name = "NeonFrontierCard"
	card.button_group = group
	card.toggle_mode = true
	card.focus_mode = Control.FOCUS_ALL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	physical_min_size(card, 0.0, 168.0)
	card.set_meta("world_id", String(FRONTIER_ID))
	card.pressed.connect(_on_card_pressed.bind(FRONTIER_ID))
	AegisTheme.set_button_variant(card, "round")

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	physical_separation(row, 14)
	card.add_child(row)

	var plate := TextureRect.new()
	plate.texture = try_texture(WORLD_PLATE)
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	physical_min_size(plate, 240.0, 135.0)
	row.add_child(plate)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	physical_separation(column, 4)
	row.add_child(column)
	column.add_child(make_label("NEON FRONTIER", "title", AegisTokens.INK))
	var blurb := make_label(
		(
			"An open training arena with raised platforms and sightlines to the edge "
			+ "of the grid. Wave defence, exploration and the weapon range all run here."
		),
		"body_s",
		AegisTokens.INK_2
	)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(blurb)
	column.add_child(make_label("STATUS  OPEN", "label_s", AegisTokens.OK))

	_cards.append(card)
	return card


func _build_locked_card(index: int) -> Control:
	var card := AegisButton.new()
	card.name = "LockedWorldCard%d" % index
	card.disabled = true
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	physical_min_size(card, 0.0, 96.0)
	AegisTheme.set_button_variant(card, "round")

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(column)
	column.add_child(make_label("THEATRE %02d" % (index + 2), "label", AegisTokens.LINE_HI))
	column.add_child(make_label("IN DEVELOPMENT", "title", AegisTokens.INK_3))
	return card


func _refresh() -> void:
	var progression := progression_service()
	if progression == null:
		return
	var selected := progression.selected_world_id
	for card in _cards:
		var id := StringName(str(card.get_meta("world_id", "")))
		var is_selected := id == selected
		card.edge_active = is_selected
		card.set_pressed_no_signal(is_selected)
	_summary.text = "1 THEATRE OPEN · %d IN DEVELOPMENT" % LOCKED_SLOTS


func _on_card_pressed(world_id: StringName) -> void:
	var progression := progression_service()
	if progression == null:
		return
	progression.select_world(world_id)
	Sfx.play_ui(&"ui_click")
	_refresh()


func _on_launch_pressed() -> void:
	var progression := progression_service()
	if progression == null:
		return
	progression.select_world(progression.selected_world_id)
	# PRELOAD gets the gameplay scene path and the loadout it must honour. It
	# does the threaded load and the scene change itself.
	(
		completed
		. emit(
			&"PRELOAD",
			{
				"scene": "res://scenes/main.tscn",
				"title": "PREPARING DROP",
				"targets": ["res://scenes/main.tscn"],
				"weapon_id": String(progression.selected_weapon_id),
				"world_id": String(progression.selected_world_id),
			}
		)
	)


func _on_resized() -> void:
	relayout()
