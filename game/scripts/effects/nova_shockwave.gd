class_name NovaShockwave
extends Node3D

## A short, translucent area cue for a *real* Nova impact. It is not a damage
## volume: NovaProjectile alone decides direct/splash damage. The two thin bands
## expand on the hit surface (normally the floor beneath an enemy), while the
## small core stays at the actual collision point. No screen-space whiteout.
const GROUP := "nova_shockwaves"
const LIFETIME := 0.62
const REDUCED_LIFETIME := 0.32
const SEGMENTS := 40

var blast_radius: float = 4.0
var reduce_motion: bool = false
var reduce_flash: bool = false
var _age: float = 0.0
var _trigger_frame: int = -1
var _surface: Node3D
var _front: MeshInstance3D
var _edge: MeshInstance3D
var _core: MeshInstance3D
var _front_material: StandardMaterial3D
var _edge_material: StandardMaterial3D
var _core_material: StandardMaterial3D
var _light: OmniLight3D


static func spawn(
	parent: Node,
	impact: Vector3,
	contact: Vector3,
	normal: Vector3,
	radius: float,
	less_motion: bool = false,
	less_flash: bool = false
) -> NovaShockwave:
	if parent == null or not parent.is_inside_tree():
		return null
	var shock := NovaShockwave.new()
	shock.name = "NovaShockwave"
	shock.blast_radius = clampf(radius, 0.4, 8.0)
	shock.reduce_motion = less_motion
	shock.reduce_flash = less_flash
	parent.add_child(shock)
	shock.global_position = impact
	shock._surface.global_position = contact
	var up := normal.normalized() if normal.length_squared() > 0.01 else Vector3.UP
	if up.dot(Vector3.UP) < 0.999:
		shock._surface.global_basis = Basis(Quaternion(Vector3.UP, up))
	return shock


func _ready() -> void:
	add_to_group(GROUP)
	_surface = Node3D.new()
	_surface.name = "ImpactSurface"
	add_child(_surface)
	_front_material = _material(Color(1.0, 0.42, 0.12), 0.48)
	_edge_material = _material(Color(1.0, 0.8, 0.53), 0.76)
	_core_material = _material(Color(1.0, 0.68, 0.28), 0.72)
	_front = _band("BlastFront", 0.92, 1.0, _front_material)
	_edge = _band("BlastEdge", 0.984, 1.0, _edge_material)
	_edge.position.y = 0.018
	_core = MeshInstance3D.new()
	_core.name = "ImpactCore"
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.13
	core_mesh.height = 0.26
	core_mesh.radial_segments = 8
	core_mesh.rings = 4
	_core.mesh = core_mesh
	_core.material_override = _core_material
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_core.visible = not reduce_flash
	add_child(_core)
	_light = OmniLight3D.new()
	_light.name = "BlastBounce"
	_light.light_color = Color(1.0, 0.49, 0.2)
	_light.light_energy = 0.0 if reduce_flash else 1.3
	_light.omni_range = 2.5
	_light.shadow_enabled = false
	add_child(_light)
	_trigger_frame = Engine.get_process_frames()
	_update_visuals(0.0)


func _band(
	label: String, inner: float, outer: float, material: StandardMaterial3D
) -> MeshInstance3D:
	var vertices := PackedVector3Array()
	for segment in range(SEGMENTS):
		var start := float(segment) * TAU / float(SEGMENTS)
		var end := float(segment + 1) * TAU / float(SEGMENTS)
		var near_start := Vector3(cos(start) * inner, 0.0, sin(start) * inner)
		var far_start := Vector3(cos(start) * outer, 0.0, sin(start) * outer)
		var near_end := Vector3(cos(end) * inner, 0.0, sin(end) * inner)
		var far_end := Vector3(cos(end) * outer, 0.0, sin(end) * outer)
		vertices.append_array(
			PackedVector3Array([near_start, far_start, near_end, far_start, far_end, near_end])
		)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var band := MeshInstance3D.new()
	band.name = label
	band.mesh = mesh
	band.material_override = material
	band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_surface.add_child(band)
	return band


func _material(color: Color, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(color, alpha)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.7
	return material


func _process(delta: float) -> void:
	# Headless WebGL can take >100 ms between renders. Do not spawn and retire an
	# effect in the same frame; it must survive one actual rendered frame.
	if Engine.get_process_frames() == _trigger_frame:
		return
	_age += delta
	var duration := REDUCED_LIFETIME if reduce_motion else LIFETIME
	_update_visuals(clampf(_age / duration, 0.0, 1.0))
	if _age >= duration:
		queue_free()


func _update_visuals(progress: float) -> void:
	var expansion := 1.0 if reduce_motion else 1.0 - pow(1.0 - progress, 2.0)
	var reach := lerpf(0.28, blast_radius, expansion)
	_front.scale = Vector3(reach, 1.0, reach)
	_edge.scale = Vector3(reach * 0.95, 1.0, reach * 0.95)
	var fade := pow(1.0 - progress, 1.25)
	_front_material.albedo_color.a = (0.28 if reduce_flash else 0.48) * fade
	_edge_material.albedo_color.a = (0.42 if reduce_flash else 0.76) * fade
	_core_material.albedo_color.a = 0.72 * clampf(1.0 - progress * 3.2, 0.0, 1.0)
	_light.light_energy = (0.0 if reduce_flash else 1.3) * clampf(1.0 - progress * 3.5, 0.0, 1.0)
