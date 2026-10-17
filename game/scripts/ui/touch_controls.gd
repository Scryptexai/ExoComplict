class_name TouchControls
extends Control

signal movement_changed(value: Vector2)
signal look_delta(value: Vector2)
signal fire_changed(pressed: bool)
signal aim_changed(pressed: bool)
signal weapon_switch_requested
signal skill_requested
signal pause_requested
signal retry_requested

const HIT_CONFIRM_DURATION: float = 0.16
const HELP_VISIBLE_SECONDS: float = 12.0
const HELP_FADE_SECONDS: float = 1.5
# The browser shell (game/web_shell/index.html) draws its chips along the top of
# the page; the HUD keeps clear of them instead of overlapping.
const WEB_TOP_INSET: float = 46.0
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
var _skill_button: Button
var _pause_button: Button
var _aim_button: Button
var _pause_label: Label
var _results_panel: PanelContainer
var _results_summary: Label
var _results_retry_button: Button
var _player_down: bool = false
var _hit_confirm_remaining: float = 0.0
var _damage_flash_remaining: float = 0.0
var _skill_cooldown_remaining: float = 0.0
var _skill_cooldown_total: float = 12.0
var _skill_feedback_remaining: float = 0.0
var _aiming: bool = false
var _fire_flash_remaining: float = 0.0
var _help_remaining: float = HELP_VISIBLE_SECONDS
var _top_inset: float = 0.0


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
	if _skill_feedback_remaining > 0.0:
		_skill_feedback_remaining = maxf(_skill_feedback_remaining - delta, 0.0)
		if _skill_feedback_remaining <= 0.0:
			_refresh_skill_button()
	if _fire_flash_remaining > 0.0:
		_fire_flash_remaining = maxf(_fire_flash_remaining - delta, 0.0)
		needs_redraw = true
	if is_instance_valid(_help_label) and _help_label.visible and _help_remaining > 0.0:
		_help_remaining = maxf(_help_remaining - delta, 0.0)
		if _help_remaining <= HELP_FADE_SECONDS:
			_help_label.modulate.a = clampf(_help_remaining / HELP_FADE_SECONDS, 0.0, 1.0)
		if _help_remaining <= 0.0:
			_help_label.visible = false
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


func set_skill_cooldown(remaining_seconds: float, total_seconds: float) -> void:
	_skill_cooldown_total = maxf(total_seconds, 0.0)
	_skill_cooldown_remaining = clampf(remaining_seconds, 0.0, _skill_cooldown_total)
	if _skill_cooldown_remaining <= 0.0:
		_skill_feedback_remaining = 0.0
	_refresh_skill_button()


func show_skill_feedback(targets_hit: int) -> void:
	if not is_instance_valid(_skill_button):
		return
	_skill_feedback_remaining = 1.1
	_skill_button.text = "EMP\n%d HIT" % targets_hit if targets_hit > 0 else "EMP\nNO HIT"
	_skill_button.disabled = (_player_down or get_tree().paused or _skill_cooldown_remaining > 0.0)


func _refresh_skill_button() -> void:
	if not is_instance_valid(_skill_button):
		return
	if _skill_feedback_remaining <= 0.0:
		if _skill_cooldown_remaining > 0.0:
			_skill_button.text = "EMP\n%d s" % ceili(_skill_cooldown_remaining)
		else:
			_skill_button.text = "EMP\nREADY"
	_skill_button.disabled = (_player_down or get_tree().paused or _skill_cooldown_remaining > 0.0)


## External aim state (desktop right mouse), so the reticle tightens even when
## the AIM button is not the thing being held.
func set_aim_state(aiming: bool) -> void:
	if _aiming == aiming:
		return
	_aiming = aiming
	queue_redraw()


## Bring the control hint back (called on retry and when the run starts).
func show_help() -> void:
	if not is_instance_valid(_help_label):
		return
	_help_remaining = HELP_VISIBLE_SECONDS
	_help_label.modulate.a = 1.0
	_help_label.visible = true


func _apply_help_readability() -> void:
	var shadow := Color(0.0, 0.02, 0.05, 0.85)
	_help_label.add_theme_color_override("font_shadow_color", shadow)
	_help_label.add_theme_constant_override("shadow_offset_x", 1)
	_help_label.add_theme_constant_override("shadow_offset_y", 1)
	_help_label.add_theme_constant_override("shadow_outline_size", 4)


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
	if is_instance_valid(_aim_button):
		_aim_button.disabled = paused or _player_down
	if paused and _aiming:
		_on_aim_up()
	_refresh_skill_button()


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
	if is_instance_valid(_aim_button):
		_aim_button.disabled = down or get_tree().paused
	if down and _aiming:
		_on_aim_up()
	_refresh_skill_button()


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
	_skill_button.visible = false
	_aim_button.visible = false
	_pause_button.visible = false
	_pause_label.visible = false
	_aiming = false
	queue_redraw()


func hide_results() -> void:
	if not is_instance_valid(_results_panel):
		return
	_results_panel.visible = false
	_top_bar.visible = true
	_help_label.visible = true
	_fire_button.visible = true
	_weapon_button.visible = true
	_skill_button.visible = true
	_aim_button.visible = true
	_pause_button.visible = true
	_pause_label.visible = get_tree().paused
	_refresh_skill_button()
	show_help()


func _build_ui() -> void:
	_top_bar = HBoxContainer.new()
	_top_bar.name = "PlaytestHUD"
	# Anchor to the full width: a bare Control rect collapses to its minimum and
	# the cards then never share the screen.
	_top_bar.anchor_left = 0.0
	_top_bar.anchor_right = 1.0
	_top_bar.anchor_top = 0.0
	_top_bar.anchor_bottom = 0.0
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

	_aim_button = _make_button("AIM", "AimButton")
	_aim_button.add_theme_font_size_override("font_size", 15)
	_aim_button.tooltip_text = "Hold to aim down sights: narrows the camera and steadies the shot"
	_apply_button_theme(_aim_button, Color(0.05, 0.2, 0.3, 0.96), Color(0.35, 0.88, 1.0, 0.9))
	_aim_button.button_down.connect(_on_aim_down)
	_aim_button.button_up.connect(_on_aim_up)

	_skill_button = _make_button("EMP\nREADY", "SkillButton")
	_skill_button.add_theme_font_size_override("font_size", 15)
	_skill_button.tooltip_text = "EMP Pulse: damage nearby enemies. Recharges over time."
	_apply_button_theme(_skill_button, Color(0.04, 0.28, 0.36, 0.98), Color(0.22, 0.86, 1.0, 0.96))
	_skill_button.pressed.connect(_on_skill_pressed)

	_help_label = Label.new()
	_help_label.name = "ControlsHelp"
	_help_label.anchor_left = 0.16
	_help_label.anchor_right = 0.84
	_help_label.anchor_top = 0.0
	_help_label.anchor_bottom = 0.0
	_help_label.offset_top = 116.0
	_help_label.offset_bottom = 154.0
	_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_help_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_help_label.text = (
		"TOUCH: 360° joystick moves · drag right to aim · hold FIRE / AIM · EMP is the skill\n"
		+ "DESKTOP: WASD moves · right mouse aims · hold left mouse to fire · E cycles · R retries"
	)
	_help_label.add_theme_font_size_override("font_size", 12)
	_help_label.add_theme_color_override("font_color", Color(0.76, 0.88, 0.96, 0.92))
	_help_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_help_readability()
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
	_status_label.text = "Score: 0 · BP earned: 0\nKOs: 0 · Time: 00:00\nTarget 54 / 54 · Shots 0"
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
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card.clip_contents = true
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
	var viewport_width := maxf(size.x, 320.0)
	var viewport_height := maxf(size.y, 320.0)
	_ui_scale = clampf(minf(viewport_width, viewport_height) / 720.0, 0.64, 1.0)
	var margin := 14.0 * _ui_scale
	_top_inset = _resolve_top_inset()
	var card_height := 104.0 * _ui_scale
	# The three cards share the available width instead of fighting over a fixed
	# minimum, so a 390 px phone keeps the whole top bar on screen.
	var narrow := viewport_width < 760.0
	_health_card.custom_minimum_size = Vector2(0.0, card_height)
	_health_card.size_flags_stretch_ratio = 0.95 if narrow else 1.0
	_wave_card.custom_minimum_size = Vector2(0.0, card_height)
	_wave_card.size_flags_stretch_ratio = 1.15 if narrow else 1.15
	_run_card.custom_minimum_size = Vector2(0.0, card_height)
	_run_card.size_flags_stretch_ratio = 1.0
	_run_card.visible = not narrow
	_pause_button.custom_minimum_size = Vector2(84.0 * _ui_scale, 52.0 * _ui_scale)
	_pause_button.add_theme_font_size_override("font_size", roundi(14.0 * _ui_scale))
	_top_bar.offset_left = margin
	_top_bar.offset_top = _top_inset
	_top_bar.offset_right = -margin
	_top_bar.offset_bottom = _top_inset + card_height

	var fire_size := minf(142.0 * _ui_scale, minf(viewport_width, viewport_height) * 0.34)
	var base_margin := 20.0 * _ui_scale
	_fire_button.offset_left = -fire_size - base_margin
	_fire_button.offset_top = -fire_size - base_margin
	_fire_button.offset_right = -base_margin
	_fire_button.offset_bottom = -base_margin
	_fire_button.custom_minimum_size = Vector2(fire_size, fire_size)
	_fire_button.add_theme_font_size_override("font_size", roundi(21.0 * _ui_scale))

	var weapon_width := minf(164.0 * _ui_scale, viewport_width * 0.42)
	var weapon_height := 58.0 * _ui_scale
	_weapon_button.offset_left = -weapon_width - base_margin
	_weapon_button.offset_top = -fire_size - base_margin - weapon_height - 12.0 * _ui_scale
	_weapon_button.offset_right = -base_margin
	_weapon_button.offset_bottom = -fire_size - base_margin - 12.0 * _ui_scale
	_weapon_button.custom_minimum_size = Vector2(weapon_width, weapon_height)

	var side_size := minf(94.0 * _ui_scale, minf(viewport_width, viewport_height) * 0.22)
	var side_gap := 12.0 * _ui_scale
	var skill_right := fire_size + base_margin + side_gap
	var side_center_bottom := base_margin + fire_size * 0.5
	_skill_button.offset_left = -skill_right - side_size
	_skill_button.offset_right = -skill_right
	_skill_button.offset_top = -side_center_bottom - side_size * 0.5
	_skill_button.offset_bottom = -side_center_bottom + side_size * 0.5
	_skill_button.custom_minimum_size = Vector2(side_size, side_size)
	_skill_button.add_theme_font_size_override("font_size", roundi(15.0 * _ui_scale))
	var aim_right := skill_right + side_size + side_gap
	_aim_button.offset_left = -aim_right - side_size
	_aim_button.offset_right = -aim_right
	_aim_button.offset_top = -side_center_bottom - side_size * 0.5
	_aim_button.offset_bottom = -side_center_bottom + side_size * 0.5
	_aim_button.custom_minimum_size = Vector2(side_size, side_size)
	_aim_button.add_theme_font_size_override("font_size", roundi(15.0 * _ui_scale))

	var help_top := _top_inset + card_height + 8.0 * _ui_scale
	_help_label.offset_top = help_top
	_help_label.offset_bottom = help_top + 40.0 * _ui_scale
	_help_label.add_theme_font_size_override("font_size", roundi(12.0 * _ui_scale))

	_results_panel.custom_minimum_size = Vector2(440.0 * _ui_scale, 356.0 * _ui_scale)
	var panel_half_width := minf(220.0 * _ui_scale, viewport_width * 0.46)
	_results_panel.offset_left = -panel_half_width
	_results_panel.offset_right = panel_half_width
	var panel_half_height := minf(178.0 * _ui_scale, viewport_height * 0.42)
	_results_panel.offset_top = -panel_half_height
	_results_panel.offset_bottom = panel_half_height
	if is_instance_valid(_pause_label):
		_pause_label.add_theme_font_size_override("font_size", roundi(26.0 * _ui_scale))
	_apply_font_scale()


## Every HUD font is derived from the base size times the UI scale, with a floor
## of 11 px: a smaller factor would technically fit the card but be unreadable.
func _apply_font_scale() -> void:
	for entry in [
		[_health_value_label, 14],
		[_wave_title_label, 17],
		[_wave_state_label, 12],
		[_wave_enemy_label, 12],
		[_status_label, 12],
	]:
		var label := entry[0] as Label
		if is_instance_valid(label):
			label.add_theme_font_size_override(
				"font_size", maxi(roundi(float(entry[1]) * _ui_scale), 11)
			)
	for heading in [_health_card, _wave_card, _run_card]:
		if not is_instance_valid(heading):
			continue
		for child in heading.find_children("*", "Label", true, false):
			var label := child as Label
			if label != null and int(label.get_theme_font_size("font_size")) >= 13:
				label.add_theme_font_size_override("font_size", maxi(roundi(13.0 * _ui_scale), 11))


## Keep the HUD clear of notches and of the browser shell chrome.
func _resolve_top_inset() -> float:
	var inset := 0.0
	if OS.has_feature("web"):
		# Browser chips wrap onto two rows on a narrow screen; reserve for that.
		inset = WEB_TOP_INSET + (WEB_TOP_INSET * 0.8 if size.x < size.y else 0.0)
	var safe_area := DisplayServer.get_display_safe_area()
	if safe_area.position.y > 0:
		inset = maxf(inset, float(safe_area.position.y))
	return inset * _ui_scale + 10.0 * _ui_scale


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
			if not touched_button.disabled:
				# Godot buttons only fire `pressed` on release, so a hold button
				# (AIM) also needs its press forwarded here.
				touched_button.emit_signal("button_down")
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
		if is_instance_valid(button):
			button.emit_signal("button_up")
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
		_skill_button,
		_aim_button,
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
	elif button == _skill_button:
		_on_skill_pressed()
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
		_skill_button,
		_aim_button,
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

	_draw_crosshair()
	_draw_joystick()


## Reticle: a dot with four ticks, drawn for contrast against a bright world.
## Ticks spread with walking and firing, and pull in while aiming, so the player
## can read accuracy state without opening anything.
func _draw_crosshair() -> void:
	if _player_down or get_tree().paused or _results_panel.visible:
		return
	var center := size * 0.5
	var spread := 5.0 + _fire_flash_remaining * 46.0
	if _move_touch_id != -1:
		spread += 4.0
	if _aiming:
		spread *= 0.45
	var tick := 7.0 * _ui_scale
	var gap := (10.0 + spread) * _ui_scale
	var thickness := 2.0 * _ui_scale
	var color := Color(0.52, 0.96, 1.0, 0.95)
	if _hit_confirm_remaining > 0.0:
		color = Color(1.0, 0.72, 0.24, 1.0)
		gap *= 1.25
	# dark outline first so the reticle survives a white floor
	var outline := Color(0.0, 0.03, 0.06, 0.6)
	for offset in [Vector2(1.0, 0.0), Vector2(-1.0, 0.0), Vector2(0.0, 1.0), Vector2(0.0, -1.0)]:
		_draw_crosshair_ticks(center + offset * _ui_scale, gap, tick, thickness, outline)
	_draw_crosshair_ticks(center, gap, tick, thickness, color)
	draw_circle(center, maxf(1.4 * _ui_scale, 1.0), color)
	draw_arc(center, 2.6 * _ui_scale, 0.0, TAU, 16, outline, 1.0)


func _draw_crosshair_ticks(
	center: Vector2, gap: float, tick: float, thickness: float, color: Color
) -> void:
	draw_line(center + Vector2(gap, 0.0), center + Vector2(gap + tick, 0.0), color, thickness)
	draw_line(center - Vector2(gap, 0.0), center - Vector2(gap + tick, 0.0), color, thickness)
	draw_line(center + Vector2(0.0, gap), center + Vector2(0.0, gap + tick), color, thickness)
	draw_line(center - Vector2(0.0, gap), center - Vector2(0.0, gap + tick), color, thickness)


func _draw_joystick() -> void:
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
		_fire_flash_remaining = 1.0
		queue_redraw()
		fire_changed.emit(true)


func _on_fire_up() -> void:
	fire_changed.emit(false)


func _on_aim_down() -> void:
	if _player_down or get_tree().paused:
		return
	_aiming = true
	_set_aim_button_active(true)
	queue_redraw()
	aim_changed.emit(true)


func _on_aim_up() -> void:
	_aiming = false
	_set_aim_button_active(false)
	queue_redraw()
	aim_changed.emit(false)


func _set_aim_button_active(active: bool) -> void:
	if not is_instance_valid(_aim_button):
		return
	_aim_button.modulate = Color(1.0, 1.0, 1.0) if active else Color(0.82, 0.9, 0.98)


func _on_weapon_switch_pressed() -> void:
	if not _player_down and not get_tree().paused:
		Sfx.play_ui(&"ui_click")
		weapon_switch_requested.emit()


func _on_skill_pressed() -> void:
	if not _player_down and not get_tree().paused and _skill_cooldown_remaining <= 0.0:
		Sfx.play_ui(&"ui_click")
		skill_requested.emit()


func _on_pause_pressed() -> void:
	Sfx.play_ui(&"ui_click")
	if _player_down:
		retry_requested.emit()
	else:
		pause_requested.emit()


func _on_results_retry_pressed() -> void:
	Sfx.play_ui(&"ui_click")
	retry_requested.emit()


func _on_window_focus_exited() -> void:
	_clear_touch_state()
