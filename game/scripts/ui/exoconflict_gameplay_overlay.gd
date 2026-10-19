extends Control
## Overlay tambahan di gameplay: profile card hexagonal + resource + mini-map
## Ditempel di atas touch_controls sebagai sibling

@export var profile_texture: Texture2D
@export var coin_icon: Texture2D
@export var map_texture: Texture2D

@onready var _profile_name: Label = $ProfileCard/Name
@onready var _health_bar: ProgressBar = $ProfileCard/HealthBar
@onready var _shield_bar: ProgressBar = $ProfileCard/ShieldBar
@onready var _bp_label: Label = $ResourceCard/BPLabel
@onready var _ammo_label: Label = $ResourceCard/AmmoLabel
@onready var _map_rect: TextureRect = $MapCard/Map

var _hero_name: String = "NEXUS-01"
var _bp: int = 0
var _ammo: String = "24/24"


func _ready() -> void:
	if profile_texture != null and is_instance_valid($ProfileCard/Avatar):
		$ProfileCard/Avatar.texture = profile_texture
	if map_texture != null and is_instance_valid(_map_rect):
		_map_rect.texture = map_texture
	_refresh()


func set_profile(hero_name: String, health: float, max_health: float) -> void:
	_hero_name = hero_name
	if is_instance_valid(_profile_name):
		_profile_name.text = hero_name
	if is_instance_valid(_health_bar):
		_health_bar.max_value = max_health
		_health_bar.value = health
	_refresh()


func set_resource(bp: int, ammo_text: String) -> void:
	_bp = bp
	_ammo_text = ammo_text if ammo_text != "" else _ammo
	if is_instance_valid(_bp_label):
		_bp_label.text = str(_bp) + " BP"
	if is_instance_valid(_ammo_label):
		_ammo_label.text = _ammo_text


var _ammo_text: String = "24/24"


func _refresh() -> void:
	if is_instance_valid(_profile_name):
		_profile_name.text = _hero_name
