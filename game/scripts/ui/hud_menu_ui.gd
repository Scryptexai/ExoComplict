## Construction of modal pause and results cards. The TouchControls facade
## owns their signals and state; this helper only creates the UI nodes.
class_name HudMenuUi
extends RefCounted


static func build_pause(hud) -> void:
	hud._pause_panel = AegisPanel.new()
	hud._pause_panel.name = "PausePanel"
	hud._pause_panel.interactive = true
	hud._pause_panel.visible = false
	hud.add_child(hud._pause_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	hud._pause_panel.add_child(content)

	hud._pause_swipe_handle = ColorRect.new()
	hud._pause_swipe_handle.name = "PauseSwipeHandle"
	hud._pause_swipe_handle.color = AegisTokens.LINE_HI
	hud._pause_swipe_handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud._pause_swipe_handle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(hud._pause_swipe_handle)

	var eyebrow: Label = hud._label("RUN SUSPENDED", "label", AegisTokens.ACCENT)
	content.add_child(eyebrow)
	hud._pause_label = hud._label("PAUSED", "display_l", AegisTokens.INK)
	content.add_child(hud._pause_label)
	hud._pause_stats_label = hud._label("SCORE 0  ·  00:00", "mono_m", AegisTokens.INK_2)
	content.add_child(hud._pause_stats_label)

	var rule := ColorRect.new()
	rule.color = AegisTokens.LINE
	rule.custom_minimum_size = Vector2(0.0, 1.0)
	content.add_child(rule)

	hud._pause_resume_button = AegisButton.new()
	hud._pause_resume_button.name = "ResumeButton"
	hud._pause_resume_button.text = "RESUME"
	hud._pause_resume_button.focus_mode = Control.FOCUS_ALL
	hud._pause_resume_button.mouse_filter = Control.MOUSE_FILTER_STOP
	hud._pause_resume_button.icon = AegisTheme.icon("play", true)
	hud._pause_resume_button.add_theme_constant_override("icon_max_width", 18)
	AegisTheme.set_button_variant(hud._pause_resume_button, "primary")
	hud._pause_resume_button.pressed.connect(hud._on_pause_pressed)
	content.add_child(hud._pause_resume_button)
	hud._touch_buttons.append(hud._pause_resume_button)

	hud._pause_restart_button = AegisButton.new()
	hud._pause_restart_button.name = "RestartButton"
	hud._pause_restart_button.text = "RESTART RUN"
	hud._pause_restart_button.focus_mode = Control.FOCUS_ALL
	hud._pause_restart_button.mouse_filter = Control.MOUSE_FILTER_STOP
	hud._pause_restart_button.icon = AegisTheme.icon("arrow-counter-clockwise")
	hud._pause_restart_button.add_theme_constant_override("icon_max_width", 18)
	AegisTheme.set_button_variant(hud._pause_restart_button, "ghost")
	hud._pause_restart_button.pressed.connect(hud._on_restart_pressed)
	content.add_child(hud._pause_restart_button)
	hud._touch_buttons.append(hud._pause_restart_button)

	hud._pause_settings_button = AegisButton.new()
	hud._pause_settings_button.name = "SettingsButton"
	hud._pause_settings_button.text = "SETTINGS"
	hud._pause_settings_button.icon = AegisTheme.icon("gear-six")
	hud._pause_settings_button.focus_mode = Control.FOCUS_ALL
	AegisTheme.set_button_variant(hud._pause_settings_button, "ghost")
	hud._pause_settings_button.pressed.connect(hud._open_settings)
	content.add_child(hud._pause_settings_button)
	hud._touch_buttons.append(hud._pause_settings_button)

	var hint: Label = hud._label("SETTINGS → CONTROLS · ESC RESUME", "label_s", AegisTokens.INK_3)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(hint)


static func build_results(hud) -> void:
	hud._results_panel = AegisPanel.new()
	hud._results_panel.name = "ResultsPanel"
	hud._results_panel.interactive = true
	hud._results_panel.visible = false
	hud.add_child(hud._results_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	hud._results_panel.add_child(content)

	content.add_child(hud._label("RUN COMPLETE", "label", AegisTokens.ACCENT))
	hud._results_title = hud._label("RUN RESULTS", "display_xl", AegisTokens.INK)
	content.add_child(hud._results_title)

	var rule := ColorRect.new()
	rule.color = AegisTokens.LINE
	rule.custom_minimum_size = Vector2(0.0, 1.0)
	content.add_child(rule)

	hud._results_summary = hud._label("", "mono_m", AegisTokens.INK_2)
	hud._results_summary.autowrap_mode = TextServer.AUTOWRAP_OFF
	hud._results_summary.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(hud._results_summary)

	hud._results_retry_button = AegisButton.new()
	hud._results_retry_button.name = "ResultsRetryButton"
	hud._results_retry_button.text = "RETRY"
	hud._results_retry_button.focus_mode = Control.FOCUS_ALL
	hud._results_retry_button.mouse_filter = Control.MOUSE_FILTER_STOP
	hud._results_retry_button.icon = AegisTheme.icon("arrow-counter-clockwise")
	hud._results_retry_button.add_theme_constant_override("icon_max_width", 18)
	AegisTheme.set_button_variant(hud._results_retry_button, "primary")
	hud._results_retry_button.pressed.connect(hud._on_results_retry_pressed)
	content.add_child(hud._results_retry_button)
	hud._touch_buttons.append(hud._results_retry_button)

	hud._results_explore_button = AegisButton.new()
	hud._results_explore_button.name = "ResultsExploreButton"
	hud._results_explore_button.text = "RETURN TO EXPLORE"
	hud._results_explore_button.focus_mode = Control.FOCUS_ALL
	hud._results_explore_button.mouse_filter = Control.MOUSE_FILTER_STOP
	hud._results_explore_button.icon = AegisTheme.icon("caret-right")
	AegisTheme.set_button_variant(hud._results_explore_button, "ghost")
	hud._results_explore_button.pressed.connect(hud._on_return_to_explore_pressed)
	content.add_child(hud._results_explore_button)
	hud._touch_buttons.append(hud._results_explore_button)
