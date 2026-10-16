@tool
extends RefCounted

const ASSET_DIRECTORY := "res://assets/world/kaykit_space_base_bits/gltf/"

static var _scene_templates: Dictionary = {}
static var _failed_asset_paths: Dictionary = {}


static func instantiate_model(model_name: String) -> Node3D:
	if model_name.is_empty() or model_name.contains("..") or model_name.contains("/"):
		push_warning("Rejected invalid external world asset name: " + model_name)
		return null
	var asset_path := ASSET_DIRECTORY + model_name + ".gltf"
	if not _scene_templates.has(asset_path):
		var loaded_template := _load_model_template(asset_path)
		if loaded_template == null:
			return null
		_scene_templates[asset_path] = loaded_template
	var template := _scene_templates[asset_path] as Node3D
	if not is_instance_valid(template):
		return null
	return template.duplicate() as Node3D


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


static func _load_model_template(asset_path: String) -> Node3D:
	if not FileAccess.file_exists(asset_path):
		if not _failed_asset_paths.has(asset_path):
			push_warning("External world asset not found: " + asset_path)
			_failed_asset_paths[asset_path] = true
		return null

	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var parse_error := document.append_from_file(asset_path, state)
	if parse_error != OK:
		if not _failed_asset_paths.has(asset_path):
			push_warning(
				"Could not load external world asset %s (error %d)." % [asset_path, parse_error]
			)
			_failed_asset_paths[asset_path] = true
		return null

	var generated_scene := document.generate_scene(state)
	if not generated_scene is Node3D:
		if not _failed_asset_paths.has(asset_path):
			push_warning("External world asset did not create a 3D scene: " + asset_path)
			_failed_asset_paths[asset_path] = true
		return null
	return generated_scene as Node3D
