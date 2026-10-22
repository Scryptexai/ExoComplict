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
## Asset C as a real video, encoded from the same four frames by
## tools/art/build_ui_video.py. The sheet is the fallback, not the other way
## round: a device that cannot decode Theora still gets the walk cycle.
const ROBOT_VIDEO := "res://assets/ui/loading_robot.ogv"
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
var _robot_video: VideoStreamPlayer
var _robot_time := 0.0
var _indeterminate: MenuIndeterminateBar
var _reduce_motion := false
var _done := false
## QA only (`?qa_hold=1`): stop at 100 % instead of leaving the stage. A web
## build finishes this preload within one frame, so the screen cannot otherwise
## be photographed or reviewed at all -- and "it is always too fast to see" is
## not a reason to ship a screen nobody has looked at. Inert in the real flow:
## FrontEnd only sets it from the QA deep link, and nothing else reads it.
var _hold := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Deliberately *not* the cinematic's key art. Both stages used to open on
	# `loading_keyart.jpg` with a scrim, so for as long as the load took they
	# were the same picture -- the audit's "two stages look like one screen"
	# (docs/UX_AUDIT_2026-10-22.md 4). A load is a utility moment, not the
	# poster: this screen is a dark plate with the wordmark, the walk cycle and
	# a bar, and the opening's key art belongs to the opening alone. The
	# backdrop is a flat colour, so it is also up on the first frame instead of
	# waiting for a 40 KB JPEG to decode.
	var plate := ColorRect.new()
	plate.name = &"LoadingPlate"
	plate.color = AegisTokens.VOID
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	apply_safe_margins(margin)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_END
	physical_separation(column, 14)
	margin.add_child(column)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)

	# The mark comes first: a player who alt-tabs back mid-load should recognise
	# the product before reading the status line, the same way every other stage
	# opens on the wordmark.
	var mark := TextureRect.new()
	mark.name = &"Wordmark"
	mark.texture = try_texture("res://assets/ui/logo_wordmark.png")
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	physical_min_size(mark, 240.0, 60.0)
	column.add_child(mark)

	_title = make_label("LOADING", "display_l", AegisTokens.INK)
	column.add_child(_title)

	_status = make_label("", "label", AegisTokens.INK_2)
	column.add_child(_status)

	_robot = TextureRect.new()
	_robot.name = &"RobotSheet"
	_robot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_robot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_robot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	physical_min_size(_robot, 160.0, 160.0)
	_robot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sheet := try_texture(ROBOT_SHEET)
	if sheet != null:
		_robot_atlas = AtlasTexture.new()
		_robot_atlas.atlas = sheet
		_robot_atlas.region = Rect2(0.0, 0.0, ROBOT_CELL, ROBOT_CELL)
		_robot.texture = _robot_atlas
	column.add_child(_robot)

	_robot_video = VideoStreamPlayer.new()
	_robot_video.name = &"RobotVideo"
	_robot_video.stream = try_video(ROBOT_VIDEO)
	_robot_video.expand = true
	# `expand` stretches the frame to whatever rect the container gives the
	# player, and the column is 318 px wide: a square 512x512 loop came out
	# 318x160, i.e. twice as wide as tall, while the sprite-sheet fallback drew
	# the same robot at 160x160. Shrink-and-centre makes both paths agree.
	_robot_video.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_robot_video.loop = true
	_robot_video.autoplay = false
	_robot_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	physical_min_size(_robot_video, 160.0, 160.0)
	column.add_child(_robot_video)

	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.value = 0.0
	physical_min_size(_bar, 0.0, 8.0)
	column.add_child(_bar)

	_indeterminate = MenuIndeterminateBar.new()
	physical_min_size(_indeterminate, 0.0, 8.0)
	_indeterminate.visible = false
	column.add_child(_indeterminate)

	_percent = make_label("", "mono_m", AegisTokens.INFO)
	_connect_resized(_on_resized)
	relayout()
	column.add_child(_percent)


func enter(stage_payload: Dictionary) -> void:
	_reduce_motion = bool(AegisPreferences.read().get("reduce_motion", false))
	_targets = []
	for path in stage_payload.get("targets", []):
		_targets.append(str(path))
	_index = 0
	_failed = []
	_done = false
	_hold = bool(stage_payload.get("hold", false))
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
	_use_video_robot(_robot_video.stream != null and not _reduce_motion)
	set_process(true)
	# An empty queue still has to leave the stage; give it one beat.
	if total == 0:
		call_deferred("_finish")


func exit() -> void:
	set_process(false)
	_indeterminate.set_running(false)
	if is_instance_valid(_robot_video) and _robot_video.is_playing():
		_robot_video.stop()


## The video and the sprite sheet are one animation in two containers, so only
## one of them is ever on screen. `reduce_motion` holds the first frame of
## whichever is in use, which for the video means not starting it at all.
func _use_video_robot(use_video: bool) -> void:
	_robot_video.visible = use_video
	_robot.visible = not use_video and _robot_atlas != null
	if use_video:
		# No length in the log line: `stream_length` reads 0.00 until the
		# decoder opens, and the number belongs to the test that waits for it.
		print("MenuLoading: playing the encoded walk cycle")
		_robot_video.play()
	else:
		_robot_video.stop()
		_robot_video.stream_position = 0.0


func _process(delta: float) -> void:
	if _robot.visible and _robot_atlas != null and not _reduce_motion:
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
	_status.text = "READY"
	if _hold:
		return
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


func _on_resized() -> void:
	relayout()
