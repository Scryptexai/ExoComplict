## Front-end menu layout probe.
##
## Screenshots cannot be read in this environment, and a layout that fits one
## screen can pour off the next: the dashboard that measures 56 px buttons at
## 390x844 put DEPLOY at y=444 on a 390 px tall landscape screen, and a card
## list that scrolls nicely in portrait leaves a ~130 px window in landscape.
##
## So this test renders the real `front_end.tscn` inside SubViewports sized like
## a phone in both orientations (plus a small phone and a desktop window),
## walks every visible control, and asserts two things in *physical* pixels:
##
##   * nothing that is not inside a scroll container is drawn outside the
##     viewport -- the failure that hides a button below the bottom edge;
##   * every button is still at least MIN_TOUCH_PX tall and wide enough to hit.
##
## It also prints a rect report in the same format as `?qa_menu=1`, so the
## numbers measured headlessly can be compared with the numbers measured in a
## real browser at the same viewport.
extends SceneTree

const FrontEndScene = preload("res://scenes/ui/front_end.tscn")
## Distinct from the real save so the suite never reads a developer profile.
const PROFILE_PATH := "user://menu_layout_smoke_profile.cfg"

const SIZES := {
	"portrait": Vector2i(390, 844),
	"landscape": Vector2i(844, 390),
	"small portrait": Vector2i(360, 640),
	"desktop": Vector2i(1280, 720),
}
## The four menu screens that carry the layout: the hub and the three
## selection lists. BOOT/LOADING/CINEMATIC/CHAPTER/PRELOAD are single-purpose
## panels with no edge-hugging actions.
const STAGES := [&"DASHBOARD", &"HERO", &"WEAPON", &"WORLD"]
## AegisTokens.MIN_TOUCH_PX, less a pixel of rounding.
const MIN_TOUCH := 55.0

var _failures: Array[String] = []
var _viewport: SubViewport = null
var _front_end: Control = null


func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	for size_name in SIZES:
		var size: Vector2i = SIZES[size_name]
		await _mount(size)
		for stage_name in STAGES:
			await _probe(stage_name, size_name, Vector2(size))
	_teardown()
	if _failures.is_empty():
		print("Menu layout smoke test passed.")
		quit(0)
		return
	print("Menu layout smoke test FAILED:")
	for failure in _failures:
		print("  fail: " + failure)
	quit(1)


## Puts the front end inside a SubViewport of exactly `size`. `MenuStage` reads
## its physical size from the window and falls back to the viewport when the
## window is not real -- which is the case headless -- so the SubViewport size
## is what every layout decision is made against.
func _mount(size: Vector2i) -> void:
	_teardown()
	_viewport = SubViewport.new()
	_viewport.size = size
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.name = "LayoutProbe"
	root.add_child(_viewport)
	_front_end = FrontEndScene.instantiate()
	_front_end.set_anchors_preset(Control.PRESET_FULL_RECT)
	_front_end.get_node("ProgressionService").set("profile_path", PROFILE_PATH)
	_viewport.add_child(_front_end)
	await process_frame
	await process_frame


func _teardown() -> void:
	if is_instance_valid(_front_end):
		_front_end.free()
		_front_end = null
	if is_instance_valid(_viewport):
		_viewport.free()
		_viewport = null


func _probe(stage_name: StringName, size_name: String, physical: Vector2) -> void:
	_front_end.call("go_to", stage_name, {})
	await process_frame
	await process_frame
	var stage: Control = _front_end.get_node_or_null("StageHost/" + str(stage_name)) as Control
	if not _expect(is_instance_valid(stage), "%s %s: stage is mounted" % [stage_name, size_name]):
		return
	var stretch: float = HudLayout.compute_stretch(stage, physical)
	var viewport := Rect2(Vector2.ZERO, physical)
	var lines := PackedStringArray()
	lines.append("STAGE=%s %s" % [stage_name, size_name])
	lines.append(
		(
			"CANVAS=%dx%d PHYSICAL=%dx%d STRETCH=%.3f"
			% [
				roundi(stage.size.x),
				roundi(stage.size.y),
				roundi(physical.x),
				roundi(physical.y),
				stretch
			]
		)
	)
	for child in stage.find_children("*", "Control", true, false):
		var control := child as Control
		if control == null or not control.is_visible_in_tree():
			continue
		if not (control is Button or control is Label or control is ProgressBar):
			continue
		var name := str(control.name)
		if control is Button and not (control as Button).text.is_empty():
			name = (control as Button).text
		elif control is Label and not (control as Label).text.is_empty():
			name = (control as Label).text.substr(0, mini((control as Label).text.length(), 18))
		var global := control.get_global_rect()
		var rect := Rect2(global.position * stretch, global.size * stretch)
		lines.append(
			(
				"%s=%.0f,%.0f,%.0fx%.0f"
				% [name, rect.position.x, rect.position.y, rect.size.x, rect.size.y]
			)
		)
		_check(control, rect, viewport, "%s %s" % [stage_name, size_name])
	print("Menu layout: " + " | ".join(lines))


## The two rules. A control inside a ScrollContainer is allowed to sit outside
## the viewport: that is what scrolling is for, and clipping it is the
## container's job. Everything else has to be on screen to be usable.
func _check(control: Control, rect: Rect2, viewport: Rect2, where: String) -> void:
	var name := str(control.name)
	if control is Button and not (control as Button).text.is_empty():
		name = (control as Button).text
	if _inside_scroll_container(control):
		return
	if (
		rect.position.x < -1.0
		or rect.position.y < -1.0
		or rect.end.x > viewport.size.x + 1.0
		or rect.end.y > viewport.size.y + 1.0
	):
		_fail(
			(
				"%s: %s is outside the viewport (%.0f,%.0f %.0fx%.0f in %.0fx%.0f)"
				% [
					where,
					name,
					rect.position.x,
					rect.position.y,
					rect.size.x,
					rect.size.y,
					viewport.size.x,
					viewport.size.y
				]
			)
		)
	if control is Button and not (control as Button).text.is_empty():
		if rect.size.y + 0.5 < MIN_TOUCH:
			_fail(
				(
					"%s: %s is only %.0f px tall, under the %.0f px touch floor"
					% [where, name, rect.size.y, MIN_TOUCH]
				)
			)
		if rect.size.x + 0.5 < MIN_TOUCH:
			_fail.call(
				(
					"%s: %s is only %.0f px wide, under the %.0f px floor"
					% [where, name, rect.size.x, MIN_TOUCH]
				)
			)


func _inside_scroll_container(control: Control) -> bool:
	var node: Node = control.get_parent()
	while node != null:
		if node is ScrollContainer:
			return true
		node = node.get_parent()
	return false


func _expect(condition: bool, message: String) -> bool:
	if condition:
		print("  ok: " + message)
		return true
	_fail(message)
	return false


func _fail(message: String) -> void:
	print("  fail: " + message)
	_failures.append(message)
