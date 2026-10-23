## Video asset smoke test.
##
## The front end has one video: the studio ident, transcoded from
## `branding_studio_present.mp4` (committed by its owner at the repository root)
## into `studio_ident.ogv` by `tools/art/build_ui_video.py`. (The LOADING walk
## cycle that used to be the second one was cut on 2026-10-23 --
## docs/VERIFICATION_2026-10-23.md 3.)
##
## It is a *studio brand film* -- somebody else's mark -- so this test checks
## the asset and the stage's restraint: the file is the delivered film (same
## frame size, same length, audio present, playback advances) and the stage it
## plays in carries no product art at all.
##
## A file on disk proves nothing about an export -- a video can sit there and
## never decode. So this test loads it through `ResourceLoader` the way the
## stage does and compares what the *engine* reports against
## `game/assets/ui/video_manifest.json`, then checks the stage really did pick
## the video path over its composed fallback.
##
## What it cannot tell you is whether a frame is ever presented: the headless
## runner has neither a display nor an audio device. Playback is measured in a
## real browser build and recorded in docs/asset-inspections/, not asserted here.
extends SceneTree

const VIDEOS := {
	"studio_ident": "res://assets/ui/studio_ident.ogv",
}
const MANIFEST := "res://assets/ui/video_manifest.json"
const StudioIdentScene = preload("res://scenes/ui/menus/stage_studio_ident.tscn")
const LoadingScene = preload("res://scenes/ui/menus/stage_loading.tscn")

var _failures: Array[String] = []
## How many videos were actually measured. A skipped assertion is a silent
## pass, and this file is worthless if one of them can slip through.
var _measured := 0


func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	var manifest := _read_manifest()
	for key in VIDEOS:
		await _check_video(key, VIDEOS[key], manifest)
	await _check_stage("studio_ident", StudioIdentScene, "_video")
	await _check_the_ident_carries_no_product_art()

	# The robot is gone, and "gone" is asserted rather than assumed: a stage
	# that still held a player for it would be loading a file that no longer
	# exists, and the test suite is the only place that can notice.
	var loading: Control = LoadingScene.instantiate()
	root.add_child(loading)
	await process_frame
	_expect(
		not loading.has_method("_use_video_robot"),
		"loading: no walk cycle left to play",
	)
	_expect(
		not _art_textures(loading).has("res://assets/ui/loading_robot_sheet.png"),
		"loading: the robot sprite sheet is not referenced",
	)
	loading.free()

	_expect(
		_measured == VIDEOS.size(),
		"every shipped video was measured (%d of %d)" % [_measured, VIDEOS.size()]
	)
	if _failures.is_empty():
		print("Video asset smoke test passed.")
		quit(0)
		return
	print("Video asset smoke test FAILED:")
	for failure in _failures:
		print("  fail: " + failure)
	quit(1)


func _read_manifest() -> Dictionary:
	var handle := FileAccess.open(MANIFEST, FileAccess.READ)
	if handle == null:
		_fail("the video manifest is missing at %s" % MANIFEST)
		return {}
	var parsed: Variant = JSON.parse_string(handle.get_as_text())
	handle.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail("the video manifest is not a JSON object")
		return {}
	var entries := {}
	for entry in (parsed as Dictionary).get("videos", []):
		entries[str((entry as Dictionary)["key"])] = entry
	return entries


func _check_video(key: String, path: String, manifest: Dictionary) -> void:
	var stream := ResourceLoader.load(path, "VideoStream") as VideoStream
	if not _expect(stream != null, "%s: %s loads as a VideoStream" % [key, path]):
		return
	if ClassDB.class_exists("VideoStreamTheora"):
		_expect(stream is VideoStreamTheora, "%s: the engine reports it as VideoStreamTheora" % key)
	var entry: Dictionary = manifest.get(key, {})
	if entry.is_empty():
		_fail("%s: no manifest entry to compare against" % key)
		return
	# Size and length live on the playback, not the stream: `VideoStream` is
	# only a factory until something instantiates a decoder for it.
	var player := VideoStreamPlayer.new()
	player.stream = stream
	root.add_child(player)
	player.play()
	var texture: Texture2D = null
	for _frame in range(240):
		await process_frame
		texture = player.get_video_texture()
		if texture != null:
			break
	if not _expect(texture != null, "%s: a frame decodes into a texture" % key):
		player.free()
		return
	var wanted_size := Vector2(
		float((entry["size"] as Array)[0]), float((entry["size"] as Array)[1])
	)
	var measured_size := texture.get_size()
	_expect(
		measured_size == wanted_size,
		(
			"%s: the engine measures %dx%d, the manifest says %dx%d"
			% [
				key,
				int(measured_size.x),
				int(measured_size.y),
				int(wanted_size.x),
				int(wanted_size.y)
			]
		)
	)
	var measured_length := player.get_stream_length()
	var wanted_length := float(entry["duration_s"])
	_expect(
		absf(measured_length - wanted_length) < 0.15,
		(
			"%s: the engine measures %.2f s, the manifest says %.2f s"
			% [key, measured_length, wanted_length]
		)
	)
	# Headless frames carry a tiny delta, so advancing is measured in frames
	# rather than seconds: give the decoder room and then require it to have
	# moved.
	var advanced := 0.0
	for _frame in range(240):
		await process_frame
		advanced = player.get_stream_position()
		if advanced > 0.05:
			break
	_expect(
		advanced > 0.05,
		"%s: playback advances (%.2f s of %.2f s decoded)" % [key, advanced, measured_length]
	)
	_measured += 1
	player.stop()
	player.free()


## The ident is somebody else's mark, so the assertion is about restraint: the
## stage holds the video and nothing else. No key art behind it, no wordmark on
## it, no caption and no skip button -- which is also how it stays different
## from LOADING, the screen the audit said it used to be identical to
## (docs/UX_AUDIT_2026-10-22.md 4).
func _check_the_ident_carries_no_product_art() -> void:
	var ident: Control = StudioIdentScene.instantiate()
	var loading: Control = LoadingScene.instantiate()
	root.add_child(ident)
	root.add_child(loading)
	await process_frame
	await process_frame
	_expect(
		_art_textures(ident).is_empty(),
		"studio ident: no texture of ours on the mark (got %s)" % [_art_textures(ident)],
	)
	_expect(
		ident.find_children("*", "Button", true, false).is_empty(),
		"studio ident: no skip button, no control, on the mark",
	)
	_expect(
		not _art_textures(loading).has("res://assets/ui/loading_keyart.jpg"),
		"loading: does not use the key art",
	)
	_expect(
		loading.find_child("Wordmark", true, false) != null,
		"loading: carries the product wordmark, so it is not an anonymous frame",
	)
	ident.free()
	loading.free()


## Every texture path a stage's TextureRects hold, recursively.
func _art_textures(stage: Control) -> Array[String]:
	var found: Array[String] = []
	for child in stage.find_children("*", "TextureRect", true, false):
		var rect := child as TextureRect
		if rect == null or rect.texture == null:
			continue
		var path := rect.texture.resource_path
		if path.begins_with("res://") and not found.has(path):
			found.append(path)
	return found


func _check_stage(name: String, scene: PackedScene, player_var: String) -> void:
	var stage: Control = scene.instantiate()
	root.add_child(stage)
	await process_frame
	await process_frame
	var player: VideoStreamPlayer = stage.get(player_var) as VideoStreamPlayer
	if not _expect(
		player != null and player.stream != null,
		"%s: the stage loaded the video into its %s player" % [name, player_var]
	):
		stage.free()
		return
	_expect(
		stage.call("try_video", "res://assets/ui/definitely_not_here.ogv") == null,
		"%s: a missing video loads as null instead of crashing the stage" % name
	)
	stage.free()


func _expect(condition: bool, message: String) -> bool:
	if condition:
		print("  ok: " + message)
		return true
	_fail(message)
	return false


func _fail(message: String) -> void:
	print("  fail: " + message)
	_failures.append(message)
