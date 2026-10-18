## Geometry for the three HUD layouts. Kept out of touch_controls.gd so the
## runtime facade stays readable and each platform layout can be reviewed (and
## tuned on a device) on its own.
##
## Every function takes the live HUD as an untyped host: typing it as
## TouchControls would create a cyclic script reference, and the HUD is the only
## caller. Positions are expressed in physical design pixels and converted with
## the host's `_to_layout()` so the same numbers work at 390 px and at 1280 px.
class_name HudLayout
extends RefCounted


static func over_hud(hud, position: Vector2) -> bool:
	var hud_controls: Array[Control] = [
		hud._top_bar,
		hud._wave_card,
		hud._defense_button,
		hud._armory_button,
		hud._armory_panel,
		hud._help_panel,
		hud._fire_button,
		hud._weapon_button,
		hud._skill_button,
		hud._aim_button,
		hud._touch_ammo_chip,
		hud._pause_panel,
		hud._results_panel,
		hud._settings_menu,
		hud._run_card,
		hud._score_chip,
		hud._desktop_weapon_card,
		hud._emp_chip,
		hud._ads_chip,
		hud._compact_card,
	]
	for control in hud_controls:
		if (
			is_instance_valid(control)
			and control.visible
			and control.get_global_rect().has_point(position)
		):
			return true
	return false


static func desktop(hud) -> void:
	var unit: float = hud._control_unit()
	var inset := 20.0 * unit
	_place_top_bar(hud, inset, hud._top_inset, 64.0 * unit)
	_place_in_top_bar(hud._health_card, 0, 0, 0, 0, Rect2(0, 0, 268.0 * unit, 56.0 * unit))
	# Destiny-style objective hierarchy: the task sits below health on the
	# left, never across the sightline in the centre of the screen.
	_place_in_top_bar(hud._wave_card, 0, 0, 0, 0, Rect2(0, 64.0 * unit, 306.0 * unit, 56.0 * unit))
	_place(
		hud._defense_button,
		0,
		0,
		0,
		0,
		Rect2(inset, hud._top_inset + 128.0 * unit, 230.0 * unit, 52.0 * unit)
	)
	_place_in_top_bar(
		hud._system_row, 1, 0, 1, 0, Rect2(-152.0 * unit, 0, 152.0 * unit, 56.0 * unit)
	)
	_place(
		hud._armory_button,
		0,
		0,
		0,
		0,
		Rect2(inset + 320.0 * unit, hud._top_inset + 64.0 * unit, 186.0 * unit, 52.0 * unit)
	)
	_place(
		hud._score_chip,
		1,
		0,
		1,
		0,
		Rect2(-inset - 184.0 * unit, hud._top_inset + 72.0 * unit, 184.0 * unit, 30.0 * unit)
	)
	_place(
		hud._run_card,
		0,
		1,
		0,
		1,
		Rect2(inset, -(inset + 28.0 * unit + 76.0 * unit), 320.0 * unit, 76.0 * unit)
	)
	_place(
		hud._desktop_weapon_card,
		1,
		1,
		1,
		1,
		Rect2(-inset - 268.0 * unit, -inset - 76.0 * unit, 268.0 * unit, 76.0 * unit)
	)
	var chip_bottom := -inset - 76.0 * unit - 8.0 * unit - 36.0 * unit
	_place(
		hud._emp_chip,
		1,
		1,
		1,
		1,
		Rect2(-inset - 172.0 * unit, chip_bottom, 172.0 * unit, 36.0 * unit)
	)
	_place(
		hud._ads_chip,
		1,
		1,
		1,
		1,
		Rect2(
			-inset - 172.0 * unit - 8.0 * unit - 76.0 * unit, chip_bottom, 76.0 * unit, 36.0 * unit
		)
	)
	_place(
		hud._desktop_hint, 0, 1, 0, 1, Rect2(inset, -inset - 20.0 * unit, 640.0 * unit, 18.0 * unit)
	)

	hud._show_top_wave_details(true)
	hud._compact_card.visible = false
	hud._run_card.visible = true
	hud._score_chip.visible = true
	hud._sound_button.visible = true
	hud._wave_icon.visible = true
	_place_help(
		hud,
		inset,
		hud._top_inset + 64.0 * unit + 8.0 * unit,
		560.0 * unit,
		hud._help_block_height(3)
	)
	_place_compact(hud, inset, 0.0, false)


static func touch_portrait(hud) -> void:
	var edge: float = hud._to_layout(12.0)
	var bar_height: float = hud._to_layout(56.0)
	_place_top_bar(hud, edge, hud._top_inset, bar_height)
	_place_in_top_bar(hud._health_card, 0, 0, 0, 0, Rect2(0, 0, hud._to_layout(184.0), bar_height))
	var objective_top: float = bar_height + hud._to_layout(8.0)
	# The old 354 px objective plus two vertically stacked 234 px actions hid
	# the first third of the bay. Keep the readout legible, then share one row
	# between the deliberate Defense start and the Explore-only Armory choice.
	var objective_width: float = minf(hud._to_layout(270.0), hud.size.x - edge * 2.0)
	_place_in_top_bar(
		hud._wave_card, 0, 0, 0, 0, Rect2(0, objective_top, objective_width, hud._to_layout(56.0))
	)
	var action_top: float = hud._top_inset + objective_top + hud._to_layout(64.0)
	var available_px: float = hud._physical_size.x - 24.0
	var start_px: float = minf(208.0, available_px * 0.615)
	var armory_px: float = minf(148.0, available_px - start_px - 8.0)
	_place(
		hud._defense_button,
		0,
		0,
		0,
		0,
		Rect2(edge, action_top, hud._to_layout(start_px), hud._to_layout(56.0))
	)
	_place(
		hud._armory_button,
		1,
		0,
		1,
		0,
		Rect2(
			-edge - hud._to_layout(armory_px),
			action_top,
			hud._to_layout(armory_px),
			hud._to_layout(56.0)
		)
	)
	# Match the pause glyph to its target instead of a tiny symbol in a 88 px
	# wide empty rectangle. 56 px remains a finger-sized hit area.
	var system_width: float = hud._to_layout(56.0 if hud._narrow else 112.0)
	_place_in_top_bar(
		hud._system_row, 1, 0, 1, 0, Rect2(-system_width, 0, system_width, bar_height)
	)

	# Actual 390x844 WebGL review: the four plates crowded the right side and
	# SHOOT looked like a toy despite a large bbox. Reserve that thumb for FIRE,
	# ADS, EMP; dock weapon + ammo by the movement thumb, as in the live mobile
	# control reference. In portrait this leaves the hero and aiming lane clear.
	# FIRE x218..378/y646..806; ADS x282..378/y538..634;
	# EMP x282..378/y432..528. An actual held-ADS screenshot exposed the
	# first bottom-left weapon dock covering the helmet. Dock the infrequent
	# swap action BELOW Start but ABOVE the hero instead, with ammo alongside.
	_place_button(hud, hud._fire_button, 12.0, 38.0, 160.0, 160.0)
	_place_button(hud, hud._aim_button, 12.0, 210.0, 96.0, 96.0)
	_place_button(hud, hud._skill_button, 12.0, 316.0, 96.0, 96.0)
	var dock_top: float = action_top + hud._to_layout(64.0)
	_place_weapon_dock(hud, hud._weapon_button, 12.0, dock_top, 104.0, 104.0)
	_place_weapon_dock(
		hud, hud._touch_ammo_chip, 128.0, dock_top + hud._to_layout(18.0), 112.0, 54.0
	)
	_place(
		hud._skill_ring,
		1,
		1,
		1,
		1,
		Rect2(
			-hud._to_layout(112.0),
			-hud._to_layout(416.0),
			hud._to_layout(104.0),
			hud._to_layout(104.0)
		)
	)
	_place(
		hud._score_chip,
		1,
		0,
		1,
		0,
		Rect2(
			-edge - hud._to_layout(184.0),
			hud._top_inset + bar_height + hud._to_layout(8.0),
			hud._to_layout(184.0),
			hud._to_layout(30.0)
		)
	)

	_mirror_skill_ring(hud)
	var stick_x: float = hud._to_layout(86.0)
	hud._joystick_center = Vector2(
		hud.size.x - stick_x if hud._left_handed else stick_x, hud.size.y - hud._to_layout(106.0)
	)
	hud._joystick_radius = hud._to_layout(72.0)

	hud._show_top_wave_details(true)
	# The objective now has its own row: display a readable description instead
	# of cramming a two-word badge between health and pause.
	hud._wave_state_label.visible = false
	hud._run_card.visible = false
	hud._score_chip.visible = false
	hud._sound_button.visible = false
	hud._wave_icon.visible = false
	_place_compact(hud, edge, 0.0, false)
	_place_help(
		hud,
		edge,
		hud._top_inset + objective_top + hud._to_layout(128.0),
		minf(hud._to_layout(342.0), hud.size.x - edge * 2.0),
		hud._help_block_height(2)
	)
	if not hud._touch_mode:
		_place(
			hud._desktop_hint,
			0,
			1,
			0,
			1,
			Rect2(edge, -edge - hud._to_layout(18.0), hud.size.x - edge * 2.0, hud._to_layout(18.0))
		)


static func touch_landscape(hud) -> void:
	var edge: float = hud._to_layout(44.0)
	var bar_height: float = hud._to_layout(56.0)
	_place_top_bar(hud, edge, hud._top_inset, bar_height)
	_place_in_top_bar(hud._health_card, 0, 0, 0, 0, Rect2(0, 0, hud._to_layout(208.0), bar_height))
	var objective_top: float = bar_height + hud._to_layout(8.0)
	_place_in_top_bar(
		hud._wave_card,
		0,
		0,
		0,
		0,
		Rect2(0, objective_top, hud._to_layout(294.0), hud._to_layout(60.0))
	)
	_place(
		hud._defense_button,
		0,
		0,
		0,
		0,
		Rect2(
			edge,
			hud._top_inset + objective_top + hud._to_layout(68.0),
			hud._to_layout(230.0),
			hud._to_layout(56.0)
		)
	)
	_place_in_top_bar(
		hud._system_row,
		1,
		0,
		1,
		0,
		Rect2(-hud._to_layout(152.0), 0, hud._to_layout(152.0), bar_height)
	)
	_place(
		hud._armory_button,
		0,
		0,
		0,
		0,
		Rect2(
			edge + hud._to_layout(306.0),
			hud._top_inset + objective_top,
			hud._to_layout(186.0),
			hud._to_layout(56.0)
		)
	)

	# 844x390: keep a 12+ px separation while giving the primary action a
	# real 148px face. Ammo stays attached to swap, not floating by the hero.
	# FIRE x684..832/y229..377; ADS x738..832/y123..217;
	# EMP x580..674/y240..334; WEAPON x630..724/y123..217.
	_place_button(hud, hud._fire_button, 12.0, 13.0, 148.0, 148.0)
	_place_button(hud, hud._aim_button, 12.0, 173.0, 94.0, 94.0)
	_place_button(hud, hud._skill_button, 170.0, 56.0, 94.0, 94.0)
	_place_button(hud, hud._weapon_button, 120.0, 173.0, 94.0, 94.0)
	# y174..228: a real 14px gap below Armory and 12px before EMP.
	_place_button(hud, hud._touch_ammo_chip, 226.0, 162.0, 112.0, 54.0)
	# Cooldown ring remains centred around the actual EMP face.
	_place(
		hud._skill_ring,
		1,
		1,
		1,
		1,
		Rect2(
			-hud._to_layout(268.0),
			-hud._to_layout(154.0),
			hud._to_layout(102.0),
			hud._to_layout(102.0)
		)
	)

	_mirror_skill_ring(hud)
	var stick_x: float = hud._to_layout(120.0)
	hud._joystick_center = Vector2(
		hud.size.x - stick_x if hud._left_handed else stick_x, hud.size.y - hud._to_layout(90.0)
	)
	hud._joystick_radius = hud._to_layout(64.0)

	hud._show_top_wave_details(true)
	# On a 390 px-high display the optional state badge steals the objective's
	# width and squeezes its description into the corner. The title/remaining
	# count already communicate the state; leave the description its own row.
	hud._wave_state_label.visible = false
	hud._sound_button.visible = true
	hud._wave_icon.visible = false
	hud._compact_card.visible = false
	hud._run_card.visible = true
	hud._score_chip.visible = false
	_place(
		hud._run_card,
		1,
		0,
		1,
		0,
		Rect2(
			-edge - hud._to_layout(236.0),
			hud._top_inset + bar_height + hud._to_layout(8.0),
			hud._to_layout(236.0),
			hud._to_layout(64.0)
		)
	)
	# Retain an anchor for the help panel across rotations, but never show it
	# over the enlarged action row on a 390px-high landscape playfield.
	_place(
		hud._help_panel,
		1,
		0,
		1,
		0,
		Rect2(
			-edge - hud._to_layout(220.0),
			hud._top_inset + bar_height + hud._to_layout(2.0),
			hud._to_layout(220.0),
			hud._help_block_height(2)
		)
	)
	hud._help_panel.visible = false


## Portrait menus are bottom sheets above the gesture area; wide layouts use
## centered cards. The same pause/results widgets work in both orientations.
static func overlays(hud) -> void:
	var sheet: bool = hud._portrait and hud._narrow
	var anchor_y := 1.0 if sheet else 0.5
	var sheet_bottom: float = hud._to_layout(34.0) if sheet else 0.0

	var results_width: float = minf(
		hud._to_layout(390.0 if sheet else 600.0), hud.size.x * (0.94 if sheet else 0.92)
	)
	var results_height: float = minf(hud._to_layout(528.0), hud.size.y * (0.86 if sheet else 0.9))
	hud._results_panel.custom_minimum_size = Vector2(results_width, results_height)
	_place(
		hud._results_panel,
		0.5,
		anchor_y,
		0.5,
		anchor_y,
		Rect2(
			-results_width * 0.5,
			-results_height - sheet_bottom if sheet else -results_height * 0.5,
			results_width,
			results_height
		)
	)
	hud._results_retry_button.custom_minimum_size = Vector2(
		minf(hud._to_layout(302.0 if sheet else 240.0), results_width - hud._to_layout(48.0)),
		hud._to_layout(56.0 if sheet else 52.0)
	)
	hud._results_retry_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hud._results_explore_button.custom_minimum_size = hud._results_retry_button.custom_minimum_size
	hud._results_explore_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hud._results_goal_bar.custom_minimum_size.y = hud._to_layout(8.0)

	var pause_width: float = minf(
		hud._to_layout(390.0 if sheet else 400.0), hud.size.x * (0.94 if sheet else 0.88)
	)
	var pause_height: float = minf(
		hud._to_layout(340.0 if sheet else 390.0), hud.size.y * (0.86 if sheet else 0.9)
	)
	hud._pause_panel.custom_minimum_size = Vector2(pause_width, pause_height)
	_place(
		hud._pause_panel,
		0.5,
		anchor_y,
		0.5,
		anchor_y,
		Rect2(
			-pause_width * 0.5,
			-pause_height - sheet_bottom if sheet else -pause_height * 0.5,
			pause_width,
			pause_height
		)
	)
	for button in [hud._pause_resume_button, hud._pause_restart_button, hud._pause_settings_button]:
		if is_instance_valid(button):
			button.custom_minimum_size = Vector2(0.0, hud._to_layout(56.0 if sheet else 52.0))


static func place(
	_hud, control: Control, al: float, at: float, ar: float, ab: float, rect: Rect2
) -> void:
	_place(control, al, at, ar, ab, rect)


static func _place_top_bar(hud, left: float, top: float, height: float) -> void:
	hud._top_bar.offset_left = left
	hud._top_bar.offset_top = top
	hud._top_bar.offset_right = -left
	hud._top_bar.offset_bottom = top + height


static func _place_in_top_bar(
	control: Control, al: float, at: float, ar: float, ab: float, rect: Rect2
) -> void:
	_place(control, al, at, ar, ab, rect)


static func _place(
	control: Control, al: float, at: float, ar: float, ab: float, rect: Rect2
) -> void:
	control.anchor_left = al
	control.anchor_top = at
	control.anchor_right = ar
	control.anchor_bottom = ab
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.position.x + rect.size.x
	control.offset_bottom = rect.position.y + rect.size.y


static func _place_button(
	hud, button: Control, right_px: float, bottom_px: float, w_px: float, h_px: float
) -> void:
	var right: float = hud._to_layout(right_px)
	var bottom: float = hud._to_layout(bottom_px)
	var width: float = hud._to_layout(w_px)
	var height: float = hud._to_layout(h_px)
	if hud._left_handed:
		_place(button, 0, 1, 0, 1, Rect2(right, -bottom - height, width, height))
	else:
		_place(button, 1, 1, 1, 1, Rect2(-right - width, -bottom - height, width, height))
	button.custom_minimum_size = Vector2(width, height)


## Weapon + ammo live opposite the firing thumb in portrait. Mirroring both
## docks together preserves the handedness option without mirroring the art.
static func _place_weapon_dock(
	hud, control: Control, side_px: float, top: float, w_px: float, h_px: float
) -> void:
	var side: float = hud._to_layout(side_px)
	var width: float = hud._to_layout(w_px)
	var height: float = hud._to_layout(h_px)
	if hud._left_handed:
		_place(control, 1, 0, 1, 0, Rect2(-side - width, top, width, height))
	else:
		_place(control, 0, 0, 0, 0, Rect2(side, top, width, height))
	control.custom_minimum_size = Vector2(width, height)


static func _mirror_skill_ring(hud) -> void:
	if not hud._left_handed:
		return
	var old_left: float = hud._skill_ring.offset_left
	var old_right: float = hud._skill_ring.offset_right
	hud._skill_ring.anchor_left = 0.0
	hud._skill_ring.anchor_right = 0.0
	hud._skill_ring.offset_left = -old_right
	hud._skill_ring.offset_right = -old_left


static func _place_compact(hud, left: float, top: float, visible: bool) -> float:
	if not is_instance_valid(hud._compact_card):
		return 0.0
	hud._compact_card.visible = visible
	if not visible:
		return 0.0
	var font := float(hud._compact_label.get_theme_font_size("font_size"))
	var height: float = font * 1.45 * float(hud.COMPACT_LINES) + hud._to_layout(16.0)
	_place(hud._compact_card, 0, 0, 1, 0, Rect2(left, top, -left * 2.0, height))
	hud._compact_label.custom_minimum_size = Vector2.ZERO
	return height


static func _place_help(hud, left: float, top: float, width: float, height: float) -> void:
	_place(hud._help_panel, 0.5, 0, 0.5, 0, Rect2(-width * 0.5, top, width, height))
	hud._help_panel.offset_left = -width * 0.5
	hud._help_panel.offset_right = width * 0.5
	hud._help_panel.offset_left = maxf(hud._help_panel.offset_left, -hud.size.x * 0.5 + left)
	hud._help_panel.offset_right = minf(hud._help_panel.offset_right, hud.size.x * 0.5 - left)
