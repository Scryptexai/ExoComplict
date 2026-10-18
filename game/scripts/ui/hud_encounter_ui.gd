## The context-sensitive objective rail and opt-in encounter action. The HUD
## facade owns signals and input; this helper keeps the visual mode policy in
## one place without creating a second controller or a second gameplay state.
class_name HudEncounterUi
extends RefCounted


static func update_objective(
	hud, wave_number: int, active_enemies: int, remaining_enemies: int, state_text: String
) -> void:
	if not is_instance_valid(hud._wave_title_label):
		return
	if hud._play_phase == "explore":
		hud._wave_title_label.text = "EXPLORE THE FRONTIER"
		hud._wave_enemy_label.text = "SAFE ZONE · MOVE FREELY"
		hud._wave_state_label.text = "NO HOSTILES"
		hud._wave_chip_label.text = "EXPLORE\nSAFE"
	elif hud._play_phase == "preparing":
		hud._wave_title_label.text = "DEFENSE IN %d" % hud._preparation_seconds
		# Keep the promise readable in a 390 px portrait objective card.
		hud._wave_enemy_label.text = "GET READY · SPAWNS MARKED"
		hud._wave_state_label.text = "PREPARE"
		hud._wave_chip_label.text = "DEFENSE\nIN %d" % hud._preparation_seconds
	else:
		hud._wave_title_label.text = (
			"WAVE %02d" % wave_number if wave_number > 0 else "FRONTIER DEFENSE"
		)
		hud._wave_state_label.text = state_text.to_upper()
		hud._wave_enemy_label.text = (
			"ENEMIES  %d ACTIVE  ·  %d LEFT" % [active_enemies, remaining_enemies]
		)
		hud._wave_chip_label.text = (
			"WAVE %02d\n%d LEFT" % [wave_number, remaining_enemies]
			if wave_number > 0
			else "READY\n%d LEFT" % remaining_enemies
		)
	hud._compact_wave_text = hud._wave_enemy_label.text
	hud._refresh_compact_label()


static func apply_context(hud) -> void:
	if not is_instance_valid(hud._defense_button):
		return
	var active: bool = (
		not hud._results_visible() and not hud._player_down and not hud.get_tree().paused
	)
	var exploring: bool = hud._play_phase == "explore"
	var preparing: bool = hud._play_phase == "preparing"
	hud._defense_button.visible = active and (exploring or preparing)
	hud._defense_button.disabled = not exploring
	hud._defense_button.text = (
		"DEFENSE IN %d" % hud._preparation_seconds if preparing else "START DEFENSE  [B]"
	)
	hud._wave_card.visible = not hud._results_visible() and hud._play_phase != "results"
	# The old three-line run panel competed with the horizon. Detailed score,
	# BP and shots remain available in pause and results.
	hud._run_card.visible = false
	hud._score_chip.visible = false
	hud._compact_card.visible = false
	hud._desktop_hint.visible = (
		active and not hud._touch_mode and (exploring or preparing) and hud._hud_preset != "MINIMAL"
	)
	if is_instance_valid(hud._pause_restart_button):
		hud._pause_restart_button.text = ("RESET EXPLORATION" if exploring else "RETURN TO EXPLORE")
	if is_instance_valid(hud._pause_stats_label) and exploring:
		hud._pause_stats_label.text = "SAFE ZONE · NO WAVES UNTIL YOU START"


static func build_objective(hud) -> void:
	hud._wave_card = AegisPanel.new()
	hud._wave_card.name = "WaveCard"
	hud._wave_card.clip_contents = true
	hud._top_bar.add_child(hud._wave_card)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	hud._wave_card.add_child(row)

	hud._wave_icon = TextureRect.new()
	hud._wave_icon.texture = AegisTheme.icon("target")
	hud._wave_icon.custom_minimum_size = Vector2(16.0, 16.0)
	hud._wave_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hud._wave_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hud._wave_icon.modulate = AegisTokens.INK_2
	row.add_child(hud._wave_icon)

	var text_col := VBoxContainer.new()
	text_col.add_theme_constant_override("separation", 0)
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_col)
	hud._wave_title_label = hud._label("EXPLORE THE FRONTIER", "heading_s", AegisTokens.INK)
	text_col.add_child(hud._wave_title_label)
	hud._wave_enemy_label = hud._label("SAFE ZONE · MOVE FREELY", "label_s", AegisTokens.INK_2)
	text_col.add_child(hud._wave_enemy_label)
	hud._wave_chip_label = hud._label("EXPLORE\nSAFE", "label_s", AegisTokens.INK_2)
	hud._wave_chip_label.visible = false
	text_col.add_child(hud._wave_chip_label)

	hud._wave_state_label = hud._label("NO HOSTILES", "label_s", AegisTokens.ACCENT)
	hud._wave_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud._wave_state_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(hud._wave_state_label)


static func build_start_action(hud) -> void:
	hud._defense_button = (
		hud
		. _text_button(
			"START DEFENSE  [B]",
			"DefenseStartButton",
			"primary",
			"play",
			"Prepare for Defense (B). No enemies spawn until you start.",
		)
	)
	hud._defense_button.pressed.connect(hud._on_defense_pressed)


## Retain data nodes for results, accessibility preferences, and older smoke
## fixtures without painting run statistics over the exploration sightline.
static func build_legacy_score_widgets(hud) -> void:
	hud._score_chip = AegisPanel.new()
	hud._score_chip.name = "ScoreChip"
	hud._score_chip.show_brackets = false
	hud.add_child(hud._score_chip)
	hud._score_value_label = hud._label("SCORE 0  ·  00:00", "mono_m", AegisTokens.INK)
	hud._score_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud._score_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud._score_value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	hud._score_chip.add_child(hud._score_value_label)

	hud._compact_card = AegisPanel.new()
	hud._compact_card.name = "CompactDataCard"
	hud._compact_card.visible = false
	hud._compact_card.clip_contents = true
	hud.add_child(hud._compact_card)
	hud._compact_label = hud._label(
		hud._compact_wave_text + "\n" + hud._collapsed_run_text(), "mono_s", AegisTokens.INK_2
	)
	hud._compact_label.name = "CompactDataLabel"
	hud._compact_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud._compact_card.add_child(hud._compact_label)
