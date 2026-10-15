class_name TouchControls
extends Control

signal movement_changed(value: Vector2)
signal look_delta(value: Vector2)
signal fire_changed(pressed: bool)
signal weapon_switch_requested
signal pause_requested
signal retry_requested

const JOYSTICK_RADIUS: float = 68.0
const HIT_CONFIRM_DURATION: float = 0.16
const DAMAGE_FLASH_DURATION: float = 0.28

var _move_touch_id: int = -1
var _look_touch_id: int = -1
var _move_origin: Vector2 = Vector2.ZERO
var _move_position: Vector2 = Vector2.ZERO
var _status_label: Label
var _help_label: Label
var _fire_button: Button
var _weapon_button: Button
var _pause_button: Button
var _pause_label: Label
var _results_panel: PanelContainer
var _results_summary: Label
var _results_retry_button: Button
var _player_down: bool = false
var _hit_confirm_remaining: float = 0.0
var _damage_flash_remaining: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	resized.connect(queue_redraw)
	queue_redraw()


func _process(delta: float) -> void:
	var needs_redraw := false
	if _hit_confirm_remaining > 0.0:
		_hit_confirm_remaining = maxf(_hit_confirm_remaining - delta, 0.0)
		needs_redraw = true
	if _damage_flash_remaining > 0.0:
		_damage_flash_remaining = maxf(_damage_flash_remaining - delta, 0.0)
		needs_redraw = true
	if needs_redraw:
		queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_begin_touch(event.index, event.position)
		else:
			_end_touch(event.index)
	elif event is InputEventScreenDrag:
		_update_touch(event.index, event.position, event.relative)


func show_hit_confirmed() -> void:
	_hit_confirm_remaining = HIT_CONFIRM_DURATION
	queue_redraw()


func show_damage_received() -> void:
	_damage_flash_remaining = DAMAGE_FLASH_DURATION
	queue_redraw()


func set_status(text: String) -> void:
	if is_instance_valid(_status_label):
		_status_label.text = text


func set_weapon_label(display_name: String) -> void:
	if is_instance_valid(_weapon_button):
		_weapon_button.text = display_name.to_upper()


func set_paused(paused: bool) -> void:
	if is_instance_valid(_pause_button):
		_pause_button.text = "RETRY" if _player_down else ("RESUME" if paused else "PAUSE")
		_pause_button.disabled = false
	if is_instance_valid(_pause_label):
		_pause_label.visible = paused
	if is_instance_valid(_fire_button):
		_fire_button.disabled = paused or _player_down
		if paused or _player_down:
			# Do not rely on a matching touch-up event after pausing or defeat.
			fire_changed.emit(false)
	if is_instance_valid(_weapon_button):
		_weapon_button.disabled = paused or _player_down


func set_player_down(down: bool) -> void:
	_player_down = down
	if is_instance_valid(_pause_button):
		_pause_button.text = "RETRY" if down else ("RESUME" if get_tree().paused else "PAUSE")
	if is_instance_valid(_fire_button):
		_fire_button.disabled = down or get_tree().paused
		if down:
			fire_changed.emit(false)
	if is_instance_valid(_weapon_button):
		_weapon_button.disabled = down or get_tree().paused


func show_results(
	wave_reached: int,
	survival_time: String,
	eliminations: int,
	run_score: int,
	bp_earned: int,
) -> void:
	if not is_instance_valid(_results_panel):
		return
	_results_summary.text = (
		"Wave reached: %d\nSurvival time: %s\nEliminations: %d\nRun score: %d\nBP earned: %d"
		% [wave_reached, survival_time, eliminations, run_score, bp_earned]
	)
	_results_panel.visible = true
	_status_label.visible = false
	_help_label.visible = false
	_fire_button.visible = false
	_weapon_button.visible = false
	_pause_button.visible = false
	_pause_label.visible = false
	fire_changed.emit(false)


func hide_results() -> void:
	if not is_instance_valid(_results_panel):
		return
	_results_panel.visible = false
	_status_label.visible = true
	_help_label.visible = true
	_fire_button.visible = true
	_weapon_button.visible = true
	_pause_button.visible = true
	_pause_label.visible = get_tree().paused


func _build_ui() -> void:
	_status_label = Label.new()
	_status_label.position = Vector2(22.0, 16.0)
	_status_label.custom_minimum_size = Vector2(580.0, 128.0)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 17)
	_status_label.add_theme_color_override("font_color", Color(0.82, 0.94, 1.0))
	add_child(_status_label)

	_help_label = Label.new()
	_help_label.anchor_top = 1.0
	_help_label.anchor_bottom = 1.0
	_help_label.anchor_right = 1.0
	_help_label.offset_left = 22.0
	_help_label.offset_top = -50.0
	_help_label.offset_right = -190.0
	_help_label.offset_bottom = -10.0
	_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help_label.text = (
		"Move: WASD / left drag · Aim: right mouse / right drag · "
		+ "Fire: click / FIRE · Switch: E / weapon button · Reset: R / RETRY"
	)
	_help_label.add_theme_font_size_override("font_size", 14)
	_help_label.add_theme_color_override("font_color", Color(0.72, 0.82, 0.9, 0.9))
	add_child(_help_label)

	_fire_button = _make_button("FIRE", -166.0, -166.0, -26.0, -26.0, true)
	_fire_button.add_theme_font_size_override("font_size", 22)
	_fire_button.button_down.connect(_on_fire_down)
	_fire_button.button_up.connect(_on_fire_up)

	_weapon_button = _make_button("PULSE RIFLE", -166.0, -248.0, -26.0, -176.0, true)
	_weapon_button.add_theme_font_size_override("font_size", 14)
	_weapon_button.pressed.connect(_on_weapon_switch_pressed)

	_pause_button = _make_button("PAUSE", -126.0, 18.0, -24.0, 72.0)
	_pause_button.add_theme_font_size_override("font_size", 16)
	_pause_button.pressed.connect(_on_pause_pressed)

	_pause_label = Label.new()
	_pause_label.anchor_left = 0.5
	_pause_label.anchor_right = 0.5
	_pause_label.anchor_top = 0.5
	_pause_label.anchor_bottom = 0.5
	_pause_label.offset_left = -170.0
	_pause_label.offset_right = 170.0
	_pause_label.offset_top = -62.0
	_pause_label.offset_bottom = 62.0
	_pause_label.text = "PAUSED\nTap RESUME to continue"
	_pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pause_label.add_theme_font_size_override("font_size", 30)
	_pause_label.add_theme_color_override("font_color", Color(0.85, 0.96, 1.0))
	_pause_label.visible = false
	add_child(_pause_label)
	_build_results_panel()


func _build_results_panel() -> void:
	_results_panel = PanelContainer.new()
	_results_panel.name = "ResultsPanel"
	_results_panel.anchor_left = 0.5
	_results_panel.anchor_right = 0.5
	_results_panel.anchor_top = 0.5
	_results_panel.anchor_bottom = 0.5
	_results_panel.offset_left = -220.0
	_results_panel.offset_right = 220.0
	_results_panel.offset_top = -178.0
	_results_panel.offset_bottom = 178.0
	_results_panel.custom_minimum_size = Vector2(440.0, 356.0)
	_results_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_results_panel.visible = false
	add_child(_results_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	_results_panel.add_child(content)

	var title := Label.new()
	title.text = "RUN RESULTS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.45, 0.86, 1.0))
	content.add_child(title)

	_results_summary = Label.new()
	_results_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_results_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_results_summary.add_theme_font_size_override("font_size", 18)
	_results_summary.add_theme_color_override("font_color", Color(0.84, 0.92, 1.0))
	content.add_child(_results_summary)

	_results_retry_button = Button.new()
	_results_retry_button.name = "ResultsRetryButton"
	_results_retry_button.text = "RETRY"
	_results_retry_button.custom_minimum_size = Vector2(190.0, 54.0)
	_results_retry_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_results_retry_button.focus_mode = Control.FOCUS_NONE
	_results_retry_button.pressed.connect(_on_results_retry_pressed)
	content.add_child(_results_retry_button)


func _make_button(
	label: String,
	left_offset: float,
	top_offset: float,
	right_offset: float,
	bottom_offset: float,
	bottom_anchored: bool = false
) -> Button:
	var button := Button.new()
	button.name = "WeaponSwitchButton"
	if label == "FIRE":
		button.name = "FireButton"
	elif label == "PAUSE":
		button.name = "PauseButton"
	button.text = label
	button.anchor_left = 1.0
	button.anchor_right = 1.0
	button.anchor_top = 1.0 if bottom_anchored else 0.0
	button.anchor_bottom = button.anchor_top
	button.offset_left = left_offset
	button.offset_top = top_offset
	button.offset_right = right_offset
	button.offset_bottom = bottom_offset
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(button)
	return button


func _begin_touch(touch_id: int, position: Vector2) -> void:
	if _is_over_button(position):
		return
	if position.x < size.x * 0.46 and _move_touch_id == -1:
		_move_touch_id = touch_id
		_move_origin = position
		_move_position = position
		movement_changed.emit(Vector2.ZERO)
		queue_redraw()
	elif position.x >= size.x * 0.46 and _look_touch_id == -1:
		_look_touch_id = touch_id


func _update_touch(touch_id: int, position: Vector2, relative: Vector2) -> void:
	if touch_id == _move_touch_id:
		_move_position = position
		var offset := (position - _move_origin) / JOYSTICK_RADIUS
		movement_changed.emit(offset.limit_length(1.0))
		queue_redraw()
	elif touch_id == _look_touch_id:
		look_delta.emit(relative)


func _end_touch(touch_id: int) -> void:
	if touch_id == _move_touch_id:
		_move_touch_id = -1
		movement_changed.emit(Vector2.ZERO)
		queue_redraw()
	elif touch_id == _look_touch_id:
		_look_touch_id = -1


func _is_over_button(position: Vector2) -> bool:
	if is_instance_valid(_results_panel) and _results_panel.visible:
		if _results_panel.get_global_rect().has_point(position):
			return true
	if is_instance_valid(_fire_button) and _fire_button.get_global_rect().has_point(position):
		return true
	if is_instance_valid(_weapon_button) and _weapon_button.get_global_rect().has_point(position):
		return true
	if is_instance_valid(_pause_button) and _pause_button.get_global_rect().has_point(position):
		return true
	return false


func _draw() -> void:
	if _damage_flash_remaining > 0.0:
		var flash_strength := _damage_flash_remaining / DAMAGE_FLASH_DURATION
		var flash_color := Color(1.0, 0.08, 0.04, 0.2 * flash_strength)
		draw_rect(Rect2(Vector2.ZERO, size), flash_color, true)

	var center := size * 0.5
	var crosshair_extent := 9.0
	var crosshair_color := Color(0.38, 0.92, 1.0, 0.9)
	if _hit_confirm_remaining > 0.0:
		crosshair_extent = 13.0
		crosshair_color = Color(1.0, 0.68, 0.22, 1.0)
	draw_line(
		center - Vector2(crosshair_extent, 0.0),
		center + Vector2(crosshair_extent, 0.0),
		crosshair_color,
		2.0
	)
	draw_line(
		center - Vector2(0.0, crosshair_extent),
		center + Vector2(0.0, crosshair_extent),
		crosshair_color,
		2.0
	)

	var joystick_center := _move_origin
	if _move_touch_id == -1:
		joystick_center = Vector2(106.0, size.y - 112.0)
	var joystick_color := Color(0.22, 0.72, 0.94, 0.26)
	draw_arc(joystick_center, JOYSTICK_RADIUS, 0.0, TAU, 40, joystick_color, 2.0)
	if _move_touch_id != -1:
		draw_circle(_move_position, 23.0, Color(0.22, 0.72, 0.94, 0.34))
		draw_arc(_move_position, 23.0, 0.0, TAU, 24, Color(0.48, 0.88, 1.0, 0.72), 2.0)


func _on_fire_down() -> void:
	fire_changed.emit(true)


func _on_fire_up() -> void:
	fire_changed.emit(false)


func _on_weapon_switch_pressed() -> void:
	weapon_switch_requested.emit()


func _on_pause_pressed() -> void:
	pause_requested.emit()


func _on_results_retry_pressed() -> void:
	retry_requested.emit()
