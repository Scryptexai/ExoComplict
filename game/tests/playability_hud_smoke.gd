extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	var main_scene := MainScene.instantiate()
	main_scene.set("start_wave_session_on_ready", false)
	root.add_child(main_scene)
	await process_frame

	var player: Node3D = main_scene.get_node("Player")
	var wave_director: Node = main_scene.get_node("WaveDirector")
	var controls: Control = main_scene.get_node("HUD/TouchControls")
	var health_bar := controls.get("_health_bar") as ProgressBar
	var health_value := controls.get("_health_value_label") as Label
	var wave_title := controls.get("_wave_title_label") as Label
	var wave_enemy_label := controls.get("_wave_enemy_label") as Label
	var status_label := controls.get("_status_label") as Label
	var help_label := controls.get("_help_label") as Label
	var fire_button := controls.get("_fire_button") as Button
	var weapon_button := controls.get("_weapon_button") as Button
	var pause_button := controls.get("_pause_button") as Button
	var spring_arm := player.get_node("CameraRig/YawPivot/PitchPivot/SpringArm3D") as SpringArm3D
	var pitch_pivot := player.get_node("CameraRig/YawPivot/PitchPivot") as Node3D

	_expect(
		(
			is_instance_valid(health_bar)
			and is_instance_valid(wave_title)
			and is_instance_valid(status_label)
		),
		"playtest HUD builds health, wave, and run-data cards",
	)
	_expect(
		is_equal_approx(health_bar.value, 100.0) and health_value.text == "100 / 100",
		"health bar reflects the live player health",
	)
	_expect(
		wave_title.text == "FRONTIER DEFENSE" and wave_enemy_label.text.contains("0 ACTIVE"),
		"wave HUD starts in a clear ready state",
	)
	_expect(
		(
			help_label.autowrap_mode != TextServer.AUTOWRAP_OFF
			and help_label.text.contains("TOUCH")
			and help_label.text.contains("WASD")
		),
		"wrapped help explains mobile and desktop controls",
	)
	_expect(
		(
			fire_button.text == "FIRE"
			and weapon_button.text == "PULSE RIFLE"
			and pause_button.text == "PAUSE"
		),
		"fire, weapon-cycle, and pause buttons are visible and labeled",
	)
	_expect(
		(
			is_equal_approx(spring_arm.spring_length, 4.15)
			and spring_arm.position.x > 0.25
			and pitch_pivot.rotation.x < -0.1
		),
		"camera rig uses a close rear follow, right-shoulder offset, and downward pitch",
	)

	var shots_before_touch_fire := int(main_scene.get("_shots_fired"))
	_send_screen_touch(controls, 70, fire_button.get_global_rect().get_center(), true)
	for _frame in 2:
		await physics_frame
	_expect(
		(
			bool(player.get("_touch_fire_pressed"))
			and int(main_scene.get("_shots_fired")) > shots_before_touch_fire
		),
		"screen touch on FIRE reaches the player and spawns a combat shot",
	)
	_send_screen_touch(controls, 70, fire_button.get_global_rect().get_center(), false)
	_expect(
		not bool(player.get("_touch_fire_pressed")),
		"screen touch release on FIRE clears the player input state",
	)

	player.call("apply_damage", 27.0)
	_expect(
		is_equal_approx(health_bar.value, 73.0) and health_value.text == "73 / 100",
		"taking damage updates the health bar immediately",
	)

	wave_director.call("start_session")
	_expect(
		wave_title.text == "WAVE 01" and wave_enemy_label.text.ends_with("3 LEFT"),
		"starting a wave updates wave number and remaining-enemy count",
	)

	_tap_screen_button(controls, weapon_button, 73)
	_expect(
		(
			player.call("get_current_weapon_name") == "Nova Launcher"
			and weapon_button.text == "NOVA LAUNCHER"
		),
		"touching the weapon button cycles the active weapon and HUD label",
	)

	var initial_position: Vector3 = player.global_position
	var joystick_touch := InputEventScreenTouch.new()
	joystick_touch.index = 71
	joystick_touch.position = Vector2(controls.size.x * 0.12, controls.size.y * 0.62)
	joystick_touch.pressed = true
	controls.call("_input", joystick_touch)
	var joystick_drag := InputEventScreenDrag.new()
	joystick_drag.index = 71
	joystick_drag.position = joystick_touch.position + Vector2(0.0, -90.0)
	joystick_drag.relative = Vector2(0.0, -90.0)
	controls.call("_input", joystick_drag)
	_expect(
		(Vector2(player.get("_touch_movement")) - Vector2(0.0, -1.0)).length() < 0.02,
		"left-side touch drag maps to forward movement input",
	)
	for _frame in 18:
		await physics_frame
	_expect(
		player.global_position.z < initial_position.z - 0.35,
		"touch movement moves the player through the 3D world",
	)
	var joystick_release := InputEventScreenTouch.new()
	joystick_release.index = 71
	joystick_release.position = joystick_drag.position
	joystick_release.pressed = false
	controls.call("_input", joystick_release)
	_expect(
		Vector2(player.get("_touch_movement")).is_zero_approx(),
		"releasing the movement touch clears the virtual joystick",
	)

	var yaw_pivot: Node3D = player.get_node("CameraRig/YawPivot")
	var yaw_before := yaw_pivot.rotation.y
	var look_touch := InputEventScreenTouch.new()
	look_touch.index = 72
	look_touch.position = Vector2(controls.size.x * 0.82, controls.size.y * 0.58)
	look_touch.pressed = true
	controls.call("_input", look_touch)
	var look_drag := InputEventScreenDrag.new()
	look_drag.index = 72
	look_drag.position = look_touch.position + Vector2(60.0, 0.0)
	look_drag.relative = Vector2(60.0, 0.0)
	controls.call("_input", look_drag)
	_expect(
		not is_equal_approx(yaw_pivot.rotation.y, yaw_before),
		"right-side touch drag rotates the over-the-shoulder camera",
	)
	var look_release := InputEventScreenTouch.new()
	look_release.index = 72
	look_release.position = look_drag.position
	look_release.pressed = false
	controls.call("_input", look_release)

	_send_screen_touch(controls, 74, fire_button.get_global_rect().get_center(), true)
	_expect(bool(player.get("_touch_fire_pressed")), "holding FIRE sets the player fire state")
	_tap_screen_button(controls, pause_button, 75)
	_expect(
		(
			paused
			and not bool(player.get("_touch_fire_pressed"))
			and Vector2(player.get("_touch_movement")).is_zero_approx()
		),
		"pausing clears held touch fire and movement input",
	)
	_expect(fire_button.disabled, "fire is disabled while the run is paused")
	_tap_screen_button(controls, pause_button, 76)
	_expect(not paused and pause_button.text == "PAUSE", "RESUME restores play input")

	var run_stats: Node = main_scene.get_node("RunStats")
	run_stats.call("start_run")
	run_stats.call("record_elimination", 100, 110)
	_expect(
		status_label.text.contains("Score: 100") and status_label.text.contains("BP earned: 110"),
		"run score and earned Battle Points update on the HUD",
	)
	player.call("apply_damage", 1000.0)
	var results_panel := controls.get("_results_panel") as PanelContainer
	var results_retry_button := controls.get("_results_retry_button") as Button
	_expect(
		results_panel.visible and results_retry_button.is_visible_in_tree(),
		"defeat presents a touch-reachable retry button",
	)
	_tap_screen_button(controls, results_retry_button, 77)
	_expect(
		(
			not bool(player.call("is_defeated"))
			and is_equal_approx(health_bar.value, 100.0)
			and not results_panel.visible
		),
		"touching results RETRY restores the player and returns to the HUD",
	)
	print("Playability/HUD smoke test: %d failure(s)" % _failures)
	main_scene.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


func _send_screen_touch(controls: Control, touch_id: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = touch_id
	event.position = position
	event.pressed = pressed
	controls.call("_input", event)


func _tap_screen_button(controls: Control, button: Button, touch_id: int) -> void:
	var position := button.get_global_rect().get_center()
	_send_screen_touch(controls, touch_id, position, true)
	_send_screen_touch(controls, touch_id, position, false)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)
