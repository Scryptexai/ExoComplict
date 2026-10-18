## Large, icon-led combat target. Its matte backing and pronounced rim survive
## both the bright FBX deck and the dark reactor, while the entire Button rect
## remains the same accessible touch / mouse / controller target.
class_name CombatTouchButton
extends AegisButton

@export var accent: Color = AegisTokens.INFO:
	set(value):
		accent = value
		queue_redraw()
@export var is_primary: bool = false:
	set(value):
		is_primary = value
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
	var radius := minf(size.x, size.y) * 0.445
	# The old hairline was ~1 px on a 390 px Web canvas. Scale the stroke
	# with the target so it stays visible after Godot's canvas stretch.
	var line := maxf(radius * (0.052 if is_primary else 0.046), 1.0)
	var rim := Color(accent, 1.0 if _held else (0.92 if is_primary else 0.76))
	for arc in [Vector2(-2.35, -1.25), Vector2(-0.40, 0.68), Vector2(1.48, 2.34)]:
		draw_arc(center, radius, arc.x, arc.y, 28, rim, line, true)
	if _held:
		draw_arc(center, radius * 0.84, -PI, PI, 64, Color(accent, 0.53), line * 0.8, true)
