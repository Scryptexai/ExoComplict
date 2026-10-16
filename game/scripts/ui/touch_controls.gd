class_name TouchControls
extends Control

signal movement_changed(value: Vector2)
signal look_delta(value: Vector2)
signal fire_changed(pressed: bool)
signal weapon_switch_requested
signal pause_requested
signal retry_requested

const HIT_CONFIRM_DURATION: float = 0.16
const DAMAGE_FLASH_DURATION: float = 0.28
const DEFAULT_HEALTH_COLOR := Color(0.18, 0.88, 0.65, 1.0)
const WARNING_HEALTH_COLOR := Color(1.0, 0.68, 0.2, 1.0)
const CRITICAL_HEALTH_COLOR := Color(1.0, 0.24, 0.22, 1.0)

var _move_touch_id: int = -1
var _look_touch_id: int = -1
var _fire_touch_id: int = -1
var _pressed_touch_buttons: Dictionary = {}
var _move_origin: Vector2 = Vector2.ZERO
var _move_position: Vector2 = Vector2.ZERO
var _ui_scale: float = 1.0
var _top_bar: HBoxContainer
var _health_card: PanelContainer
var _wave_card: PanelContainer
var _run_card: PanelContainer
var _health_bar: ProgressBar
var _health_value_label: Label
var _wave_title_label: Label
var _wave_state_label: Label
var _wave_enemy_label: Label
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
	resized.connect(_layout_controls)
	var window := get_window()
	if is_instance_valid(window):
		window.focus_exited.connect(_on_window_focus_exited)
	_layout_controls()
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
		var local_position: Vector2 = event.position
		if event.pressed:
			_begin_touch(event.index, local_position)
		else:
			_end_touch(event.index, event.position)
	elif event is InputEventScreenDrag:
		_update_touch(event.index, event.position, event.relative)
	elif (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_R
		and get_tree().paused
	):
		retry_requested.emit()
		get_viewport().set_input_as_handled()


func set_hud_health(current: float, maximum: float) -> void:
	if not is_instance_valid(_health_bar) or not is_instance_valid(_health_value_label):
		return
	var safe_maximum := maxf(maximum, 1.0)
	var safe_current := clampf(current, 0.0, safe_maximum)
	_health_bar.max_value = safe_maximum
	_health_bar.value = safe_current
	_health_value_label.text = "%d / %d" % [roundi(safe_current), roundi(safe_maximum)]
	var health_ratio := safe_current / safe_maximum
	var health_color := DEFAULT_HEALTH_COLOR
	if health_ratio <= 0.3:
		health_color = CRITICAL_HEALTH_COLOR
	elif health_ratio <= 0.6:
		health_color = WARNING_HEALTH_COLOR
	_health_bar.add_theme_stylebox_override("fill", _make_progress_style(health_color))


func set_wave_status(
	wave_number: int,
	active_enemies: int,
	remaining_enemies: int,
	state_text: String,
) -> void:
	if not is_instance_valid(_wave_title_label):
		return
	_wave_title_label.text = "WAVE %02d" % wave_number if wave_number > 0 else "FRONTIER DEFENSE"
	_wave_state_label.text = state_text
	_wave_enemy_label.text = "ENEMIES  %d ACTIVE  ·  %d LEFT" % [active_enemies, remaining_enemies]


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
	if paused:
		_clear_touch_state()
	if is_instance_valid(_pause_button):
		_pause_button.text = "RETRY" if _player_down else ("RESUME" if paused else "PAUSE")
		_pause_button.disabled = false
	if is_instance_valid(_pause_label):
		_pause_label.visible = paused
	if is_instance_valid(_fire_button):
		_fire_button.disabled = paused or _player_down
	if is_instance_valid(_weapon_button):
		_weapon_button.disabled = paused or _player_down


func set_player_down(down: bool) -> void:
	_player_down = down
	if down:
		_clear_touch_state()
	if is_instance_valid(_pause_button):
		_pause_button.text = "RETRY" if down else ("RESUME" if get_tree().paused else "PAUSE")
	if is_instance_valid(_fire_button):
		_fire_button.disabled = down or get_tree().paused
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
	_clear_touch_state()
	_results_summary.text = (
		"Wave reached: %d\nSurvival time: %s\nEliminations: %d\nRun score: %d\nBP earned: %d"
		% [wave_reached, survival_time, eliminations, run_score, bp_earned]
	)
	_results_panel.visible = true
	_top_bar.visible = false
	_help_label.visible = false
	_fire_button.visible = false
	_weapon_button.visible = false
	_pause_button.visible = false
	_pause_label.visible = false


func hide_results() -> void:
	if not is_instance_valid(_results_panel):
		return
	_results_panel.visible = false
	_top_bar.visible = true
	_help_label.visible = true
	_fire_button.visible = true
	_weapon_button.visible = true
	_pause_button.visible = true
	_pause_label.visible = get_tree().paused


func _build_ui() -> void:
	_top_bar = HBoxContainer.new()
	_top_bar.name = "PlaytestHUD"
	_top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_bar.add_theme_constant_override("separation", 10)
	add_child(_top_bar)

	_build_health_card()
	_build_wave_card()
	_build_run_card()

	_pause_button = Button.new()
	_pause_button.name = "PauseButton"
	_pause_button.text = "PAUSE"
	_pause_button.tooltip_text = "Pause the run"
	_pause_button.focus_mode = Control.FOCUS_NONE
	_pause_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pause_button.custom_minimum_size = Vector2(108.0, 58.0)
	_pause_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_button_theme(_pause_button, Color(0.09, 0.19, 0.25, 0.96), Color(0.18, 0.75, 0.91, 0.78))
	_pause_button.add_theme_font_size_override("font_size", 15)
	_pause_button.pressed.connect(_on_pause_pressed)
	_top_bar.add_child(_pause_button)

	_fire_button = _make_button("FIRE", "FireButton")
	_fire_button.add_theme_font_size_override("font_size", 22)
	_fire_button.button_down.connect(_on_fire_down)
	_fire_button.button_up.connect(_on_fire_up)

	_weapon_button = _make_button("PULSE RIFLE", "WeaponSwitchButton")
	_weapon_button.add_theme_font_size_override("font_size", 14)
	_weapon_button.tooltip_text = "Tap to cycle weapons"
	_weapon_button.pressed.connect(_on_weapon_switch_pressed)

	_help_label = Label.new()
	_help_label.name = "ControlsHelp"
	_help_label.anchor_left = 0.2
	_help_label.anchor_right = 0.8
	_help_label.anchor_top = 1.0
	_help_label.anchor_bottom = 1.0
	_help_label.offset_top = -61.0
	_help_label.offset_bottom = -10.0
	_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_help_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_help_label.text = (
		"TOUCH: drag left side to move · drag right side to aim · hold FIRE · tap weapon to cycle\n"
		+ "DESKTOP: WASD · right mouse to aim · hold left mouse or FIRE · E to cycle · R to retry"
	)
	_help_label.add_theme_font_size_override("font_size", 12)
	_help_label.add_theme_color_override("font_color", Color(0.76, 0.88, 0.96, 0.92))
	_help_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_help_label)

	_pause_label = Label.new()
	_pause_label.name = "PauseOverlay"
	_pause_label.anchor_left = 0.5
	_pause_label.anchor_right = 0.5
	_pause_label.anchor_top = 0.5
	_pause_label.anchor_bottom = 0.5
	_pause_label.offset_left = -190.0
	_pause_label.offset_right = 190.0
	_pause_label.offset_top = -70.0
	_pause_label.offset_bottom = 70.0
	_pause_label.text = "PAUSED\nTap RESUME to continue"
	_pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pause_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pause_label.add_theme_font_size_override("font_size", 28)
	_pause_label.add_theme_color_override("font_color", Color(0.85, 0.96, 1.0))
	_pause_label.visible = false
	_pause_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pause_label)

	_build_results_panel()


func _build_health_card() -> void:
	_health_card = _make_card("HealthCard", Vector2(250.0, 88.0))
	_top_bar.add_child(_health_card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	_health_card.add_child(content)

	var heading_row := HBoxContainer.new()
	content.add_child(heading_row)
	var heading := _make_heading("VITALS")
	heading_row.add_child(heading)
	_health_value_label = Label.new()
	_health_value_label.text = "100 / 100"
	_health_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_health_value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_health_value_label.add_theme_font_size_override("font_size", 14)
	_health_value_label.add_theme_color_override("font_color", Color(0.91, 0.97, 1.0))
	heading_row.add_child(_health_value_label)

	_health_bar = ProgressBar.new()
	_health_bar.name = "HealthBar"
	_health_bar.min_value = 0.0
	_health_bar.max_value = 100.0
	_health_bar.value = 100.0
	_health_bar.show_percentage = false
	_health_bar.custom_minimum_size = Vector2(0.0, 16.0)
	_health_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_health_bar.add_theme_stylebox_override(
		"background", _make_progress_style(Color(0.035, 0.085, 0.11, 1.0))
	)
	_health_bar.add_theme_stylebox_override("fill", _make_progress_style(DEFAULT_HEALTH_COLOR))
	content.add_child(_health_bar)


func _build_wave_card() -> void:
	_wave_card = _make_card("WaveCard", Vector2(280.0, 88.0))
	_top_bar.add_child(_wave_card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 2)
	_wave_card.add_child(content)

	_wave_title_label = _make_heading("FRONTIER DEFENSE")
	_wave_title_label.add_theme_font_size_override("font_size", 17)
	content.add_child(_wave_title_label)
	_wave_state_label = Label.new()
	_wave_state_label.text = "READY"
	_wave_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_wave_state_label.add_theme_font_size_override("font_size", 12)
	_wave_state_label.add_theme_color_override("font_color", Color(0.65, 0.87, 0.96))
	content.add_child(_wave_state_label)
	_wave_enemy_label = Label.new()
	_wave_enemy_label.text = "ENEMIES  0 ACTIVE  ·  0 LEFT"
	_wave_enemy_label.add_theme_font_size_override("font_size", 12)
	_wave_enemy_label.add_theme_color_override("font_color", Color(0.84, 0.93, 1.0))
	content.add_child(_wave_enemy_label)


func _build_run_card() -> void:
	_run_card = _make_card("RunDataCard", Vector2(320.0, 88.0))
	_top_bar.add_child(_run_card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	_run_card.add_child(content)
	var heading := _make_heading("RUN DATA")
	content.add_child(heading)
	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.text = "Score: 0 · BP earned: 0\nKOs: 0 · Time: 00:00\nTarget: 54 / 54 · Shots: 0"
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.84, 0.92, 1.0))
	content.add_child(_status_label)


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
	_results_panel.add_theme_stylebox_override("panel", _make_panel_style())
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
	_results_retry_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_button_theme(
		_results_retry_button, Color(0.08, 0.33, 0.43, 1.0), Color(0.2, 0.82, 1.0, 0.95)
	)
	_results_retry_button.pressed.connect(_on_results_retry_pressed)
	content.add_child(_results_retry_button)


func _make_card(card_name: String, minimum_size: Vector2) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = card_name
	card.custom_minimum_size = minimum_size
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", _make_panel_style())
	return card


func _make_heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.39, 0.85, 1.0))
	return label


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.045, 0.067, 0.94)
	style.border_color = Color(0.08, 0.62, 0.82, 0.58)
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.content_margin_left = 12.0
	style.content_margin_top = 8.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 8.0
	return style


func _make_progress_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(7)
	style.content_margin_left = 0.0
	style.content_margin_top = 0.0
	style.content_margin_right = 0.0
	style.content_margin_bottom = 0.0
	return style


func _make_button(label: String, button_name: String) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = label
	button.anchor_left = 1.0
	button.anchor_right = 1.0
	button.anchor_top = 1.0
	button.anchor_bottom = 1.0
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_button_theme(button, Color(0.08, 0.25, 0.34, 0.96), Color(0.1, 0.77, 0.96, 0.88))
	add_child(button)
	return button


func _apply_button_theme(button: Button, background: Color, border: Color) -> void:
	button.add_theme_stylebox_override("normal", _make_button_style(background, border))
	button.add_theme_stylebox_override(
		"hover", _make_button_style(background.lightened(0.12), border)
	)
	button.add_theme_stylebox_override(
		"pressed", _make_button_style(background.darkened(0.12), border.lightened(0.1))
	)
	button.add_theme_stylebox_override(
		"disabled", _make_button_style(Color(0.05, 0.09, 0.12, 0.78), Color(0.16, 0.28, 0.34, 0.56))
	)
	button.add_theme_color_override("font_color", Color(0.9, 0.97, 1.0))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.64, 0.7, 0.65))


func _make_button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 10.0
	style.content_margin_top = 8.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 8.0
	return style


func _layout_controls() -> void:
	if not is_instance_valid(_top_bar):
		return
	var viewport_width := maxf(size.x, 640.0)
	var viewport_height := maxf(size.y, 360.0)
	_ui_scale = clampf(minf(viewport_width / 1280.0, viewport_height / 720.0), 0.68, 1.0)
	var margin := 16.0 * _ui_scale
	_top_bar.offset_left = margin
	_top_bar.offset_top = 14.0 * _ui_scale
	_top_bar.offset_right = -margin
	_top_bar.offset_bottom = 104.0 * _ui_scale
	_health_card.custom_minimum_size = Vector2(250.0 * _ui_scale, 88.0 * _ui_scale)
	_wave_card.custom_minimum_size = Vector2(280.0 * _ui_scale, 88.0 * _ui_scale)
	_run_card.custom_minimum_size = Vector2(320.0 * _ui_scale, 88.0 * _ui_scale)
	_pause_button.custom_minimum_size = Vector2(108.0 * _ui_scale, 58.0 * _ui_scale)
	var fire_size := 148.0 * _ui_scale
	_fire_button.offset_left = -fire_size - 24.0 * _ui_scale
	_fire_button.offset_top = -fire_size - 24.0 * _ui_scale
	_fire_button.offset_right = -24.0 * _ui_scale
	_fire_button.offset_bottom = -24.0 * _ui_scale
	_fire_button.custom_minimum_size = Vector2(fire_size, fire_size)
	var weapon_width := 172.0 * _ui_scale
	var weapon_height := 66.0 * _ui_scale
	_weapon_button.offset_left = -weapon_width - 24.0 * _ui_scale
	_weapon_button.offset_top = -250.0 * _ui_scale
	_weapon_button.offset_right = -24.0 * _ui_scale
	_weapon_button.offset_bottom = -184.0 * _ui_scale
	_weapon_button.custom_minimum_size = Vector2(weapon_width, weapon_height)
	_help_label.offset_top = -61.0 * _ui_scale
	_help_label.offset_bottom = -10.0 * _ui_scale
	_results_panel.custom_minimum_size = Vector2(440.0 * _ui_scale, 356.0 * _ui_scale)
	_results_panel.offset_left = -220.0 * _ui_scale
	_results_panel.offset_right = 220.0 * _ui_scale
	_results_panel.offset_top = -178.0 * _ui_scale
	_results_panel.offset_bottom = 178.0 * _ui_scale


func _begin_touch(touch_id: int, position: Vector2) -> void:
	var touched_button := _find_touch_button(position)
	if is_instance_valid(touched_button):
		get_viewport().set_input_as_handled()
		if (
			touched_button == _fire_button
			and not touched_button.disabled
			and not _player_down
			and not get_tree().paused
			and _fire_touch_id == -1
		):
			_fire_touch_id = touch_id
			fire_changed.emit(true)
		else:
			_pressed_touch_buttons[touch_id] = touched_button
		return
	if _player_down or get_tree().paused or _is_over_hud(position):
		return
	if position.y < size.y * 0.2:
		return
	if position.x < size.x * 0.47 and _move_touch_id == -1:
		_move_touch_id = touch_id
		_move_origin = position
		_move_position = position
		movement_changed.emit(Vector2.ZERO)
		queue_redraw()
	elif position.x >= size.x * 0.47 and _look_touch_id == -1:
		_look_touch_id = touch_id


func _update_touch(touch_id: int, position: Vector2, relative: Vector2) -> void:
	if touch_id == _fire_touch_id or _pressed_touch_buttons.has(touch_id):
		get_viewport().set_input_as_handled()
		return
	if _player_down or get_tree().paused:
		_clear_touch_state()
		return
	if touch_id == _move_touch_id:
		_move_position = position
		var radius := 68.0 * _ui_scale
		var offset := (position - _move_origin) / radius
		movement_changed.emit(offset.limit_length(1.0))
		queue_redraw()
	elif touch_id == _look_touch_id:
		look_delta.emit(relative)


func _end_touch(touch_id: int, position: Vector2) -> void:
	if touch_id == _fire_touch_id:
		_fire_touch_id = -1
		fire_changed.emit(false)
		get_viewport().set_input_as_handled()
		return
	if _pressed_touch_buttons.has(touch_id):
		var button := _pressed_touch_buttons[touch_id] as Button
		_pressed_touch_buttons.erase(touch_id)
		get_viewport().set_input_as_handled()
		if (
			is_instance_valid(button)
			and not button.disabled
			and button.get_global_rect().has_point(position)
		):
			_activate_touch_button(button)
		return
	if touch_id == _move_touch_id:
		_move_touch_id = -1
		movement_changed.emit(Vector2.ZERO)
		queue_redraw()
	elif touch_id == _look_touch_id:
		_look_touch_id = -1


func _clear_touch_state() -> void:
	_move_touch_id = -1
	_look_touch_id = -1
	_fire_touch_id = -1
	_pressed_touch_buttons.clear()
	_move_origin = Vector2.ZERO
	_move_position = Vector2.ZERO
	movement_changed.emit(Vector2.ZERO)
	fire_changed.emit(false)
	queue_redraw()


func _find_touch_button(position: Vector2) -> Button:
	var buttons: Array[Button] = [
		_results_retry_button,
		_pause_button,
		_weapon_button,
		_fire_button,
	]
	for button in buttons:
		if (
			is_instance_valid(button)
			and button.is_visible_in_tree()
			and button.get_global_rect().has_point(position)
		):
			return button
	return null


func _activate_touch_button(button: Button) -> void:
	if button == _weapon_button:
		_on_weapon_switch_pressed()
	elif button == _pause_button:
		_on_pause_pressed()
	elif button == _results_retry_button:
		_on_results_retry_pressed()


func _is_over_hud(position: Vector2) -> bool:
	var global_position := position
	var hud_controls: Array[Control] = [
		_top_bar,
		_help_label,
		_fire_button,
		_weapon_button,
		_pause_label,
		_results_panel,
	]
	for control in hud_controls:
		if (
			is_instance_valid(control)
			and control.visible
			and control.get_global_rect().has_point(global_position)
		):
			return true
	return false


func _draw() -> void:
	if _damage_flash_remaining > 0.0:
		var flash_strength := _damage_flash_remaining / DAMAGE_FLASH_DURATION
		var flash_color := Color(1.0, 0.08, 0.04, 0.2 * flash_strength)
		draw_rect(Rect2(Vector2.ZERO, size), flash_color, true)

	var center := size * 0.5
	var crosshair_extent := 9.0 * _ui_scale
	var crosshair_color := Color(0.38, 0.92, 1.0, 0.9)
	if _hit_confirm_remaining > 0.0:
		crosshair_extent = 13.0 * _ui_scale
		crosshair_color = Color(1.0, 0.68, 0.22, 1.0)
	draw_line(
		center - Vector2(crosshair_extent, 0.0),
		center + Vector2(crosshair_extent, 0.0),
		crosshair_color,
		2.0 * _ui_scale
	)
	draw_line(
		center - Vector2(0.0, crosshair_extent),
		center + Vector2(0.0, crosshair_extent),
		crosshair_color,
		2.0 * _ui_scale
	)

	var joystick_center := Vector2(
		minf(106.0 * _ui_scale, size.x * 0.18), size.y - 112.0 * _ui_scale
	)
	if _move_touch_id != -1:
		joystick_center = _move_origin
	var joystick_radius := 68.0 * _ui_scale
	var joystick_color := Color(0.22, 0.72, 0.94, 0.3)
	draw_arc(joystick_center, joystick_radius, 0.0, TAU, 40, joystick_color, 2.0 * _ui_scale)
	if _move_touch_id != -1:
		draw_circle(_move_position, 23.0 * _ui_scale, Color(0.22, 0.72, 0.94, 0.36))
		draw_arc(
			_move_position,
			23.0 * _ui_scale,
			0.0,
			TAU,
			24,
			Color(0.48, 0.88, 1.0, 0.78),
			2.0 * _ui_scale
		)


func _on_fire_down() -> void:
	if not _player_down and not get_tree().paused:
		fire_changed.emit(true)


func _on_fire_up() -> void:
	fire_changed.emit(false)


func _on_weapon_switch_pressed() -> void:
	if not _player_down and not get_tree().paused:
		weapon_switch_requested.emit()


func _on_pause_pressed() -> void:
	if _player_down:
		retry_requested.emit()
	else:
		pause_requested.emit()


func _on_results_retry_pressed() -> void:
	retry_requested.emit()


func _on_window_focus_exited() -> void:
	_clear_touch_state()
