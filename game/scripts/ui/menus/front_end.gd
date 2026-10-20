## Owns the front-end journey: BOOT -> LOADING -> CINEMATIC -> CHAPTER ->
## DASHBOARD -> HERO -> WEAPON -> WORLD -> PRELOAD -> gameplay.
##
## This is the only place that knows the order. A stage asks for the next one by
## name and FrontEnd decides whether that is legal, which is what keeps the
## onboarding honest: the cinematic is skipped on a second launch because
## *this* object reads `intro_seen` off the profile, not because each screen
## remembers whether it played.
##
## Nothing here fakes progress. BOOT shows an indeterminate bar because a
## ConfigFile read reports no progress; LOADING and PRELOAD show a percentage
## because `ResourceLoader` reports one.
class_name FrontEnd
extends Control

const GAMEPLAY_SCENE := "res://scenes/main.tscn"

const STAGE_SCENES := {
	&"BOOT": preload("res://scenes/ui/menus/stage_boot.tscn"),
	&"LOADING": preload("res://scenes/ui/menus/stage_loading.tscn"),
	&"CINEMATIC": preload("res://scenes/ui/menus/stage_cinematic.tscn"),
	&"CHAPTER": preload("res://scenes/ui/menus/stage_chapter.tscn"),
	&"DASHBOARD": preload("res://scenes/ui/menus/stage_dashboard.tscn"),
	&"HERO": preload("res://scenes/ui/menus/stage_hero_select.tscn"),
	&"WEAPON": preload("res://scenes/ui/menus/stage_weapon_select.tscn"),
	&"WORLD": preload("res://scenes/ui/menus/stage_world_select.tscn"),
	&"PRELOAD": preload("res://scenes/ui/menus/stage_preload.tscn"),
}

## Where BACK / Escape goes. Stages not listed are terminal within the journey
## and ignore the key.
const BACK_TARGET := {
	&"HERO": &"DASHBOARD",
	&"WEAPON": &"HERO",
	&"WORLD": &"WEAPON",
	&"PRELOAD": &"WORLD",
}

## Read-only view of the active stage, for tests and for QA logging.
var current_stage_name := StringName()

var _stages: Dictionary = {}
var _current: MenuStage = null
var _current_name := StringName()

@onready var progression_service: ProgressionService = $ProgressionService
@onready var stage_host: Control = $StageHost


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	for key in STAGE_SCENES:
		var stage: MenuStage = (STAGE_SCENES[key] as PackedScene).instantiate()
		stage.name = str(key)
		stage.front_end = self
		stage.set_anchors_preset(Control.PRESET_FULL_RECT)
		stage.visible = false
		stage.completed.connect(_on_stage_completed.bind(key))
		stage_host.add_child(stage)
		# Entering the tree turns processing ON for a node whose script declares
		# `_process`, even though nothing called set_process(true) -- measured in
		# this build: a bare Control reports is_processing() false after new(),
		# true immediately after add_child(). Left alone every stage ticks from
		# the moment the front end boots, and the cinematic runs to completion
		# before it is ever shown. So the opt-out has to come *after* add_child,
		# and stages opt back in from enter().
		stage.set_process(false)
		stage.set_physics_process(false)
		_stages[key] = stage
	progression_service.profile_changed.connect(_on_profile_changed)
	_enter(&"BOOT", {})


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and BACK_TARGET.has(_current_name):
		get_viewport().set_input_as_handled()
		_enter(BACK_TARGET[_current_name], {})


## The only legal way to change stage. Test hooks call this directly.
func go_to(stage_name: StringName, stage_payload: Dictionary = {}) -> void:
	if not STAGE_SCENES.has(stage_name):
		push_error("FrontEnd: unknown stage '%s'." % stage_name)
		return
	_enter(stage_name, stage_payload)


## Where the front-end art load leads: the cinematic on a first launch, the
## dashboard once it has been seen. Resolved here rather than in BOOT so the
## "play the intro once" rule lives in exactly one place.
func stage_after_loading() -> StringName:
	return &"DASHBOARD" if progression_service.intro_seen else &"CINEMATIC"


func start_gameplay() -> void:
	var scene := load(GAMEPLAY_SCENE) as PackedScene
	if scene == null:
		push_error("FrontEnd: the gameplay scene is missing: " + GAMEPLAY_SCENE)
		return
	var error := get_tree().change_scene_to_packed(scene)
	if error != OK:
		push_error("FrontEnd: could not change scene (%d)." % error)


func _enter(stage_name: StringName, stage_payload: Dictionary) -> void:
	if is_instance_valid(_current):
		_current.exit()
		_current.visible = false
	var stage: MenuStage = _stages.get(stage_name)
	if stage == null:
		push_error("FrontEnd: stage '%s' was never instantiated." % stage_name)
		return
	_current = stage
	_current_name = stage_name
	current_stage_name = stage_name
	stage.payload = stage_payload
	stage.visible = true
	stage.enter(stage_payload)
	print("FrontEnd: stage %s" % stage_name)


func _on_stage_completed(
	next_stage: StringName, stage_payload: Dictionary, from_stage: StringName
) -> void:
	# The cinematic plays once. Skipping it counts as seeing it: being dropped
	# straight into the dashboard is the reward the skip button is offering.
	if from_stage == &"CINEMATIC":
		progression_service.mark_intro_seen()
	if not STAGE_SCENES.has(next_stage):
		push_error("FrontEnd: stage '%s' asked for unknown stage '%s'." % [from_stage, next_stage])
		return
	_enter(next_stage, stage_payload)


func _on_profile_changed() -> void:
	# The dashboard and the selection screens read the profile when they are
	# entered, so this only has to cover the case where a purchase or an unlock
	# lands while a screen is already open (the in-dashboard armory).
	if is_instance_valid(_current) and _current.has_method("refresh_profile"):
		_current.refresh_profile()
