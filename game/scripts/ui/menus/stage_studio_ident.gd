## The studio's ident: the first thing this application does.
##
## `branding_studio_present.mp4` is committed at the repository root by its
## owner, and it is a *studio brand film* -- the beat a Garena or Moonton title
## opens on, before the game's own logo. It is somebody else's mark, so the
## rules in this file are about not getting in its way:
##
##   * it runs first, before BOOT, on every launch. A company ident is a launch
##     beat: not a reward, not a menu item, and not something a player replays
##     from a dashboard row;
##   * it is the only thing on the screen. No product wordmark, no caption, no
##     key art behind it, no scrim, no progress bar and no SKIP button. An ident
##     with this game's UI drawn over it is no longer the studio's ident;
##   * it is fitted, never covered: contained and centred, so the square frame
##     is whole on any screen, and never stretched to fill one;
##   * nothing of ours is substituted for it. If the file is missing, or the
##     device cannot decode Theora, the stage moves on and says so in the log.
##     It does not play a sequence of ours in the mark's place -- a stand-in is
##     still not the mark, and dressing our own key art up as the opening was
##     the mistake this stage replaces.
##
## Dismissal draws nothing. The film ends by itself; any input ends it early,
## which is what the player would expect a splash to do, and a tap is not
## chrome the way a button would be.
extends MenuStage

## The encoded ident, 768x768 @ 24 fps: the delivered file, transcoded to a
## container Godot decodes (`tools/art/build_ui_video.py`), never re-edited,
## re-cropped, re-timed or re-scored here.
const STUDIO_IDENT_VIDEO := "res://assets/ui/studio_ident.ogv"

## Assumed until the decoder reports the real frame size. The shipped ident is
## square; the layout is *contain*, so a wrong guess only moves the frame for
## one update instead of cropping it.
const DEFAULT_FRAME_SIZE := Vector2(768.0, 768.0)

## A started-but-frozen decoder is given this long before the stage moves on, so
## a device without Theora support is never stranded on a black screen.
const STALL_SECONDS := 3.0
## Ceiling on the whole beat. The delivered film is 10.14 s; this only has to
## be longer than any real ident and shorter than a player's patience.
const MAX_SECONDS := 30.0

var _video: VideoStreamPlayer
var _elapsed := 0.0
var _stall := 0.0
var _last_position := 0.0
## True once a frame has been decoded, i.e. the rect has stopped guessing.
var _sized := false
var _reported := false
var _finished := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# The stage is black, not transparent. There is no key art behind the ident
	# and nothing should show through from whatever was on screen before it.
	var floor_fill := ColorRect.new()
	floor_fill.color = AegisTokens.VOID
	floor_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	floor_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(floor_fill)

	_video = VideoStreamPlayer.new()
	_video.name = &"StudioIdent"
	_video.stream = try_video(STUDIO_IDENT_VIDEO)
	# `expand` stretches the frame to the control's rect, so the rect has to
	# keep the film's own aspect: on a 390x844 screen a full-rect player would
	# smear the mark down the whole display. `_layout_video` fits the frame
	# inside the stage and centres it; the parent clips, which only matters if a
	# future ident is wider than the screen.
	_video.expand = true
	_video.loop = false
	_video.autoplay = false
	_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_video.finished.connect(_on_video_finished)
	add_child(_video)
	_connect_resized(_on_resized)


func enter(_stage_payload: Dictionary) -> void:
	_elapsed = 0.0
	_stall = 0.0
	_last_position = 0.0
	_sized = false
	_reported = false
	_finished = false
	_layout_video()
	# Two reasons the ident does not play, both logged rather than papered over:
	# the asset is missing, or the player asked for less motion. Neither is a
	# reason to put something else on the screen.
	if _video.stream == null:
		push_warning("MenuStudioIdent: %s is missing; the ident is not shown." % STUDIO_IDENT_VIDEO)
		_finish.call_deferred()
		return
	if bool(AegisPreferences.read().get("reduce_motion", false)):
		print("MenuStudioIdent: reduce_motion is set; the ident is not played.")
		_finish.call_deferred()
		return
	_video.play()
	set_process(true)
	print("MenuStudioIdent: playing %s" % STUDIO_IDENT_VIDEO)


func exit() -> void:
	set_process(false)
	if is_instance_valid(_video) and _video.is_playing():
		_video.stop()


func _process(delta: float) -> void:
	if _finished:
		return
	_elapsed += delta
	if not _sized:
		_sized = _layout_video()
	# A decoder that opened the file and then stopped moving is the one failure
	# mode a file check cannot see. It gets three seconds, then the stage moves
	# on: the ident is not worth trapping a player on a black screen for.
	var position_now := _video.stream_position
	if position_now > _last_position + 0.001:
		_last_position = position_now
		_stall = 0.0
	else:
		_stall += delta
		if _stall >= STALL_SECONDS:
			push_warning(
				"MenuStudioIdent: the ident stalled at %.2f s; moving on." % _last_position
			)
			_finish()
			return
	if _elapsed >= MAX_SECONDS:
		push_warning("MenuStudioIdent: the ident ran past %.0f s; moving on." % MAX_SECONDS)
		_finish()
		return
	if not _reported and position_now >= 2.0:
		# Once, two seconds in: QA answers "did the film actually decode" from
		# the log rather than from a still, which is what the frames are for.
		_reported = true
		print(
			(
				"MenuStudioIdent: stream at %.2f s of %.2f s"
				% [position_now, _video.get_stream_length()]
			)
		)


## Any input dismisses the ident. A splash you cannot get out of is a wall.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		accept_event()
		_finish()
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		accept_event()
		_finish()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed:
		get_viewport().set_input_as_handled()
		_finish()


## Fit the ident inside the stage, centred, keeping its own aspect.
##
## `VideoStream` carries no size -- `has_method("get_size")` is false on
## `VideoStreamTheora` -- so the frame size only becomes knowable from the
## decoded texture. The layout starts from the authored 768x768 and is refined
## on the first decoded frame; the returned value says whether it has been.
func _layout_video() -> bool:
	if _video.stream == null or size.x <= 0.0 or size.y <= 0.0:
		return false
	var natural := DEFAULT_FRAME_SIZE
	var texture := _video.get_video_texture()
	if texture != null:
		var decoded := texture.get_size()
		if decoded.x > 0.0 and decoded.y > 0.0:
			natural = decoded
	var fit := minf(size.x / natural.x, size.y / natural.y)
	var wanted := natural * fit
	_video.size = wanted
	_video.position = (size - wanted) * 0.5
	return texture != null


func _on_resized() -> void:
	_layout_video()


func _on_video_finished() -> void:
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	set_process(false)
	if is_instance_valid(_video) and _video.is_playing():
		_video.stop()
	completed.emit(&"BOOT", {})
