class_name MuzzleFlash
extends Node3D

## A directional flash anchored to the weapon's measured MuzzlePoint. The cone
## projects along local -Z (the barrel axis); short radial sparks break the
## round "glowing ball" silhouette without covering the sight line. Every mesh
## is transient and the accompanying light has a bounded range for mobile/Web.

@export_range(0.02, 0.4, 0.005) var duration: float = 0.14
@export_range(0.0, 12.0, 0.1) var flash_energy: float = 3.6
@export_range(0.02, 2.0, 0.01) var flash_scale: float = 0.42
@export var flash_color: Color = Color(1.0, 0.74, 0.4, 1.0)

var _mesh: MeshInstance3D
var _core: MeshInstance3D
var _streaks: Array[MeshInstance3D] = []
var _light: OmniLight3D
var _material: StandardMaterial3D
var _remaining: float = 0.0
# Preserve at least one render even when device frame time exceeds duration.
var _trigger_frame: int = -1


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_material.albedo_color = flash_color
	_material.emission_enabled = true
	_material.emission = flash_color
	_material.emission_energy_multiplier = flash_energy

	var cone := CylinderMesh.new()
	cone.top_radius = 0.007
	cone.bottom_radius = 0.18
	cone.height = 0.68
	cone.radial_segments = 9
	_mesh = _add_shape("FlashCone", cone)
	_mesh.rotation.x = -PI * 0.5
	_mesh.position.z = -0.26

	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.09
	core_mesh.height = 0.18
	core_mesh.radial_segments = 8
	core_mesh.rings = 4
	_core = _add_shape("FlashCore", core_mesh)
	_core.position.z = -0.025

	var streak_mesh := BoxMesh.new()
	streak_mesh.size = Vector3(0.026, 0.30, 0.05)
	for index in range(4):
		var streak := _add_shape("FlashSpark_%d" % index, streak_mesh)
		var angle := TAU * float(index) / 4.0
		streak.position = Vector3(sin(angle), cos(angle), -0.16) * Vector3(0.14, 0.14, 1.0)
		streak.rotation.z = -angle
		_streaks.append(streak)

	_light = OmniLight3D.new()
	_light.name = "FlashLight"
	_light.light_color = flash_color
	_light.light_energy = 0.0
	# Tight transient bounce around the weapon; broad cyan ground wash hid
	# the FBX material contrast in the WebGL phone capture.
	_light.omni_range = 2.8
	_light.shadow_enabled = false
	add_child(_light)


func _add_shape(node_name: String, shape: Mesh) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.mesh = shape
	mesh.material_override = _material
	mesh.visible = false
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	return mesh


func _set_active(active: bool) -> void:
	_mesh.visible = active
	_core.visible = active
	for streak in _streaks:
		streak.visible = active


func _process(delta: float) -> void:
	if _remaining <= 0.0 or Engine.get_process_frames() == _trigger_frame:
		return
	_remaining = maxf(_remaining - delta, 0.0)
	var ratio := _remaining / maxf(duration, 0.0001)
	_light.light_energy = flash_energy * 0.7 * ratio
	_material.albedo_color.a = clampf(ratio * 1.6, 0.0, 1.0)
	if _remaining <= 0.0:
		_set_active(false)
		_light.light_energy = 0.0


## Fire from the calibrated barrel point; color distinguishes the three weapon
## discharge types without pretending that they are three different 3D models.
func flash(strength: float = 1.0, tint: Color = Color(0.0, 0.0, 0.0, 0.0)) -> void:
	var color := tint if tint.a > 0.0 else flash_color
	_material.albedo_color = color
	_material.emission = color
	_light.light_color = color
	_remaining = duration * clampf(strength, 0.4, 2.0)
	_trigger_frame = Engine.get_process_frames()
	_set_active(true)
	_material.albedo_color.a = 1.0
	_light.light_energy = flash_energy * 0.7
	var size := flash_scale / 0.34 * randf_range(0.88, 1.12)
	_mesh.scale = Vector3.ONE * size
	_core.scale = Vector3.ONE * size
	for streak in _streaks:
		streak.scale = Vector3.ONE * size
		streak.rotation.z += randf_range(-0.1, 0.1)


func is_flashing() -> bool:
	return _remaining > 0.0
