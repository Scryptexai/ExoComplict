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
	AegisTheme.set_button_variant(hud._pause_restart_button, "round")
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

	hud._results_eyebrow = hud._label("RUN COMPLETE", "label", AegisTokens.ACCENT)
	content.add_child(hud._results_eyebrow)
	hud._results_title = hud._label("RUN RESULTS", "display_xl", AegisTokens.INK)
	content.add_child(hud._results_title)

	var rule := ColorRect.new()
	rule.color = AegisTokens.LINE
	rule.custom_minimum_size = Vector2(0.0, 1.0)
	content.add_child(rule)

	# The report scrolls on short landscape viewports; the two run decisions
	# remain pinned and reachable. Portrait has room to display all of it.
	var report_scroll := ScrollContainer.new()
	report_scroll.name = "RunReportScroll"
	report_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	report_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	report_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	content.add_child(report_scroll)
	var report := VBoxContainer.new()
	report.add_theme_constant_override("separation", 12)
	report.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	report_scroll.add_child(report)

	hud._results_reward_label = hud._label("+0 BP BANKED", "mono_l", AegisTokens.ACCENT)
	hud._results_reward_label.set_meta("aegis_scale", 1.4)
	report.add_child(hud._results_reward_label)
	hud._results_goal_label = hud._label("NEXT LOADOUT · NOVA LAUNCHER", "label", AegisTokens.INK)
	hud._results_goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report.add_child(hud._results_goal_label)
	hud._results_goal_progress_label = hud._label("0 / 120 BP", "mono_m", AegisTokens.INK_2)
	report.add_child(hud._results_goal_progress_label)
	hud._results_goal_bar = ProgressBar.new()
	hud._results_goal_bar.name = "NextUnlockProgress"
	hud._results_goal_bar.show_percentage = false
	hud._results_goal_bar.min_value = 0
	hud._results_goal_bar.max_value = 120
	hud._results_goal_bar.add_theme_stylebox_override(
		"background", AegisTheme.flat_style(AegisTokens.LINE)
	)
	hud._results_goal_bar.add_theme_stylebox_override(
		"fill", AegisTheme.flat_style(AegisTokens.ACCENT)
	)
	report.add_child(hud._results_goal_bar)
	var goal_rule := ColorRect.new()
	goal_rule.color = AegisTokens.LINE_HI
	goal_rule.custom_minimum_size = Vector2(0.0, 1.0)
	report.add_child(goal_rule)
	hud._results_summary = hud._label("", "mono_m", AegisTokens.INK_2)
	hud._results_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report.add_child(hud._results_summary)
	var hint: Label = hud._label(
		"10 BP PER KO · 100 BP PER CLEARED WAVE", "caption", AegisTokens.INK_3
	)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report.add_child(hint)

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
	AegisTheme.set_button_variant(hud._results_explore_button, "round")
	hud._results_explore_button.pressed.connect(hud._on_return_to_explore_pressed)
	content.add_child(hud._results_explore_button)
	hud._touch_buttons.append(hud._results_explore_button)


## Results makes the objective -> earned reward -> next loadout relationship
## visible. Purchases still live exclusively in ProgressionService/Main.
static func update_results(
	hud,
	wave_reached: int,
	survival_time: String,
	eliminations: int,
	run_score: int,
	bp_earned: int,
	wallet_bp: int,
	best_score: int,
	unlocked_ids: Dictionary,
	was_defeated: bool,
) -> void:
	hud._results_eyebrow.text = "RUN ENDED" if was_defeated else "RUN COMPLETE"
	hud._results_title.text = "RECOVER" if wave_reached <= 0 else "WAVE %02d" % wave_reached
	hud._results_retry_button.text = "RETRY EXPLORE" if wave_reached <= 0 else "RETRY DEFENSE"
	hud._results_reward_label.text = (
		"NO BP · NO RUN STARTED" if wave_reached <= 0 else "+%d BP BANKED" % bp_earned
	)
	hud._results_summary.text = (
		"WAVE %02d  ·  SURVIVED %s\n" % [maxi(wave_reached, 0), survival_time]
		+ "ELIMINATIONS %d  ·  SCORE %s\n" % [eliminations, hud._format_number(run_score)]
		+ "BEST SCORE %s  ·  WALLET %d BP" % [hud._format_number(best_score), wallet_bp]
	)

	var next_cost := 0
	var next_name := ""
	if not unlocked_ids.has("nova_launcher"):
		next_cost = int(ProgressionService.COSTS["nova_launcher"])
		next_name = "NOVA LAUNCHER"
	elif not unlocked_ids.has("arc_shooter"):
		next_cost = int(ProgressionService.COSTS["arc_shooter"])
		next_name = "ARC SHOOTER"
	if next_cost > 0:
		hud._results_goal_label.text = "NEXT LOADOUT · " + next_name
		hud._results_goal_progress_label.text = (
			"READY TO UNLOCK · OPEN ARMORY IN EXPLORE"
			if wallet_bp >= next_cost
			else "%d / %d BP  ·  %d TO GO" % [wallet_bp, next_cost, next_cost - wallet_bp]
		)
		hud._results_goal_bar.max_value = next_cost
		hud._results_goal_bar.value = mini(wallet_bp, next_cost)
	else:
		hud._results_goal_label.text = "ARSENAL COMPLETE"
		hud._results_goal_progress_label.text = "ALL LOADOUTS READY · EQUIP IN ARMORY"
		hud._results_goal_bar.max_value = 1
		hud._results_goal_bar.value = 1
