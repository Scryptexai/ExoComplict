extends Control
## 3-step selection modal: HERO -> WEAPON -> WORLD
## Tiap card hexagonal, locked dengan blur + gembok, tap -> detail modal

signal hero_selected(hero_id: String)
signal weapon_selected(weapon_id: String)
signal world_selected(world_id: String)
signal play_requested

@export var flow: ExoconflictFlow

enum Mode { HERO, WEAPON, WORLD }

var _mode: Mode = Mode.HERO
@onready var _grid: GridContainer = $Grid
@onready var _detail: Control = $DetailModal
@onready var _title: Label = $Header/TitleLabel
@onready var _play_button: Button = $PlayButton

var _selected_hero: String = "nexus01"
var _selected_weapon: String = "pulse_rifle"
var _selected_world: String = "neon_frontier"


func _ready() -> void:
	_play_button.visible = false
	if flow != null:
		show_mode(Mode.HERO)


func show_mode(m: Mode) -> void:
	_mode = m
	_detail.visible = false
	match m:
		Mode.HERO:
			_title.text = "PILIH HERO — 1/3"
			_build_hero_cards()
		Mode.WEAPON:
			_title.text = "PILIH SENJATA — 2/3"
			_build_weapon_cards()
		Mode.WORLD:
			_title.text = "PILIH DUNIA — 3/3"
			_build_world_cards()
			_play_button.visible = true
		GridContainer:
			pass


func _clear_grid() -> void:
	for c in _grid.get_children():
		c.queue_free()


func _build_hero_cards() -> void:
	_clear_grid()
	if flow == null:
		return
	for h in flow.hero_defs:
		var card := _make_card(h["name"], h["class"], h["image"], h["locked"], h["stats"], h["desc"])
		card.pressed.connect(_on_hero_card_pressed.bind(h["id"], h))
		_grid.add_child(card)


func _build_weapon_cards() -> void:
	_clear_grid()
	if flow == null:
		return
	for w in flow.weapon_defs:
		var card := _make_card(w["name"], "", w["image"], w["locked"], w["stats"], w["desc"])
		card.pressed.connect(_on_weapon_card_pressed.bind(w["id"], w))
		_grid.add_child(card)


func _build_world_cards() -> void:
	_clear_grid()
	if flow == null:
		return
	for wd in flow.world_defs:
		var card := _make_card(wd["name"], wd["sub"], wd["image"], wd["locked"], wd["stats"], wd["desc"])
		card.pressed.connect(_on_world_card_pressed.bind(wd["id"], wd))
		_grid.add_child(card)


func _make_card(title: String, sub: String, texture_path: String, locked: bool, stats: Dictionary, desc: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(220, 280)
	b.text = "%s\n%s" % [title, sub]
	# TODO: pakai TextureRect + hexagonal shader; sekarang pakai text dulu agar tidak dependensi texture load async
	b.disabled = false # locked tetap bisa tap untuk lihat detail
	b.set_meta("locked", locked)
	b.set_meta("stats", stats)
	b.set_meta("desc", desc)
	b.set_meta("texture", texture_path)
	return b


func _on_hero_card_pressed(id: String, data: Dictionary) -> void:
	if data["locked"]:
		_show_detail_locked(data)
		return
	_selected_hero = id
	_show_detail(data, func(): _confirm_hero())


func _on_weapon_card_pressed(id: String, data: Dictionary) -> void:
	if data["locked"]:
		_show_detail_locked(data)
		return
	_selected_weapon = id
	_show_detail(data, func(): _confirm_weapon())


func _on_world_card_pressed(id: String, data: Dictionary) -> void:
	if data["locked"]:
		_show_detail_locked(data)
		return
	_selected_world = id
	_show_detail(data, func(): _confirm_world())


func _show_detail(data: Dictionary, on_pick: Callable) -> void:
	_detail.visible = true
	_detail.get_node("DescLabel").text = data["desc"]
	_detail.get_node("StatsLabel").text = str(data["stats"])
	_detail.get_node("PickButton").pressed.connect(on_pick, CONNECT_ONE_SHOT)


func _show_detail_locked(data: Dictionary) -> void:
	_detail.visible = true
	_detail.get_node("DescLabel").text = data["desc"] + "\n[LOCKED] Mainkan wave untuk unlock"
	_detail.get_node("StatsLabel").text = str(data["stats"])


func _confirm_hero() -> void:
	_detail.visible = false
	if flow != null:
		flow.select_hero(_selected_hero)
	hero_selected.emit(_selected_hero)
	show_mode(Mode.WEAPON)


func _confirm_weapon() -> void:
	_detail.visible = false
	if flow != null:
		flow.select_weapon(_selected_weapon)
	weapon_selected.emit(_selected_weapon)
	show_mode(Mode.WORLD)


func _confirm_world() -> void:
	_detail.visible = false
	if flow != null:
		flow.select_world(_selected_world)
	world_selected.emit(_selected_world)


func _on_play_pressed() -> void:
	play_requested.emit()
