## THEATRE SELECTION — a map, not a card list.
##
## The previous screen was a stack of 400 px cards in the middle of an empty
## page: the theatre art was a 132 px thumbnail, and two thirds of the screen
## was bare background. A world select is the one screen in a lobby whose
## subject *is* the artwork, so the art now fills the frame and the control is
## a small strip of theatre pins laid over it.
##
## What the screen answers, and where:
##
##   * which theatre is loaded -- the full-bleed plate, and its name at 40 px
##     over the bottom of the image, the way Free Fire's map banner reads;
##   * what is there          -- the chapter line and one sentence of framing,
##     both from the WorldDefinition, never a literal in this file;
##   * which others exist     -- a pin per theatre in the registry. A pin for a
##     theatre that cannot be launched is disabled and says IN DEVELOPMENT, so
##     the map can hold the whole roadmap without pretending any of it is
##     playable;
##   * what happens next      -- LAUNCH, the amber tile, at the bottom edge on a
##     phone and under the copy on a desktop.
##
## One world exists today: `scenes/worlds/neon_frontier.tscn`. The launch
## payload names `FrontEnd.GAMEPLAY_SCENE` rather than a third copy of the path,
## and `data_source_smoke.gd` walks the gameplay scene looking for the theatre
## each pin advertises.
extends MenuStage

## The map's pins. A pin is a Button, because that is the control a player
## presses; `world_id` rides on it as metadata, which is also what
## `data_source_smoke.gd` reads to prove every registry entry is offered.
var _pins: Array[AegisButton] = []
var _plate: TextureRect
var _title: Label
var _chapter: Label
var _brief: Label
var _status: Label
var _launch: AegisButton

var _stack: VBoxContainer
var _body: BoxContainer
var _side: HBoxContainer
var _map: Control
var _info: AegisPanel
var _info_text: VBoxContainer
## HBox on a wide screen, VBox on a phone: two container classes, because the
## direction is the class.
var _pin_row: Container
var _chrome: LobbyChrome
var _selected := &""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_build_backdrop())
	var scrim := ColorRect.new()
	# Light on purpose. The plate is the screen's subject; the old 0.55 scrim
	# over a thumbnail was two ways of hiding the same artwork.
	scrim.color = Color(AegisTokens.VOID, 0.34)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	_stack = VBoxContainer.new()
	physical_separation(_stack, 16)
	make_margin().add_child(_stack)

	_chrome = LobbyChrome.build(self, LobbyChrome.TAB_WORLD, false)
	_chrome.navigate.connect(_on_nav_requested)
	_stack.add_child(_chrome.bar)

	# Two explicit arrangements, the same way HERO does it: a `vertical` flag on
	# a container is not the same thing as the other container class, and the
	# landscape body kept stacking its children vertically -- the info panel drew
	# under the map, 400 px down an 844x390 screen.
	_body = VBoxContainer.new()
	_body.name = &"TheatreBody"
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	physical_separation(_body, 12)
	_stack.add_child(_body)

	_side = HBoxContainer.new()
	_side.name = &"TheatreSide"
	_side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	physical_separation(_side, 18)

	_build_map()
	_build_info()

	_connect_resized(_on_resized)
	relayout()
	reframe()


## The plate behind everything is the map's own horizon: darkened at the edges
## by the scrim above, and drifting a few pixels so the screen is alive without
## asking the GPU for a shader.
func _build_backdrop() -> TextureRect:
	_plate = TextureRect.new()
	_plate.name = &"TheatrePlate"
	# The plate is the first theatre's own art, read from the registry the pins
	# are built from, so the map cannot open on one horizon while its first pin
	# shows another. No path is spelled out in this file.
	var definitions := WorldDefinition.load_all_definitions()
	_plate.texture = (null if definitions.is_empty() else try_texture(definitions[0].plate_path))
	_plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	_plate.pivot_offset = Vector2.ZERO
	var drift := create_tween().set_loops()
	drift.tween_property(_plate, "scale", Vector2(1.03, 1.03), 9.0).set_trans(Tween.TRANS_SINE)
	drift.tween_property(_plate, "scale", Vector2(1.0, 1.0), 9.0).set_trans(Tween.TRANS_SINE)
	return _plate


## The pins sit in one row over the bottom of the plate. A row, not a card grid:
## the map has two theatres and will have six, and six 400 px cards is the exact
## layout this screen is replacing.
func _build_map() -> void:
	_map = Control.new()
	_map.name = &"TheatreMap"
	_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.clip_contents = true
	_body.add_child(_map)

	_pin_row = VBoxContainer.new()
	_pin_row.name = &"TheatrePins"
	physical_separation(_pin_row, 8)
	# In the stack, under the body, not floating inside the map: a pin laid out
	# against the bottom of an expanding box inherits that box's geometry, and on
	# an 844x390 landscape the body was taller than the screen, so both pins drew
	# at y=465. Normal flow cannot do that.
	_stack.add_child(_pin_row)

	var group := ButtonGroup.new()
	for definition in WorldDefinition.load_all_definitions():
		_pin_row.add_child(_build_pin(group, definition))


func _build_pin(group: ButtonGroup, definition: WorldDefinition) -> AegisButton:
	var pin := AegisButton.new()
	pin.name = "%sPin" % String(definition.world_id).to_pascal_case()
	pin.text = definition.display_name.to_upper()
	pin.set_meta("world_id", String(definition.world_id))
	pin.toggle_mode = true
	pin.button_group = group
	pin.alignment = HORIZONTAL_ALIGNMENT_LEFT
	pin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pin.focus_mode = Control.FOCUS_ALL
	pin.set_meta("aegis_role", "label")
	AegisTheme.set_button_variant(pin, "card")
	pin.pressed.connect(_on_pin_pressed.bind(definition.world_id))
	_pins.append(pin)
	return pin


func _build_info() -> void:
	_info = AegisPanel.new()
	_info.name = &"TheatreInfo"
	_info.accent_side = "left"
	_info.show_brackets = false
	_info.surface_alpha = 0.9
	_info.size_flags_vertical = Control.SIZE_SHRINK_END
	_body.add_child(_info)

	_info_text = VBoxContainer.new()
	physical_separation(_info_text, 8)
	_info.add_child(_info_text)

	_chapter = make_label("", "label", AegisTokens.ACCENT)
	_title = make_label("", "display_m", AegisTokens.INK)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_brief = make_label("", "body_s", AegisTokens.INK_2)
	_brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status = make_label("", "label_s", AegisTokens.OK)
	_launch = make_button("LAUNCH", "primary", "Drop into the selected theatre")
	_launch.pressed.connect(_on_launch_pressed)
	for node in [_chapter, _title, _brief, _status]:
		_info_text.add_child(node)
	_info_text.add_child(_launch)


## Portrait stacks the info under the map; landscape floats it beside the plate.
## The info panel is the only block with a fixed width, which is what makes the
## plate the thing that grows.
func reframe() -> void:
	var landscape := is_landscape()
	var height := physical_size().y
	if landscape:
		_reparent(_map, _side)
		_reparent(_info, _side)
		_reparent(_side, _body)
		_reparent(_pin_row, _stack)
		_info.size_flags_vertical = Control.SIZE_SHRINK_END
		physical_min_size(_info, 320.0, 0.0)
		_info.size_flags_horizontal = Control.SIZE_FILL
		physical_min_size(_map, 0.0, 0.0)
		_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_info_text.add_theme_constant_override("separation", 6)
		physical_min_size(_launch, 0.0, 64.0)
	else:
		_reparent(_map, _body)
		_reparent(_info, _body)
		_reparent(_pin_row, _stack)
		_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_info.size_flags_vertical = Control.SIZE_SHRINK_END
		physical_min_size(_info, 0.0, 0.0)
		# 50 % of the height for the map left nothing for the pins and the panel
		# on an 844 px phone: both pins drew at y=857. A third of it is enough
		# for the plate to read, and the body still expands into any slack.
		physical_min_size(_map, 0.0, height * 0.26)
		physical_min_size(_launch, 0.0, 72.0)
	# 64 px is the touch floor (`AegisTokens.MIN_TOUCH_PX`); 56 failed it.
	for pin in _pins:
		physical_min_size(pin, 0.0, 64.0)
	_orient_pins(landscape)
	# 390 px of height is enough for the name and one line about the theatre, not
	# for the chapter tag as well; the pin under the map already carries the name.
	var cramped := height < 700.0 and not landscape
	var short_landscape := landscape and height < 520.0
	_chapter.visible = not (short_landscape or cramped)
	_brief.visible = not (short_landscape or cramped)
	# A column, always. Two pins side by side need 380 px of text at `label`
	# size and a 360 px phone has 328; a `vertical` flag on the other container
	# class is not the same thing and did nothing here.
	physical_min_size(_status, 0.0, 20.0 if short_landscape else 24.0)


## A row of two pins is 64 px tall and fits any landscape screen; a column of
## two is 128 and did not fit a 390 px one (the second drew at y=350). Portrait
## has the opposite problem -- two pins side by side need 380 px of text and a
## 360 px phone has 328 -- so the pins change container with the orientation.
func _orient_pins(landscape: bool) -> void:
	var target: Container = _pin_row
	var wants_row := landscape
	if (wants_row and target is HBoxContainer) or (not wants_row and target is VBoxContainer):
		return
	target = HBoxContainer.new() if wants_row else VBoxContainer.new()
	target.name = &"TheatrePins"
	for pin in _pins:
		if pin.get_parent() != null:
			pin.get_parent().remove_child(pin)
		target.add_child(pin)
	if _pin_row != null and _pin_row.get_parent() != null:
		var parent := _pin_row.get_parent()
		var index := _pin_row.get_index()
		parent.remove_child(_pin_row)
		parent.add_child(target)
		parent.move_child(target, index)
	else:
		_stack.add_child(target)
	_pin_row = target
	physical_separation(_pin_row, 8)


## Moves a node only when it is somewhere else; re-adding on every resize would
## restart the layout every frame.
## A row of two pins is 64 px tall and fits any landscape screen; a column of
## two is 128 and did not fit a 390 px one (the second drew at y=350). Portrait
## has the opposite problem -- two pins side by side need 380 px of text and a
## 360 px phone has 328 -- so the pins change container with the orientation.
func _reparent(node: Node, target: Node) -> void:
	if node.get_parent() == target:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	target.add_child(node)


func _on_resized() -> void:
	relayout()
	reframe()


func enter(_stage_payload: Dictionary) -> void:
	apply_safe_margins(_margin)
	_on_resized()
	_refresh()


func refresh_profile() -> void:
	_refresh()
	if _chrome != null:
		_chrome.refresh(progression_service())


func _on_nav_requested(tab_id: StringName) -> void:
	match tab_id:
		LobbyChrome.TAB_HOME:
			completed.emit(&"DASHBOARD", {})
		LobbyChrome.TAB_OPERATIVE:
			completed.emit(&"HERO", {})
		_:
			pass


func _on_pin_pressed(world_id: StringName) -> void:
	var progression := progression_service()
	if progression == null:
		return
	if world_id == _selected:
		return
	progression.select_world(world_id)
	_refresh()


func _refresh() -> void:
	var progression := progression_service()
	var world_id: StringName = _selected
	if progression != null:
		world_id = progression.selected_world_id
		if _chrome != null:
			_chrome.refresh(progression)
	var definition := WorldDefinition.load_definition(world_id)
	if definition == null:
		return
	var first_time := _selected != world_id
	_selected = world_id
	_chapter.text = "CHAPTER  %s" % String(definition.world_id).replace("_", " ").to_upper()
	_title.text = definition.display_name.to_upper()
	_brief.text = _first_sentence(definition.role_description)
	_status.text = definition.status_line.to_upper()
	if definition.field_ready:
		_status.add_theme_color_override("font_color", AegisTokens.OK)
	else:
		_status.add_theme_color_override("font_color", AegisTokens.DANGER)
	for pin in _pins:
		var live: bool = String(pin.get_meta("world_id", "")) == String(world_id)
		pin.set_pressed_no_signal(live)
		pin.edge_active = live
		pin.queue_redraw()
	# The plate changes with the selection, fading rather than cutting: a map
	# that snaps from one horizon to another reads as a bug, not a choice.
	if first_time and _plate != null:
		var target := try_texture(definition.plate_path)
		if target != null:
			var fade := create_tween()
			fade.tween_property(_plate, "modulate:a", 0.25, 0.12)
			fade.tween_callback(func() -> void: _plate.texture = target)
			fade.tween_property(_plate, "modulate:a", 1.0, 0.22)


func _on_launch_pressed() -> void:
	var progression := progression_service()
	if progression == null:
		return
	var definition := WorldDefinition.load_definition(progression.selected_world_id)
	if definition == null or not definition.field_ready:
		return
	progression.select_world(progression.selected_world_id)
	(
		completed
		. emit(
			&"PRELOAD",
			{
				"scene": FrontEnd.GAMEPLAY_SCENE,
				"title": "PREPARING DROP",
				"targets": [FrontEnd.GAMEPLAY_SCENE],
				"weapon_id": String(progression.selected_weapon_id),
				"world_id": String(progression.selected_world_id),
			}
		)
	)


static func _first_sentence(text: String) -> String:
	var stop := text.find(". ")
	return text if stop == -1 else text.substr(0, stop + 1)
