## The opening cinematic, built in-engine.
##
## Asset F asked for a video and no video exists: `ffmpeg`/`ffprobe` are not
## installed and the Debian mirrors are unreachable, so there is no encoder in
## this environment. Rather than ship a fake progress bar in front of a still
## image and call it a cinematic, the intro is composed from the key art the
## pipeline did produce -- a slow push-in on `loading_keyart.jpg` under four
## captions -- and it is skippable from the first frame.
##
## The captions state the premise the game actually implements (an arena, waves
## of hostiles, Battle Points that unlock weapons). They invent no characters,
## no faction history and no plot: GAME_CONCEPT.md is explicit that this game is
## not story-driven, so a lore-dump intro would be a lie about the product.
extends MenuStage

## Seconds each caption is held, fade in/out included.
const BEAT_SECONDS := 2.4
const FADE_SECONDS := 0.55
const PUSH_SECONDS := 9.6
const PUSH_SCALE := 1.14

const CAPTIONS := [
	"AEGIS TRAINING FACILITY",
	"NEON FRONTIER — SECTOR 01",
	"HOSTILE WAVES INBOUND",
	"SURVIVE · EARN BATTLE POINTS · UNLOCK",
]

var _plate: TextureRect
var _caption: Label
var _mark: TextureRect
var _skip: AegisButton
var _position: ProgressBar
var _elapsed := 0.0
var _total := 0.0
var _beat := -1
var _reduce_motion := false
var _finished := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	var viewport := Control.new()
	viewport.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewport.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Clip the push-in so the plate never spills past the frame edge.
	viewport.clip_contents = true
	add_child(viewport)

	_plate = make_backdrop("res://assets/ui/loading_keyart.jpg")
	_plate.pivot_offset = Vector2(960.0, 540.0)
	viewport.add_child(_plate)

	var scrim := ColorRect.new()
	scrim.color = Color(AegisTokens.VOID, 0.66)
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
	column.add_theme_constant_override("separation", 20)
	margin.add_child(column)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)

	_mark = TextureRect.new()
	_mark.texture = try_texture("res://assets/ui/logo_wordmark.png")
	_mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_mark.custom_minimum_size = Vector2(300.0, 75.0)
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
	_position.custom_minimum_size = Vector2(0.0, 4.0)
	column.add_child(_position)

	_skip = make_button("SKIP", "ghost", "Skip the opening cinematic")
	_skip.custom_minimum_size = Vector2(160.0, 56.0)
	_skip.pressed.connect(_on_skip_pressed)
	column.add_child(_skip)


func enter(_stage_payload: Dictionary) -> void:
	_reduce_motion = bool(AegisPreferences.read().get("reduce_motion", false))
	_elapsed = 0.0
	_total = CAPTIONS.size() * BEAT_SECONDS
	_beat = -1
	_finished = false
	_position.value = 0.0
	_caption.modulate.a = 0.0
	_mark.modulate.a = 0.0
	_plate.scale = Vector2.ONE
	_advance_beat()
	set_process(true)


func exit() -> void:
	set_process(false)
	if is_instance_valid(_plate):
		_plate.scale = Vector2.ONE


func _process(delta: float) -> void:
	if _finished:
		return
	_elapsed += delta
	_position.value = clampf(_elapsed / maxf(_total, 0.001), 0.0, 1.0)
	if not _reduce_motion:
		var phase := clampf(_elapsed / PUSH_SECONDS, 0.0, 1.0)
		var eased: float = 1.0 - pow(1.0 - phase, 3.0)
		_plate.scale = Vector2.ONE * lerpf(1.0, PUSH_SCALE, eased)
		_plate.pivot_offset = _plate.size * 0.5
	var beat := int(_elapsed / BEAT_SECONDS)
	if beat != _beat and beat < CAPTIONS.size():
		_beat = beat
		_advance_beat()
	if _elapsed >= _total:
		_finish()


func _advance_beat() -> void:
	if _beat < 0 or _beat >= CAPTIONS.size():
		return
	_caption.text = CAPTIONS[_beat]
	# The wordmark only lands with the last caption, so the title is revealed
	# by the intro rather than competing with it for the first eight seconds.
	if _beat == CAPTIONS.size() - 1:
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


func _on_skip_pressed() -> void:
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	set_process(false)
	completed.emit(&"CHAPTER", {})


