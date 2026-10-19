extends Control

## Dashboard Hub: profile hexagonal, economy dock (coin), tier hero/weapon, menu rail
## Background dashboard_bg_sci_fi.png, wordmark di tengah-atas

signal play_pressed
signal hero_pressed
signal weapon_pressed
signal world_pressed
signal settings_pressed

@export var background_texture: Texture2D
@export var wordmark_texture: Texture2D

@onready var _profile_card: Control = $ProfileCard
@onready var _coin_label: Label = $EconomyDock/CrystalCoin/Label
@onready var _gold_label: Label = $EconomyDock/GoldCoin/Label

var _crystal: int = 1240
var _gold: int = 560


func _ready() -> void:
	if background_texture != null:
		$Background.texture = background_texture
	if wordmark_texture != null:
		$Wordmark.texture = wordmark_texture
	_refresh_economy()


func _refresh_economy() -> void:
	if is_instance_valid(_coin_label):
		_coin_label.text = str(_crystal)
	if is_instance_valid(_gold_label):
		_gold_label.text = str(_gold)


func set_economy(crystal: int, gold: int) -> void:
	_crystal = crystal
	_gold = gold
	_refresh_economy()


func set_profile(hero_name: String, level: int, tier: int) -> void:
	if is_instance_valid(_profile_card):
		_profile_card.get_node("NameLabel").text = hero_name
		_profile_card.get_node("LevelLabel").text = "LVL %d" % level


func _on_play_pressed() -> void:
	play_pressed.emit()


func _on_hero_pressed() -> void:
	hero_pressed.emit()


func _on_weapon_pressed() -> void:
	weapon_pressed.emit()


func _on_world_pressed() -> void:
	world_pressed.emit()
