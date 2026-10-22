class_name WorldSelection
extends RefCounted

## Which theatre the launcher selected, resolved in one place.
##
## Both worlds are instanced by `main.tscn`, and each builds only when this says
## so — otherwise the one the player did not choose puts its walls through the
## other's gate. Getting that wrong is not hypothetical: the first version asked
## `Engine.get_singleton("ProgressionService")`, which returns null for an
## autoload, and every caller defaulted to "build it".
##
## Resolved in this order:
##
##   1. `override_id` — set by a headless test before it instantiates the scene.
##      A `--script` smoke test has no autoloads at all, so the service below does
##      not exist there and a test that wanted the station could not select it.
##   2. the `ProgressionService` autoload, i.e. what the player picked on the
##      WORLD screen and the profile remembered.
##   3. empty, which the worlds read as "the default theatre".
static var override_id: StringName = &""


static func selected() -> StringName:
	if override_id != &"":
		return override_id
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return &""
	var service := tree.root.get_node_or_null("ProgressionService")
	if service == null:
		return &""
	return StringName(String(service.get("selected_world_id")))


## Test hook. Returns the previous override so a test can restore it.
static func override_selection(world_id: StringName) -> StringName:
	var previous := override_id
	override_id = world_id
	return previous
