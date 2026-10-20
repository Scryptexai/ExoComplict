## Base class for one screen of the front-end journey.
##
## The journey is BOOT -> LOADING -> CINEMATIC -> CHAPTER -> DASHBOARD -> HERO
## -> WEAPON -> WORLD -> PRELOAD -> gameplay. A stage owns its own layout and
## its own input, and knows nothing about the others: it finishes by emitting
## `completed` with the name of the stage it wants next, and `FrontEnd` decides
## whether that request is legal. Keeping the decision in one place is what
## stops a stage from being reachable out of order (a dashboard that appears
## before the profile is read, a preload that runs before a world is chosen).
class_name MenuStage
extends Control

## `next_stage` is a StringName key into FrontEnd.STAGE_SCENES. `payload` is
## handed to the next stage's `enter()` untouched.
signal completed(next_stage: StringName, payload: Dictionary)

## Set by FrontEnd when the stage is instantiated, before `enter()` runs.
## Typed as Node rather than FrontEnd because the two cannot preload each other;
## `progression_service()` is the typed way back to the profile.
var front_end: Node = null
## Whatever the previous stage passed along. Empty on the first stage.
var payload: Dictionary = {}
## Full-rect safe-area container every screen lays out in, created by
## `make_margin()`. Stored so `enter()` can re-apply the margins on a resize or
## a rotation without searching the tree for it.
var _margin: MarginContainer = null


## Called every time the stage becomes visible, with the payload from the
## previous stage. Re-entering a stage (DASHBOARD -> HERO -> back) runs this
## again, so it must be safe to call twice.
func enter(_stage_payload: Dictionary) -> void:
	pass


## Called when the stage is hidden. Stages are kept alive and re-shown rather
## than freed, so this must leave the stage in a state `enter()` can restart
## from.
func exit() -> void:
	pass


# --- shared metrics --------------------------------------------------------- #


## Physical window size, falling back to the viewport when there is no real
## window (headless runs report a 64x64 dummy, which would make every layout
## decision wrong in the same way HudLayout guards against it).
func physical_size() -> Vector2:
	var window := get_window()
	if is_instance_valid(window):
		var window_size := Vector2(window.size)
		if window_size.x >= 320.0 and window_size.y >= 320.0:
			return window_size
	return Vector2(get_viewport_rect().size)


## Uniform canvas scale: how many physical pixels one layout unit occupies.
func stretch_factor(physical: Vector2) -> float:
	return HudLayout.compute_stretch(self, physical)


func to_layout(physical_pixels: float, stretch: float) -> float:
	return physical_pixels / maxf(stretch, 0.0001)


## (left, right, bottom) in physical pixels. Menus use the same function the
## combat HUD uses, so a notch or a gesture bar is respected in both instead of
## being handled twice and drifting apart.
func safe_insets(physical: Vector2) -> Vector3:
	return HudLayout.measure_safe_insets(physical, touch_mode())


func touch_mode() -> bool:
	return DisplayServer.is_touchscreen_available()


## Top inset mirrors TouchControls._resolve_top_inset: the web shell keeps one
## browser toggle on screen, and a notch pushes content down further.
func top_inset(stretch: float) -> float:
	var inset := 12.0 if touch_mode() else 20.0
	if OS.has_feature("web"):
		inset = maxf(inset, 30.0)
	var safe_area := DisplayServer.get_display_safe_area()
	if safe_area.position.y > 0:
		inset = maxf(inset, float(safe_area.position.y))
	return to_layout(inset, stretch)


## Smallest font that still renders at AegisTokens.MIN_PHYSICAL_FONT_PX on the
## real screen. Menus inherit the HUD's readability floor on purpose.
func minimum_font_size(stretch: float) -> int:
	return maxi(roundi(AegisTokens.MIN_PHYSICAL_FONT_PX / maxf(stretch, 0.0001)), 11)


# --- shared widgets --------------------------------------------------------- #


func make_label(text: String, role: String, color: Color, scale: float = 1.0) -> Label:
	var label := Label.new()
	label.text = text
	label.set_meta("aegis_role", role)
	label.set_meta("aegis_scale", scale)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	AegisTheme.style_label(label, role, color, scale)
	return label


func make_button(
	text: String, variant: String, tooltip: String = "", role: String = "title"
) -> AegisButton:
	var button := AegisButton.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.set_meta("aegis_role", role)
	AegisTheme.set_button_variant(button, variant)
	if not tooltip.is_empty():
		button.tooltip_text = tooltip
	return button


## Creates the full-rect safe-area container a menu screen lays out in.
func make_margin() -> MarginContainer:
	_margin = MarginContainer.new()
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_margin)
	return _margin


## Push a container's margins out to the safe area plus a comfortable inset.
## Every menu screen calls this so the reserved edge is defined once.
func apply_safe_margins(
	container: MarginContainer, extra_side: float = 28.0, extra_bottom: float = 24.0
) -> void:
	var physical := physical_size()
	var stretch := stretch_factor(physical)
	var insets := safe_insets(physical)
	container.add_theme_constant_override(
		"margin_left", roundi(to_layout(maxf(insets.x, 0.0) + extra_side, stretch))
	)
	container.add_theme_constant_override(
		"margin_right", roundi(to_layout(maxf(insets.y, 0.0) + extra_side, stretch))
	)
	container.add_theme_constant_override(
		"margin_bottom", roundi(to_layout(maxf(insets.z, 0.0) + extra_bottom, stretch))
	)
	container.add_theme_constant_override(
		"margin_top", roundi(top_inset(stretch) + to_layout(24.0, stretch))
	)


## Grow every font under `root` so it renders at MIN_PHYSICAL_FONT_PX on the
## real screen. Type roles are authored in logical units for a 1280x720 canvas;
## on a phone the canvas is scaled down and a 15 px title lands at ~7 physical
## pixels, which reads as broken rather than small.
func enforce_font_floor(root: Node, stretch: float) -> void:
	var floor_size := minimum_font_size(stretch)
	if root is Label:
		_grow_label(root, floor_size)
	elif root is Button:
		_grow_button(root as Button, floor_size)
	for child in root.find_children("*", "", true, false):
		if child is Label:
			_grow_label(child, floor_size)
		elif child is Button:
			_grow_button(child, floor_size)


func _grow_label(label: Label, floor_size: int) -> void:
	var role := str(label.get_meta("aegis_role", "body"))
	var scale := float(label.get_meta("aegis_scale", 1.0))
	var wanted := maxi(roundi(float(AegisTheme.type_size(role)) * scale), floor_size)
	if label.get_theme_font_size("font_size") < wanted:
		AegisTheme.resize_label(label, role, wanted)


func _grow_button(button: Button, floor_size: int) -> void:
	var role := str(button.get_meta("aegis_role", "title"))
	var wanted := maxi(AegisTheme.type_size(role), floor_size)
	if button.get_theme_font_size("font_size") < wanted:
		AegisTheme.resize_button_font(button, role, wanted)


## Full-bleed backdrop. `cover` keeps the art's aspect and lets the long edge
## run off-screen, which is what the 16:9 key art expects on a tall phone.
func make_backdrop(texture_path: String) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = try_texture(texture_path)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Loads a texture only if it exists. The front end must never hard-fail on
## missing art: a missing plate is a visual regression, a crash is not.
func try_texture(texture_path: String) -> Texture2D:
	if texture_path.is_empty() or not ResourceLoader.exists(texture_path):
		return null
	return load(texture_path) as Texture2D


## The persistent profile the front end owns, or null if this stage is being
## driven by a test that never attached a FrontEnd.
func progression_service() -> ProgressionService:
	if front_end == null:
		return null
	return front_end.get("progression_service") as ProgressionService
