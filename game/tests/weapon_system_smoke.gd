extends SceneTree

const MainScene = preload("res://scenes/main.tscn")


class DamageReceiver:
	extends StaticBody3D
	var damage_calls: Array[float] = []

	func apply_damage(amount: float, _source: Node = null) -> void:
		damage_calls.append(amount)


func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	var main_scene := MainScene.instantiate()
	main_scene.set("start_wave_session_on_ready", false)
	root.add_child(main_scene)
	await process_frame

	var player: Node3D = main_scene.get_node("Player")
	var weapon_controller: Node = player.get_node("WeaponController")
	var muzzle: Marker3D = player.get_node("VisualRoot/WeaponSocket/Muzzle")
	var controls: Node = main_scene.get_node("HUD/TouchControls")
	var weapon_button := controls.get("_weapon_button") as Button
	var test_passed := true

	test_passed = (
		_expect(
			weapon_controller.get("weapon_definitions").size() == 3,
			"Pulse Rifle, Nova Launcher, and Arc Shooter are loaded as data definitions",
		)
		and test_passed
	)
	var pulse_definition: Resource = weapon_controller.call("get_current_definition")
	test_passed = (
		_expect(
			(
				pulse_definition.get("weapon_id") == &"pulse_rifle"
				and is_equal_approx(float(pulse_definition.get("damage")), 18.0)
				and is_equal_approx(float(pulse_definition.get("fire_rate")), 5.0)
			),
			"Pulse Rifle keeps its original damage and fire rate",
		)
		and test_passed
	)
	test_passed = (
		_expect(
			bool(weapon_controller.call("select_weapon", -1)) == false,
			"invalid weapon indexes are rejected",
		)
		and test_passed
	)
	test_passed = (
		_expect(weapon_button.text == "PULSE RIFLE", "touch button shows the selected weapon")
		and test_passed
	)

	weapon_button.emit_signal("pressed")
	test_passed = (
		_expect(
			(
				weapon_controller.call("get_current_weapon_name") == "Nova Launcher"
				and weapon_button.text == "NOVA LAUNCHER"
			),
			"mobile weapon button selects Nova and updates its label",
		)
		and test_passed
	)
	weapon_button.emit_signal("pressed")
	test_passed = (
		_expect(
			(
				weapon_controller.call("get_current_weapon_name") == "Arc Shooter"
				and weapon_button.text == "ARC SHOOTER"
			),
			"mobile weapon button reaches Arc Shooter and updates its label",
		)
		and test_passed
	)
	weapon_button.emit_signal("pressed")
	test_passed = (
		_expect(
			weapon_controller.call("get_current_weapon_name") == "Pulse Rifle",
			"mobile weapon button cycles back to Pulse Rifle",
		)
		and test_passed
	)

	var key_down := InputEventKey.new()
	key_down.physical_keycode = KEY_E
	key_down.pressed = true
	Input.parse_input_event(key_down)
	await physics_frame
	await physics_frame
	var key_up := InputEventKey.new()
	key_up.physical_keycode = KEY_E
	key_up.pressed = false
	Input.parse_input_event(key_up)
	test_passed = (
		_expect(
			weapon_controller.call("get_current_weapon_name") == "Nova Launcher",
			"desktop E input cycles to Nova Launcher",
		)
		and test_passed
	)

	weapon_button.emit_signal("pressed")
	weapon_button.emit_signal("pressed")
	var pulse_target := _create_receiver(main_scene, Vector3(0.34, 1.18, 3.8))
	var blocker := _create_blocker(main_scene, Vector3(0.34, 1.18, 6.0))
	await physics_frame
	test_passed = (
		_expect(
			weapon_controller.call("get_current_weapon_name") == "Pulse Rifle",
			"touch switching can restore Pulse before firing",
		)
		and test_passed
	)

	var first_fire: bool = weapon_controller.call(
		"try_fire", player, muzzle, pulse_target.global_position
	)
	var immediate_repeat: bool = weapon_controller.call(
		"try_fire", player, muzzle, pulse_target.global_position
	)
	test_passed = (
		_expect(first_fire and not immediate_repeat, "Pulse cooldown rejects an immediate repeat")
		and test_passed
	)
	for _frame in 10:
		await physics_frame
	test_passed = (
		_expect(pulse_target.damage_calls.is_empty(), "Pulse projectile is blocked by cover")
		and test_passed
	)
	for _frame in 8:
		await physics_frame
	blocker.queue_free()
	await process_frame
	await physics_frame
	var recovered_fire: bool = weapon_controller.call(
		"try_fire", player, muzzle, pulse_target.global_position
	)
	var repeat_during_cooldown: bool = weapon_controller.call(
		"try_fire", player, muzzle, pulse_target.global_position
	)
	test_passed = (
		_expect(
			recovered_fire and not repeat_during_cooldown,
			"Pulse can fire again after cooldown and is throttled again",
		)
		and test_passed
	)
	for _frame in 30:
		await physics_frame
		if not pulse_target.damage_calls.is_empty():
			break
	test_passed = (
		_expect(
			(
				pulse_target.damage_calls.size() == 1
				and is_equal_approx(pulse_target.damage_calls[0], 18.0)
			),
			"Pulse projectile hits its target once for the original damage",
		)
		and test_passed
	)

	weapon_button.emit_signal("pressed")
	var nova_definition: Resource = weapon_controller.call("get_current_definition")
	test_passed = (
		_expect(
			(
				nova_definition.get("weapon_id") == &"nova_launcher"
				and is_equal_approx(float(nova_definition.get("splash_damage")), 24.0)
				and is_equal_approx(float(nova_definition.get("splash_radius")), 4.0)
			),
			"Nova data definition configures a distinct blast radius and damage",
		)
		and test_passed
	)

	pulse_target.queue_free()
	await process_frame
	var nova_direct := _create_receiver(main_scene, Vector3(0.34, 1.18, 3.8))
	var nova_nearby := _create_receiver(main_scene, Vector3(2.0, 1.18, 3.8))
	var nova_outside := _create_receiver(main_scene, Vector3(6.5, 1.18, 3.8))
	await physics_frame
	var nova_fire: bool = weapon_controller.call(
		"try_fire", player, muzzle, nova_direct.global_position
	)
	var nova_repeat: bool = weapon_controller.call(
		"try_fire", player, muzzle, nova_direct.global_position
	)
	test_passed = (
		_expect(nova_fire and not nova_repeat, "Nova Launcher has an independent cooldown")
		and test_passed
	)
	for _frame in 45:
		await physics_frame
		if not nova_direct.damage_calls.is_empty() and not nova_nearby.damage_calls.is_empty():
			break
	test_passed = (
		_expect(
			(
				nova_direct.damage_calls.size() == 1
				and is_equal_approx(nova_direct.damage_calls[0], 34.0)
			),
			"Nova projectile applies direct impact damage once",
		)
		and test_passed
	)
	test_passed = (
		_expect(
			(
				nova_nearby.damage_calls.size() == 1
				and is_equal_approx(nova_nearby.damage_calls[0], 24.0)
			),
			"Nova explosion damages a nearby target once",
		)
		and test_passed
	)
	test_passed = (
		_expect(
			nova_outside.damage_calls.is_empty(),
			"Nova explosion does not damage targets outside its radius",
		)
		and test_passed
	)

	main_scene.queue_free()
	await process_frame
	if test_passed:
		print("Weapon system smoke test passed.")
		quit()
	else:
		quit(1)


func _create_receiver(parent: Node, at_position: Vector3) -> DamageReceiver:
	var receiver := DamageReceiver.new()
	receiver.name = "DamageReceiver"
	receiver.position = at_position
	receiver.collision_layer = 2
	receiver.collision_mask = 0
	var shape := SphereShape3D.new()
	shape.radius = 0.42
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = shape
	receiver.add_child(collision_shape)
	parent.add_child(receiver)
	return receiver


func _create_blocker(parent: Node, at_position: Vector3) -> StaticBody3D:
	var blocker := StaticBody3D.new()
	blocker.name = "WeaponBlocker"
	blocker.position = at_position
	blocker.collision_layer = 1
	blocker.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.0, 3.0, 0.3)
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = shape
	blocker.add_child(collision_shape)
	parent.add_child(blocker)
	return blocker


func _expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error("Weapon system smoke test failed: " + message)
	return condition
