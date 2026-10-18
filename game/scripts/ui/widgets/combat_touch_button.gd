## An icon-led combat target, not a label in a colored disc. The entire Control
## rect accepts touch; the restrained segmented rim is visual guidance only.
## It remains a Button so mouse, keyboard, controller and simulated touch all
## trigger the same pressed/button_down/button_up signals as before.
class_name CombatTouchButton
extends AegisButton

@export var accent: Color = AegisTokens.INFO:
	set(value):
		accent = value
		queue_redraw()

var _held: bool = false


func _ready() -> void:
	super._ready()
	button_down.connect(_set_held.bind(true))
	button_up.connect(_set_held.bind(false))


func _set_held(value: bool) -> void:
	_held = value
	queue_redraw()


func _draw() -> void:
	super._draw()
	if size.x < 24.0 or size.y < 24.0:
		return
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - minf(size.x, size.y) * 0.065
	var line := maxf(radius * 0.032, 1.0)
	var rim := Color(accent, 0.95 if _held else 0.48)
	# Gaps in the outer rim make each action read as an instrument control,
	# not an opaque web button. The loaded SVG remains the dominant glyph.
	for arc in [Vector2(-2.35, -1.25), Vector2(-0.40, 0.68), Vector2(1.48, 2.34)]:
		draw_arc(center, radius, arc.x, arc.y, 18, rim, line, true)
	if _held:
		draw_arc(center, radius * 0.82, -PI, PI, 48, Color(accent, 0.35), line, true)
