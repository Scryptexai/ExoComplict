@tool
extends RefCounted

# Preloading imported scenes makes the GLTFs and their BIN/texture dependencies visible to
# Godot's export dependency scanner. Keep these paths static so Android PCK exports include them.
const MODEL_SCENES: Dictionary = {
	"cargo_A_stacked":
	preload("res://assets/world/kaykit_space_base_bits/gltf/cargo_A_stacked.gltf"),
	"cargo_B_stacked":
	preload("res://assets/world/kaykit_space_base_bits/gltf/cargo_B_stacked.gltf"),
	"cargodepot_A": preload("res://assets/world/kaykit_space_base_bits/gltf/cargodepot_A.gltf"),
	"drill_structure":
	preload("res://assets/world/kaykit_space_base_bits/gltf/drill_structure.gltf"),
	"landingpad_large":
	preload("res://assets/world/kaykit_space_base_bits/gltf/landingpad_large.gltf"),
	"rocks_B": preload("res://assets/world/kaykit_space_base_bits/gltf/rocks_B.gltf"),
	"spacetruck_large":
	preload("res://assets/world/kaykit_space_base_bits/gltf/spacetruck_large.gltf"),
}


static func instantiate_model(model_name: String) -> Node3D:
	if not MODEL_SCENES.has(model_name):
		push_warning("Unknown external world asset: " + model_name)
		return null

	var packed_scene := MODEL_SCENES[model_name] as PackedScene
	if packed_scene == null:
		push_warning("External world asset was not imported as a PackedScene: " + model_name)
		return null

	var instance := packed_scene.instantiate() as Node3D
	if instance == null:
		push_warning("External world asset did not instantiate as Node3D: " + model_name)
	return instance


static func add_bounds_collider(
	model_root: Node3D, collider_name: String, fill_ratio: float = 0.88
) -> StaticBody3D:
	if not is_instance_valid(model_root):
		return null
	var mesh_nodes := model_root.find_children("*", "MeshInstance3D", true, false)
	if mesh_nodes.is_empty():
		return null

	var inverse_root := model_root.global_transform.affine_inverse()
	var has_bounds := false
	var model_bounds := AABB()
	for child in mesh_nodes:
		var mesh_instance := child as MeshInstance3D
		if not is_instance_valid(mesh_instance) or mesh_instance.mesh == null:
			continue
		var relative_transform := inverse_root * mesh_instance.global_transform
		var mesh_bounds := mesh_instance.get_aabb().transformed(relative_transform)
		model_bounds = mesh_bounds if not has_bounds else model_bounds.merge(mesh_bounds)
		has_bounds = true
	if not has_bounds or model_bounds.size.is_zero_approx():
		return null

	var body := StaticBody3D.new()
	body.name = collider_name
	body.position = model_bounds.position + model_bounds.size * 0.5
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	collision.name = collider_name + "Shape"
	var shape := BoxShape3D.new()
	shape.size = model_bounds.size * clampf(fill_ratio, 0.1, 1.0)
	collision.shape = shape
	body.add_child(collision)
	model_root.add_child(body)
	return body
