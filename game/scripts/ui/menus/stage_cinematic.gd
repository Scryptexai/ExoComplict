## The opening.
##
## This is the studio ident the project ships: `branding_studio_present.mp4`
## (the file committed at the repository root) transcoded to
## `res://assets/ui/cinematic_opening.ogv` by `tools/art/build_ui_video.py`.
## It is a 768x768 square on a black field, and it is played *as authored*:
## contained, centred, never stretched and never cropped, because the mark has
## margins that a "cover" fit cuts off. The stage goes black behind it so the
## square does not sit on a rectangle of key art.
##
## Nothing is drawn over the ident. No captions, no wordmark, no progress bar:
## a company ident with the product's marketing copy on top of it is not a
## ident. The one control is SKIP, in the bottom corner, from the first frame.
##
## When the video is absent -- or a device cannot decode Theora -- the stage
## falls back to the beat it always had: a slow push-in on `loading_keyart.jpg`
## under four captions, which *is* the product's premise (an arena, waves of
## hostiles, Battle Points that unlock weapons) and stays UI text rather than
## baked pixels so it can be localised (docs/ART_DIRECTION.md §2).
extends MenuStage

## Seconds each caption is held, fade in/out included.
const BEAT_SECONDS := 2.4
const FADE_SECONDS := 0.55
const PUSH_SECONDS := 9.6
const PUSH_SCALE := 1.14

## The encoded ident, 768x768 @ 24 fps. Absent -> the composed fallback runs.
const OPENING_VIDEO := "res://assets/ui/cinematic_opening.ogv"
## How long a started-but-frozen video is given before the composed opening
## takes over, so a device that cannot decode Theora is never stranded.
const STALL_SECONDS := 2.5

## Assumed until the decoder reports the real frame size. The shipped ident is
## square; the layout is *contain*, so a wrong guess only moves the frame for
## one update instead of cropping it.
const DEFAULT_FRAME_SIZE := Vector2(768.0, 768.0)

## Three of the four caption beats. The missing one is the theatre line, and it
## is built at runtime (see `_beat_caption`) because the theatre's name is the
## world definition's, not a literal kept here as well.
const CAPTIONS := [
	"AEGIS TRAINING FACILITY",
	"HOSTILE WAVES INBOUND",
	"SURVIVE · EARN BATTLE POINTS · UNLOCK",
]

## The sector the opening drops into. There is no sector data model, so this
## half of the theatre line stays a literal; the theatre's name does not.
const CAPTION_SECTOR := "SECTOR 01"

var _video: VideoStreamPlayer
var _plate: TextureRect
## Scrim over the composed fallback only; the ident is shown undimmed.
var _scrim: ColorRect
var _caption: Label
var _mark: TextureRect
var _skip: AegisButton
var _position: ProgressBar
var _elapsed := 0.0
var _total := 0.0
## Watchdog for a video that loads but never advances. Without it a device
## that cannot decode Theora would sit on the opening forever with no way out
## but a cold restart.
var _stall := 0.0
var _last_position := 0.0
var _reported := false
var _video_sized := false
var _beat := -1
var _reduce_motion := false
var _finished := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	# The stage's own floor. With the key art hidden (the ident path) the
	# letterbox bars have to be the colour a cinema is, not whatever the
	# previous stage left behind.
	var floor_fill := ColorRect.new()
	floor_fill.color = AegisTokens.VOID
	floor_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	floor_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(floor_fill)

	var viewport := Control.new()
	viewport.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewport.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Clip the push-in so the plate never spills past the frame edge.
	viewport.clip_contents = true
	add_child(viewport)

	# The key art is the poster frame: it sits behind the video, so a device
	# that cannot decode Theora shows the composed opening instead of a hole.
	_plate = make_backdrop("res://assets/ui/loading_keyart.jpg")
	_plate.pivot_offset = Vector2(960.0, 540.0)
	# Hidden until `enter()` picks the composed path. Starting hidden makes the
	# ident the default the stage is *built* on rather than a state it has to
	# reach: a frame drawn between construction and entry shows the film's
	# letterbox, never the key art.
	_plate.visible = false
	viewport.add_child(_plate)

	_video = VideoStreamPlayer.new()
	_video.name = &"OpeningVideo"
	_video.stream = try_video(OPENING_VIDEO)
	# `expand` stretches the frame to the control's rect, so the rect has to
	# keep the video's own aspect: on a 390x844 screen a full-rect player would
	# stretch the ident into a vertical smear. `_layout_video` fits the frame
	# inside the stage and centres it; the parent clips, which only matters if
	# a future film is wider than the screen.
	_video.expand = true
	_video.loop = false
	_video.autoplay = false
	_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_video.finished.connect(_on_video_finished)
	viewport.add_child(_video)

	_scrim = ColorRect.new()
	_scrim.color = Color(AegisTokens.VOID, 0.42)
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrim.visible = false
	add_child(_scrim)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	apply_safe_margins(margin)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_END
	physical_separation(column, 20)
	margin.add_child(column)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)

	_mark = TextureRect.new()
	_mark.name = &"Wordmark"
	_mark.texture = try_texture("res://assets/ui/logo_wordmark.png")
	_mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_size_both(_mark, Vector2(300.0, 75.0), Vector2(520.0, 130.0))
	_mark.modulate.a = 0.0
	column.add_child(_mark)

	_caption = make_label("", "heading", AegisTokens.INK)
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.modulate.a = 0.0
	column.add_child(_caption)

	_position = ProgressBar.new()
	_position.show_percentage = false
	_position.min_value = 0.0
	_position.max_value = 1.0
	_position.value = 0.0
	physical_min_size(_position, 0.0, 6.0)
	column.add_child(_position)

	_skip = make_button("SKIP", "ghost", "Skip the opening cinematic")
	physical_min_size(_skip, 180.0, 64.0)
	_skip.pressed.connect(_on_skip_pressed)
	_connect_resized(_on_resized)
	relayout()
	column.add_child(_skip)


func enter(_stage_payload: Dictionary) -> void:
	_reduce_motion = bool(AegisPreferences.read().get("reduce_motion", false))
	_elapsed = 0.0
	_total = _captions_count() * BEAT_SECONDS
	_beat = -1
	_finished = false
	_position.value = 0.0
	_caption.modulate.a = 0.0
	_mark.modulate.a = 0.0
	_plate.scale = Vector2.ONE
	_stall = 0.0
	_last_position = 0.0
	_reported = false
	_video_sized = false
	# The length is *not* known yet: `stream_length` reads 0.00 until the
	# decoder has opened the file, and taking it here made the progress bar
	# saturate and the intro finish on its first frame (measured in a real
	# browser build). Start from the authored length and adopt the measured one
	# as soon as the decoder reports it.
	_video.visible = _video.stream != null and not _reduce_motion
	# The product overlay belongs to the composed fallback. Over the ident it
	# would be a caption and a wordmark laid on somebody else's brand film.
	_show_ident_overlay(not _video.visible)
	_layout_video()
	if _video.visible:
		_video.play()
		print("MenuCinematic: playing the encoded opening")
	else:
		_video.stop()
		_video.stream_position = 0.0
		print("MenuCinematic: playing the composed opening (%.2f s)" % _total)
		_advance_beat()
	set_process(true)


func exit() -> void:
	set_process(false)
	if is_instance_valid(_plate):
		_plate.scale = Vector2.ONE
	if is_instance_valid(_video) and _video.is_playing():
		_video.stop()


## Two openings, two overlays. `ident: true` hides the key-art plate, the scrim,
## the captions, the wordmark and the progress sliver, leaving the letterboxed
## video on a black stage and the one control that can be pressed. The fallback
## is the reverse, and is what every earlier frame of this stage looked like.
func _show_ident_overlay(ident: bool) -> void:
	_plate.visible = not ident
	_scrim.visible = not ident
	_caption.visible = not ident
	_mark.visible = not ident
	_position.visible = not ident
	_caption.modulate.a = 0.0
	_mark.modulate.a = 0.0


func _process(delta: float) -> void:
	if _finished:
		return
	if _video.visible:
		if _watch_video(delta):
			return
		var measured := _video.get_stream_length()
		if measured > 0.1:
			_total = measured
		if not _video_sized:
			_video_sized = _layout_video()
	# The state of the two overlays, once, at 2 s: a still of this stage that
	# disagrees with these booleans is a drawing bug and not a decision one.
	if not _reported and _elapsed >= 2.0:
		print(
			(
				"MenuCinematic: overlay video=%s plate=%s scrim=%s caption=%s"
				% [_video.visible, _plate.visible, _scrim.visible, _caption.visible]
			)
		)
	if _video.visible and not _reported and _elapsed >= 2.0:
		# One line, once: which path this device is on is exactly the question
		# a QA run has to be able to answer from the log alone.
		_reported = true
		print("MenuCinematic: stream at %.2f s of %.2f s" % [_elapsed, _total])
	_elapsed = _video.stream_position if _video.visible else _elapsed + delta
	_position.value = clampf(_elapsed / maxf(_total, 0.001), 0.0, 1.0)
	# The push-in belongs to the composed opening. It is skipped while the video
	# covers the plate, which also means any motion measured during playback
	# comes from the video and nothing else.
	if not _video.visible and not _reduce_motion:
		var phase := clampf(_elapsed / PUSH_SECONDS, 0.0, 1.0)
		var eased: float = 1.0 - pow(1.0 - phase, 3.0)
		_plate.scale = Vector2.ONE * lerpf(1.0, PUSH_SCALE, eased)
		_plate.pivot_offset = _plate.size * 0.5
	var beat := int(_elapsed / BEAT_SECONDS)
	if _video.visible:
		beat = _beats_are_over()
	if beat != _beat and beat < _captions_count():
		_beat = beat
		_advance_beat()
	if _elapsed >= _total:
		_finish()


func _advance_beat() -> void:
	if _beat < 0 or _beat >= _captions_count():
		return
	_caption.text = _beat_caption(_beat)
	# The wordmark only lands with the last caption, so the title is revealed
	# by the intro rather than competing with it for the first eight seconds.
	if _beat == _captions_count() - 1:
		_fade(_mark, 1.0)
	if _reduce_motion:
		_caption.modulate.a = 1.0
		return
	_caption.modulate.a = 0.0
	_fade(_caption, 1.0)


func _fade(target: CanvasItem, to_alpha: float) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "modulate:a", to_alpha, FADE_SECONDS)


## True when the video stalled and the composed opening took over, in which
## case this frame is already spent and `_process` should stop.
func _watch_video(delta: float) -> bool:
	if not _video.is_playing():
		return false
	if _video.stream_position > _last_position + 0.001:
		_last_position = _video.stream_position
		_stall = 0.0
		return false
	_stall += delta
	if _stall < STALL_SECONDS:
		return false
	push_warning(
		"MenuCinematic: the opening video stalled at %.2f s; falling back." % _last_position
	)
	_fallback_to_composed()
	return true


## Hand the rest of the intro to the composed path from wherever the video got
## to, so the captions keep their place instead of restarting the opening.
func _fallback_to_composed() -> void:
	_video.visible = false
	_video.stop()
	# Bring the overlay back with it. Without this the stage would keep the
	# ident's black set and run the composed opening on it -- captions over
	# nothing, which is the one thing the fallback exists to avoid.
	_show_ident_overlay(false)
	_total = _captions_count() * BEAT_SECONDS
	_elapsed = _last_position
	_stall = 0.0


## Fit the video inside the stage, centred, keeping its aspect.
##
## This used to *cover*, which was right for the 16:9 push-in it was written
## for and wrong for the square ident that replaced it: covering a 768x768
## frame with a 1280x720 window scales it to 1280 wide and crops the top and
## bottom off the mark. Contained, the ident letters onto the stage's black and
## is seen whole -- the frame is 720 px tall on a 720 px canvas, which is the
## largest it can be without cutting the art.
##
## True once the real frame size is known and the rect can stop moving.
##
## `VideoStream` carries no size -- `stream.get_size()` does not exist in this
## build (`has_method("get_size")` is false on VideoStreamTheora), so the first
## draft of this function threw on every call and left the player at the full
## stage rect: exactly the vertical smear it was written to prevent. The frame
## size only becomes knowable from the decoded texture, so the layout starts
## from the authored 16:9 and is refined on the first decoded frame.
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


## A beat index that is already past the last caption: while the ident plays,
## `_process` must not walk the caption timeline behind a hidden label.
static func _beats_are_over() -> int:
	return 1 << 20


func _on_skip_pressed() -> void:
	_finish()


func _on_video_finished() -> void:
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	set_process(false)
	completed.emit(&"CHAPTER", {})


func _on_resized() -> void:
	relayout()
	_orient_nodes([_mark])
	_layout_video()


## Four beats: the facility line, then the theatre, then the two closing lines.
static func _captions_count() -> int:
	return CAPTIONS.size() + 1


## The theatre line is built from `WorldDefinition` rather than typed out, so
## the opening cannot name one world while the WORLD card and the dashboard
## name another. If the definition is ever missing the id is spelled out
## instead -- never a remembered copy of the name.
static func _beat_caption(beat: int) -> String:
	if beat <= 0:
		return CAPTIONS[0]
	if beat == 1:
		var world := WorldDefinition.load_definition(WorldDefinition.DEFAULT_WORLD_ID)
		var theatre := (
			String(WorldDefinition.DEFAULT_WORLD_ID).replace("_", " ").to_upper()
			if world == null
			else world.display_name.to_upper()
		)
		return "%s — %s" % [theatre, CAPTION_SECTOR]
	if beat - 1 < CAPTIONS.size():
		return CAPTIONS[beat - 1]
	return ""
