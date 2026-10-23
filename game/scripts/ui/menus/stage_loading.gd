## LOADING and PRELOAD: one implementation, two stages.
##
## A loading screen is a utility moment: the wordmark, what is happening, and a
## bar that reports the engine's own count. It carried a walking robot until
## 2026-10-23; the robot was cut because it competed with the product mark for
## the only focal point a load screen has, and because it said nothing about
## the game (docs/VERIFICATION_2026-10-23.md 3). What is left is the hierarchy
## the screen actually needs, at the size a load screen is read from.
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

var _targets: Array[String] = []
var _index := 0
var _failed: Array[String] = []
var _title: Label
var _bar: ProgressBar
var _percent: Label
var _status: Label
var _mark: TextureRect
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
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	physical_separation(column, 20)
	margin.add_child(column)

	# Two spacers rather than one: the whole block -- wordmark, title and bar --
	# sits in the optical centre instead of being pushed into the bottom
	# third. With a single spacer the bar and the percentage ended up on the very
	# bottom edge, where the web shell draws its own control bar on top of them.
	var top_spacer := Control.new()
	top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(top_spacer)

	# The mark comes first: a player who alt-tabs back mid-load should recognise
	# the product before reading the status line, the same way every other stage
	# opens on the wordmark.
	_mark = TextureRect.new()
	_mark.name = &"Wordmark"
	_mark.texture = try_texture("res://assets/ui/logo_wordmark.png")
	_mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Portrait phone 390 px wide / desktop: see StageBoot for the reason the
	# mark has two authored sizes rather than one large one.
	_size_both(_mark, Vector2(300.0, 75.0), Vector2(440.0, 110.0))
	column.add_child(_mark)

	# Title and percentage on one row. The percentage used to be the last thing
	# in the column, directly under the bar, which put it below the safe margin
	# and behind the web shell's own control bar -- a readout nobody could see.
	var headline := HBoxContainer.new()
	physical_separation(headline, 16)
	column.add_child(headline)
	_title = make_label("LOADING", "display_l", AegisTokens.INK)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	headline.add_child(_title)
	_percent = make_label("", "mono_l", AegisTokens.INFO)
	_percent.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	headline.add_child(_percent)

	_status = make_label("", "label", AegisTokens.INK_2)
	column.add_child(_status)

	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.value = 0.0
	physical_min_size(_bar, 0.0, 12.0)
	column.add_child(_bar)

	_indeterminate = MenuIndeterminateBar.new()
	physical_min_size(_indeterminate, 0.0, 12.0)
	_indeterminate.visible = false
	column.add_child(_indeterminate)

	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(bottom_spacer)

	_connect_resized(_on_resized)
	relayout()


func enter(stage_payload: Dictionary) -> void:
	_reduce_motion = bool(AegisPreferences.read().get("reduce_motion", false))
	_targets = []
	for path in stage_payload.get("targets", []):
		_targets.append(str(path))
	_index = 0
	_failed = []
	_done = false
	_hold = bool(stage_payload.get("hold", false))
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
	set_process(true)
	# An empty queue still has to leave the stage; give it one beat.
	if total == 0:
		call_deferred("_finish")


func exit() -> void:
	set_process(false)
	_indeterminate.set_running(false)


func _process(_delta: float) -> void:
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
	_orient_nodes([_mark])
