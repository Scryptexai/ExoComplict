## Read-only, compact magazine indicator beside the touch SWAP button.
## A label outside the Button keeps the existing weapon name/press target intact.
class_name AegisAmmoChip
extends AegisPanel

var value_label: Label


func _ready() -> void:
	super._ready()
	show_brackets = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override(
		"panel",
		AegisTheme.panel_style(
			Color(AegisTokens.PANEL, AegisTokens.PANEL_ALPHA),
			AegisTokens.LINE,
			1,
			AegisTokens.RADIUS,
			2.0
		)
	)
	value_label = Label.new()
	value_label.name = "AmmoValue"
	value_label.text = "24/24"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.set_meta("aegis_role", "mono_s")
	value_label.set_meta("aegis_scale", 1.0)
	AegisTheme.style_label(value_label, "mono_s", AegisTokens.INK)
	add_child(value_label)


func set_ammo(remaining: int, capacity: int, reloading: bool) -> void:
	if not is_instance_valid(value_label):
		return
	value_label.text = "RELOAD" if reloading else "%d/%d" % [remaining, capacity]
	value_label.add_theme_color_override(
		"font_color",
		(
			AegisTokens.ACCENT
			if reloading
			else (AegisTokens.DANGER if remaining == 0 else AegisTokens.INK)
		)
	)
