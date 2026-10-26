class_name MovementPrototype
extends Node
## BTA-010 test-scene orchestration and diagnostics, not a game-state service.

const INPUT_MENU: PackedScene = preload("res://scenes/ui/input_test_menu.tscn")

@export var settings_path: String = SettingsStore.DEFAULT_PATH
var settings: SettingsStore = SettingsStore.new()
var _menu: InputTestMenu
var _contact_time: float = 0.0

@onready var submarine: SubmarineController = $WorldRoot/PlayerSubmarine
@onready var settings_layer: CanvasLayer = $SettingsLayer
@onready var settings_backdrop: ColorRect = $SettingsLayer/Backdrop
@onready var diagnostics: Label = %Diagnostics


func _ready() -> void:
	_load_settings()
	submarine.collision_occurred.connect(_on_collision)


func _load_settings() -> void:
	var result: Error = settings.load_settings(settings_path)
	var document: Dictionary = settings.snapshot()
	InputBindings.apply(document["bindings"], float(document["deadzone"]))
	var message: Label = %SettingsStatus
	if result == OK:
		message.text = "Saved controls loaded."
	elif result == ERR_FILE_NOT_FOUND:
		message.text = "Default controls. Escape / P / Start: input settings."
	else:
		message.text = "Settings not loaded (%s); valid controls retained. File preserved." % error_string(result)


func _unhandled_input(event: InputEvent) -> void:
	if _menu == null and not event.is_echo() \
		and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		open_settings()
		get_viewport().set_input_as_handled()


func open_settings() -> void:
	if _menu != null:
		return
	submarine.velocity = Vector2.ZERO
	submarine.set_physics_process(false)
	_menu = INPUT_MENU.instantiate() as InputTestMenu
	_menu.settings_path = settings_path
	_menu.embedded = true
	_menu.close_requested.connect(close_settings)
	settings_backdrop.show()
	settings_layer.add_child(_menu)


func close_settings() -> void:
	if _menu == null:
		return
	_menu.queue_free()
	_menu = null
	settings_backdrop.hide()
	# Explicit Save is the existing settings contract. Closing discards unsaved
	# edits; failed loads preserve the prototype's previous valid settings.
	_load_settings()
	submarine.set_physics_process(true)


func _on_collision(_normal: Vector2, _approach_speed: float) -> void:
	_contact_time = 0.35


func _process(delta: float) -> void:
	_contact_time = maxf(0.0, _contact_time - delta)
	diagnostics.text = "Speed: %.0f px/s   |   %s" % [
		submarine.velocity.length(),
		"Wall contact — sliding, no damage" if _contact_time > 0.0 else "Free movement",
	]
