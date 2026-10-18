## Short, non-interactive status chip below the sightline. The world and all
## buttons remain touchable; meaningful outcomes (EMP, wave award) are legible
## even when a one-frame VFX is missed on a slower browser renderer.
class_name HudCombatFeedbackUi
extends AegisPanel

var _message_label: Label
var _remaining: float = 0.0


func _ready() -> void:
	accent_color = AegisTokens.INFO
	accent_side = "left"
	super._ready()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message_label = Label.new()
	_message_label.name = "CombatMessage"
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message_label.set_meta("aegis_role", "title")
	_message_label.set_meta("aegis_scale", 1.0)
	AegisTheme.style_label(_message_label, "title", AegisTokens.INK)
	add_child(_message_label)
	visible = false


func _process(delta: float) -> void:
	if _remaining > 0.0:
		_remaining = maxf(_remaining - delta, 0.0)
		if _remaining <= 0.0:
			visible = false


func show_message(text: String) -> void:
	if text.is_empty():
		return
	_message_label.text = text
	_remaining = 1.9
	visible = true


func clear_message() -> void:
	_remaining = 0.0
	visible = false


func layout_for(hud) -> void:
	var width: float = minf(hud._to_layout(272.0), hud.size.x - hud._to_layout(24.0))
	HudLayout.place(
		hud,
		self,
		0.5,
		0.5,
		0.5,
		0.5,
		Rect2(-width * 0.5, hud._to_layout(64.0), width, hud._to_layout(40.0))
	)
