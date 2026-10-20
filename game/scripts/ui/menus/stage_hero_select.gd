## HERO SELECTION.
##
## One operative exists. The rig in `assets/characters/hero/` is the only
## skinned hero in the project, so one card is selectable and the rest are
## marked IN DEVELOPMENT rather than populated with invented names, invented
## portraits and invented stat blocks.
##
## The card carries no numeric stats on purpose. There is no hero data model --
## no per-hero health, speed or damage -- so any number printed here would be
## decoration that disagrees with gameplay. What the portrait shows is the
## concept art for the operative; docs/ART_DIRECTION.md §4 is explicit that the
## portrait is not the in-game model.
extends MenuStage

const HERO_PORTRAIT := "res://assets/ui/portrait_hero.png"

## The only id ProgressionService.HERO_IDS recognises.
const OPERATIVE_ID := &"exo_operative"
## How many slots the screen shows. Two are placeholders so the layout is not a
## single lonely card on a tablet; they are disabled, never selectable.
const LOCKED_SLOTS := 2

var _cards: Array[AegisButton] = []
var _summary: Label
var _continue: AegisButton
var _selected := OPERATIVE_ID


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(make_backdrop("res://assets/ui/dashboard_bg.jpg"))
	var scrim := ColorRect.new()
	scrim.color = Color(AegisTokens.VOID, 0.58)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	var column := VBoxContainer.new()
	physical_separation(column, 14)
	make_margin().add_child(column)

	column.add_child(card_line("SELECT OPERATIVE", "display_l", AegisTokens.INK))
	_summary = card_line("", "label", AegisTokens.INK_2)
	column.add_child(_summary)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	# One card per row: three 240 px cards side by side need 752 px, and on a
	# 390 px screen that pushed every label on the screen to twice the display
	# width. A vertical list scrolls instead of overflowing.
	var list := VBoxContainer.new()
	physical_separation(list, 12)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	list.add_child(_build_operative_card())
	for index in range(LOCKED_SLOTS):
		list.add_child(_build_locked_card(index))

	var footer := HBoxContainer.new()
	physical_separation(footer, 12)
	column.add_child(footer)

	var back := make_button("BACK", "ghost", "Return to the dashboard")
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	physical_min_size(back, 0.0, 56.0)
	back.pressed.connect(func() -> void: completed.emit(&"DASHBOARD", {}))
	footer.add_child(back)

	_continue = make_button("CONTINUE", "primary", "Choose a weapon")
	_continue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	physical_min_size(_continue, 0.0, 56.0)
	_continue.pressed.connect(_on_continue_pressed)
	footer.add_child(_continue)

	resized.connect(_on_resized)
	relayout()


func enter(_stage_payload: Dictionary) -> void:
	apply_safe_margins(_margin)
	_selected = OPERATIVE_ID
	_on_resized()
	_refresh()


func refresh_profile() -> void:
	_refresh()


func _refresh() -> void:
	_summary.text = "1 OPERATIVE FIELD READY · %d IN DEVELOPMENT" % LOCKED_SLOTS
	for card in _cards:
		var id := StringName(str(card.get_meta("hero_id", "")))
		var selectable := id == OPERATIVE_ID
		card.disabled = not selectable
		card.edge_active = selectable
		card.set_pressed_no_signal(selectable)


func _build_operative_card() -> Control:
	var card := AegisButton.new()
	card.name = "OperativeCard"
	card.button_group = ButtonGroup.new()
	card.set_meta("hero_id", String(OPERATIVE_ID))
	card.toggle_mode = true
	card.focus_mode = Control.FOCUS_ALL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	physical_min_size(card, 0.0, 190.0)
	card.tooltip_text = "Exo Operative — field ready"
	card.pressed.connect(_on_card_pressed.bind(OPERATIVE_ID))
	AegisTheme.set_button_variant(card, "round")

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	physical_separation(row, 14)
	card.add_child(row)

	var portrait := TextureRect.new()
	portrait.texture = try_texture(HERO_PORTRAIT)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	physical_min_size(portrait, 130.0, 170.0)
	row.add_child(portrait)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	physical_separation(column, 6)
	row.add_child(column)

	column.add_child(card_line("EXO OPERATIVE", "title", AegisTokens.INK))
	column.add_child(
		card_line(
			(
				"The operative fielded by the AEGIS training programme. Concept art"
				+ " shown; the playable model is the rig measured in the hero"
				+ " visibility report."
			),
			"body_s",
			AegisTokens.INK_2
		)
	)
	column.add_child(card_line("STATUS  FIELD READY", "label_s", AegisTokens.OK))
	_cards.append(card)
	return card


## A placeholder slot, laid out like the real card so the screen does not look
## broken. Disabled and unlabelled beyond "IN DEVELOPMENT" so it cannot be
## mistaken for a hero the player nearly has.
func _build_locked_card(index: int) -> Control:
	var card := AegisButton.new()
	card.name = "LockedHeroCard%d" % index
	card.disabled = true
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	physical_min_size(card, 0.0, 110.0)
	AegisTheme.set_button_variant(card, "round")

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	physical_separation(row, 14)
	card.add_child(row)

	var slot := Control.new()
	physical_min_size(slot, 130.0, 86.0)
	row.add_child(slot)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	column.add_child(card_line("SLOT %02d" % (index + 2), "label", AegisTokens.LINE_HI))
	column.add_child(card_line("IN DEVELOPMENT", "title", AegisTokens.INK_3))
	return card


func _on_card_pressed(hero_id: StringName) -> void:
	var progression := progression_service()
	if progression == null:
		return
	progression.select_hero(hero_id)
	Sfx.play_ui(&"ui_click")
	_refresh()


func _on_continue_pressed() -> void:
	var progression := progression_service()
	if progression != null:
		progression.select_hero(_selected)
	completed.emit(&"WEAPON", {})


func _on_resized() -> void:
	relayout()
