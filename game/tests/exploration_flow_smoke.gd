extends SceneTree

## Contract for the user-selected flow: boot into safe Explore, opt in with an
## explicit action, prepare before wave 1, then always allow returning to safety.
const MainScene = preload("res://scenes/main.tscn")

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := MainScene.instantiate()
	root.add_child(main)
	await process_frame
	var wave := main.get_node("WaveDirector")
	var player := main.get_node("Player")
	var hud := main.get_node("HUD/TouchControls")
	var start := hud.get("_defense_button") as Button
	var objective := hud.get("_wave_title_label") as Label
	var health_before := float(player.get("current_health"))
	_expect(
		(
			not bool(main.get("start_wave_session_on_ready"))
			and int(main.get("session_mode")) == 0
			and int(wave.get("current_wave")) == 0
			and start.visible
			and objective.text.contains("EXPLORE")
		),
		"boot defaults to safe Explore with a clearly labeled Defense action",
	)
	# Simulate sixty seconds of idle time without a real-time delay. Check the
	# WaveDirector after actual physics frames too: only an explicit action may
	# change its state, not elapsed time or a HUD redraw.
	main.call("_process", 60.0)
	for _frame in 12:
		await physics_frame
	_expect(
		(
			int(wave.get("current_wave")) == 0
			and not bool(wave.get("_session_running"))
			and wave.call("get_active_enemies").is_empty()
			and is_equal_approx(float(player.get("current_health")), health_before)
		),
		"sixty simulated seconds and live physics do not spawn or damage in Explore",
	)
	var binding_found := false
	for binding in InputMap.action_get_events("start_defense"):
		if binding is InputEventKey and binding.physical_keycode == KEY_B:
			binding_found = true
	_expect(binding_found, "B has a discoverable keyboard action for Defense")

	# Exercise the actual mobile touch dispatcher, not just the signal handler.
	hud.call("set_touch_mode", true)
	hud.call("apply_layout_for_size", Vector2(390.0, 844.0), 1.0)
	await process_frame
	_tap(hud, start)
	_expect(
		(
			int(main.get("session_mode")) == 1
			and start.disabled
			and start.text.contains("DEFENSE IN")
			and (hud.get("_wave_enemy_label") as Label).text == "GET READY · SPAWNS MARKED"
			and int(wave.get("current_wave")) == 0
		),
		"touching START DEFENSE enters a visible preparation, not instant combat",
	)
	main.call("_process", 3.9)
	await physics_frame
	_expect(
		int(wave.get("current_wave")) == 0 and wave.call("get_active_enemies").is_empty(),
		"no enemy may spawn before the preparation countdown expires",
	)
	main.call("_process", 1.2)
	_expect(
		(
			int(main.get("session_mode")) == 2
			and int(wave.get("current_wave")) == 1
			and objective.text == "WAVE 01"
		),
		"the first wave begins only after an explicit start plus countdown",
	)

	main.call("_toggle_pause")
	var escape := hud.get("_pause_restart_button") as Button
	_expect(paused and escape.text == "RETURN TO EXPLORE", "Defense pause exposes a real exit")
	escape.pressed.emit()
	_expect(
		(
			not paused
			and int(main.get("session_mode")) == 0
			and int(wave.get("current_wave")) == 0
			and wave.call("get_active_enemies").is_empty()
			and is_equal_approx(float(player.get("current_health")), health_before)
		),
		"exit clears the wave, unpauses and restores health in safe Explore",
	)

	# Complete a run via the director to verify the results screen has both
	# choices. Retry must prepare again; RETURN TO EXPLORE must not spawn.
	start.pressed.emit()
	main.call("_process", 5.1)
	wave.call("end_session")
	var results := hud.get("_results_panel") as Control
	var retry := hud.get("_results_retry_button") as Button
	var explore := hud.get("_results_explore_button") as Button
	_expect(
		results.visible and retry.is_visible_in_tree() and explore.is_visible_in_tree(),
		"results display distinct RETRY and RETURN TO EXPLORE actions",
	)
	retry.pressed.emit()
	_expect(
		int(main.get("session_mode")) == 1 and int(wave.get("current_wave")) == 0,
		"RETRY restarts preparation without an immediate spawn",
	)
	main.call("_process", 5.1)
	wave.call("end_session")
	explore.pressed.emit()
	_expect(
		(
			int(main.get("session_mode")) == 0
			and not results.visible
			and int(wave.get("current_wave")) == 0
		),
		"results RETURN TO EXPLORE never restarts combat",
	)

	main.queue_free()
	await process_frame
	if _failures > 0:
		printerr("Exploration flow smoke: %d failure(s)" % _failures)
		quit(1)
	else:
		print("Exploration flow smoke: PASS")
		quit()


func _tap(hud: Control, button: Button) -> void:
	var position := button.get_global_rect().get_center()
	var touch := InputEventScreenTouch.new()
	touch.index = 61
	touch.position = position
	touch.pressed = true
	hud.call("_input", touch)
	touch.pressed = false
	hud.call("_input", touch)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("  PASS: ", label)
	else:
		printerr("  FAIL: ", label)
		_failures += 1
