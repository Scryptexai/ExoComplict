extends Control

## Loading screen 16:9 dengan background cinematic, wordmark di tengah-atas,
## bar + persen di bawah, icon robot berjalan (green chroma -> AtlasTexture)
## Digunakan untuk LOADING awal dan LOADING_ASSET kedua.

signal loading_finished

@export var wordmark_texture: Texture2D
@export var background_texture: Texture2D
@export var robot_walk_texture: Texture2D

var _progress: float = 0.0
var _robot_frame: int = 0
var _frame_timer: float = 0.0

@onready var _bar: ProgressBar = $Bar
@onready var _percent_label: Label = $PercentLabel
@onready var _robot_icon: TextureRect = $RobotIcon
@onready var _tip_label: Label = $TipLabel

var _tips := [
	"TIP: Tahan AIM untuk presisi",
	"TIP: EMP hancurkan musuh di dekatmu",
	"TIP: Ganti senjata dengan E / SWAP",
	"TIP: Jelajahi dulu sebelum START DEFENSE"
]
var _tip_index: int = 0
var _tip_timer: float = 0.0


func _ready() -> void:
	if background_texture != null:
		$Background.texture = background_texture
	if wordmark_texture != null:
		$Wordmark.texture = wordmark_texture
	# Robot walk: 4 frame horizontal dari 2048px sheet -> tiap 512px
	if robot_walk_texture != null:
		_robot_icon.texture = robot_walk_texture
	_update_tips(0.0)


func set_progress(p: float) -> void:
	_progress = clampf(p, 0.0, 1.0)
	if is_instance_valid(_bar):
		_bar.value = _progress * 100.0
	if is_instance_valid(_percent_label):
		_percent_label.text = "%d%%" % roundi(_progress * 100.0)
	# gerakkan robot icon seiring progress (0-560px bar width)
	if is_instance_valid(_robot_icon):
		var bar_width := 560.0
		if is_instance_valid(_bar):
			bar_width = _bar.size.x
		_robot_icon.position.x = _bar.position.x + _progress * bar_width - _robot_icon.size.x * 0.5


func _process(delta: float) -> void:
	# animasi robot 8 fps
	_frame_timer += delta
	if _frame_timer >= 0.125:
		_frame_timer = 0.0
		_robot_frame = (_robot_frame + 1) % 4
		_update_robot_frame()
	_tip_timer += delta
	if _tip_timer >= 3.0:
		_tip_timer = 0.0
		_tip_index = (_tip_index + 1) % _tips.size()
		if is_instance_valid(_tip_label):
			_tip_label.text = _tips[_tip_index]
	# auto finish demo: naik 15% per detik
	if _progress < 1.0:
		set_progress(_progress + delta * 0.22)
		if _progress >= 1.0:
			loading_finished.emit()


func _update_robot_frame() -> void:
	if not is_instance_valid(_robot_icon) or robot_walk_texture == null:
		return
	# AtlasTexture crop: tiap frame 1/4 lebar
	var tex_size := robot_walk_texture.get_size()
	var fw := tex_size.x / 4.0
	var fh := tex_size.y
	var atlas := AtlasTexture.new()
	atlas.atlas = robot_walk_texture
	atlas.region = Rect2(fw * _robot_frame, 0, fw, fh)
	_robot_icon.texture = atlas


func _update_tips(_delta: float) -> void:
	if is_instance_valid(_tip_label):
		_tip_label.text = _tips[_tip_index]
