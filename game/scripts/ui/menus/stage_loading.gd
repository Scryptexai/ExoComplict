## LOADING and PRELOAD: one implementation, two stages.
##
## The bar is driven by `ResourceLoader.load_threaded_get_status`, so the
## percentage is the engine's own count of resources fetched, not a timer. When
## there is nothing real to load the stage refuses to invent a number: it shows
## an indeterminate sweep instead and says so.
##
## Payload:
##   targets: Array[String]  resource paths to fetch, in order
##   title:   String         heading text
##   next:    StringName     stage to enter when the queue drains
##   scene:   String         if set, change to this scene instead of going to a
##                           stage (used by PRELOAD for the gameplay scene)
extends MenuStage

## The walk cycle built by tools/art/build_ui_art.py: 2048x512, four 512 px
## cells. Keeping the animation in a single atlas means one import and one draw
## call instead of four textures swapping.
const ROBOT_SHEET := "res://assets/ui/loading_robot_sheet.png"
const ROBOT_CELL := 512.0
const ROBOT_FRAMES := 4
const ROBOT_FPS := 8.0

var _targets: Array[String] = []
var _index := 0
var _failed: Array[String] = []
var _title: Label
var _bar: ProgressBar
var _percent: Label
var _status: Label
var _robot: TextureRect
var _robot_atlas: AtlasTexture
var _robot_time := 0.0
var _indeterminate: MenuIndeterminateBar
var _reduce_motion := false
var _done := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(make_backdrop("res://assets/ui/loading_keyart.jpg"))

	# The key art is a photograph; a flat scrim is what makes the caption and
	# the bar readable on top of it at every aspect ratio.
	var scrim := ColorRect.new()
	scrim.color = Color(AegisTokens.VOID, 0.72)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	apply_safe_margins(margin)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_END
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)

	_title = make_label("LOADING", "display_l", AegisTokens.INK)
	column.add_child(_title)

	_status = make_label("", "label", AegisTokens.INK_2)
	column.add_child(_status)

	_robot = TextureRect.new()
	_robot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_robot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_robot.custom_minimum_size = Vector2(160.0, 160.0)
	_robot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sheet := try_texture(ROBOT_SHEET)
	if sheet != null:
		_robot_atlas = AtlasTexture.new()
		_robot_atlas.atlas = sheet
		_robot_atlas.region = Rect2(0.0, 0.0, ROBOT_CELL, ROBOT_CELL)
		_robot.texture = _robot_atlas
	column.add_child(_robot)

	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.value = 0.0
	_bar.custom_minimum_size = Vector2(0.0, 8.0)
	column.add_child(_bar)

	_indeterminate = MenuIndeterminateBar.new()
	_indeterminate.custom_minimum_size = Vector2(0.0, 8.0)
	_indeterminate.visible = false
	column.add_child(_indeterminate)

	_percent = make_label("", "mono_m", AegisTokens.INFO)
	column.add_child(_percent)


func enter(stage_payload: Dictionary) -> void:
	_reduce_motion = bool(AegisPreferences.read().get("reduce_motion", false))
	_targets = []
	for path in stage_payload.get("targets", []):
		_targets.append(str(path))
	_index = 0
	_failed = []
	_done = false
	_robot_time = 0.0
	_title.text = str(stage_payload.get("title", "LOADING"))
	var total := _targets.size()
	if total == 0:
		# Nothing measurable to fetch: say so rather than animating a number.
		_bar.visible = false
		_indeterminate.visible = true
		_indeterminate.reduce_motion = _reduce_motion
		_indeterminate.set_running(true)
		_percent.text = ""
		_status.text = "PREPARING"
	else:
		_bar.visible = true
		_indeterminate.visible = false
		_bar.value = 0.0
		_percent.text = "0%"
		_status.text = "0 / %d" % total
		ResourceLoader.load_threaded_request(_targets[0])
	_robot.visible = _robot_atlas != null
	set_process(true)
	# An empty queue still has to leave the stage; give it one beat.
	if total == 0:
		call_deferred("_finish")


func exit() -> void:
	set_process(false)
	_indeterminate.set_running(false)


func _process(delta: float) -> void:
	if _robot_atlas != null and not _reduce_motion:
		_robot_time += delta
		var frame := int(_robot_time * ROBOT_FPS) % ROBOT_FRAMES
		_robot_atlas.region = Rect2(frame * ROBOT_CELL, 0.0, ROBOT_CELL, ROBOT_CELL)
	if _done or _index >= _targets.size():
		return
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(_targets[_index], progress)
	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			_index += 1
			_status.text = "%d / %d" % [_index, _targets.size()]
			if _index < _targets.size():
				ResourceLoader.load_threaded_request(_targets[_index])
			else:
				_finish()
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			var fraction := float(progress[0]) if progress.size() > 0 else 0.0
			var overall := (float(_index) + clampf(fraction, 0.0, 1.0)) / float(_targets.size())
			_bar.value = overall
			_percent.text = "%d%%" % roundi(overall * 100.0)
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			# A missing resource must be loud. Continuing keeps the game
			# bootable; the push_error is what the test suite sees.
			push_error("MenuLoading: could not load '%s'." % _targets[_index])
			_failed.append(_targets[_index])
			_index += 1
			_status.text = "%d / %d" % [_index, _targets.size()]
			if _index < _targets.size():
				ResourceLoader.load_threaded_request(_targets[_index])
			else:
				_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	set_process(false)
	_indeterminate.set_running(false)
	_bar.value = 1.0
	_percent.text = "100%"
	var scene_path := str(payload.get("scene", ""))
	if not scene_path.is_empty():
		if not _failed.is_empty():
			push_error("MenuLoading: %d resource(s) failed; see earlier errors." % _failed.size())
		call_deferred("_change_scene", scene_path)
		return
	# An empty `next` means "wherever the journey goes after the art is in",
	# which is FrontEnd's decision, not this stage's.
	var next := StringName(str(payload.get("next", "")))
	if next == &"" and is_instance_valid(front_end) and front_end.has_method("stage_after_loading"):
		next = front_end.stage_after_loading()
	if next == &"":
		next = &"DASHBOARD"
	completed.emit(next, {})


func _change_scene(scene_path: String) -> void:
	var scene := load(scene_path) as PackedScene
	if scene == null:
		push_error("MenuLoading: '%s' is not a PackedScene." % scene_path)
		return
	var error := get_tree().change_scene_to_packed(scene)
	if error != OK:
		push_error("MenuLoading: change_scene failed (%d)." % error)
