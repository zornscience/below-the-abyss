class_name MovementPrototype
extends Node
## BTA-010 test-scene orchestration and diagnostics, not a game-state service.

const INPUT_MENU: PackedScene = preload("res://scenes/ui/input_test_menu.tscn")

@export var settings_path: String = SettingsStore.DEFAULT_PATH
var settings: SettingsStore = SettingsStore.new()
var _menu: InputTestMenu
var _contact_time: float = 0.0
var _damage_feedback_time: float = 0.0
var _last_damage: String = ""

@onready var submarine: SubmarineController = $WorldRoot/PlayerSubmarine
@onready var settings_layer: CanvasLayer = $SettingsLayer
@onready var settings_backdrop: ColorRect = $SettingsLayer/Backdrop
@onready var diagnostics: Label = %Diagnostics
@onready var resource_panel: PrototypeResourcePanel = %ResourcePanel


func _ready() -> void:
	_load_settings()
	submarine.depth_region = $WorldRoot/CurrentRegion as DepthRegion
	submarine.damage_system.advance(
		0.0, submarine.depth_region.depth_at_world(submarine.global_position), submarine.hull_system)
	submarine.collision_occurred.connect(_on_collision)
	submarine.damage_system.pressure_damage_applied.connect(_on_pressure_damage)
	submarine.damage_system.collision_damage_applied.connect(_on_collision_damage)
	submarine.damage_system.warning_changed.connect(_on_depth_warning_changed)
	submarine.damage_system.maximum_depth_changed.connect(func(_rating: float) -> void: _refresh_depth_status())
	resource_panel.bind_sources(submarine.resource_system, submarine.hull_system)
	resource_panel.test_controls_focused.connect(_stop_for_resource_checks)
	resource_panel.test_requested.connect(_on_resource_test_requested)
	_refresh_depth_status()


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
	elif _menu == null and not resource_panel.has_test_focus() \
		and not event.is_echo() and event.is_action_pressed("interact"):
		resource_panel.focus_test_controls()
		get_viewport().set_input_as_handled()


func _stop_for_resource_checks() -> void:
	submarine.velocity = Vector2.ZERO
	submarine.set_physics_process(false)


func _on_resource_test_requested(kind: StringName) -> void:
	match kind:
		&"hull":
			submarine.hull_system.apply_damage(25.0, &"prototype_test")
		&"battery":
			submarine.resource_system.consume_battery(25.0)
		&"oxygen":
			submarine.resource_system.consume_oxygen(25.0)
		&"refill":
			submarine.hull_system.restore_hull(submarine.hull_system.max_hull)
			submarine.resource_system.restore_battery(submarine.resource_system.max_battery)
			submarine.resource_system.restore_oxygen(submarine.resource_system.max_oxygen)
		&"pilot":
			resource_panel.release_test_focus()
			if _menu == null:
				InputBindings.apply(settings.snapshot()["bindings"], float(settings.snapshot()["deadzone"]))
				submarine.set_physics_process(true)


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
	resource_panel.release_test_focus()
	submarine.set_physics_process(true)


func _on_collision(_normal: Vector2, _approach_speed: float) -> void:
	_contact_time = 0.35


func _on_pressure_damage(amount: float) -> void:
	_damage_feedback_time = 2.0
	_last_damage = "Pressure hull loss: %.2f" % amount


func _on_collision_damage(amount: float, approach_speed: float) -> void:
	_damage_feedback_time = 2.0
	_last_damage = "Impact hull loss: %.1f (normal approach %.0f px/s)" % [amount, approach_speed]


func _on_depth_warning_changed(_state: int) -> void:
	_refresh_depth_status()


func _process(delta: float) -> void:
	_contact_time = maxf(0.0, _contact_time - delta)
	_damage_feedback_time = maxf(0.0, _damage_feedback_time - delta)
	diagnostics.text = "Speed: %.0f px/s   |   %s" % [
		submarine.velocity.length(),
		"Wall contact — severe impacts damage hull" if _contact_time > 0.0 else "Free movement",
	]
	_refresh_depth_status()
	(%DamageFeedback as Label).text = _last_damage if _damage_feedback_time > 0.0 else "No game over or respawn in this prototype."


func _refresh_depth_status() -> void:
	var damage: SubmarineDamageSystem = submarine.damage_system
	var rating: String = "Depth %.1f m / safe operating limit %.1f m" % [damage.depth_m, damage.get_maximum_depth_m()]
	var warning: Label = %DepthStatus
	match damage.warning_state:
		SubmarineDamageSystem.WarningState.SAFE:
			warning.text = "SAFE — " + rating
			warning.modulate = Color.WHITE
		SubmarineDamageSystem.WarningState.APPROACHING:
			warning.text = "CAUTION — " + rating + ". Approaching limit; prepare to ascend."
			warning.modulate = Color(1.0, 0.85, 0.35)
		SubmarineDamageSystem.WarningState.EXCEEDED:
			var consequence: String = "HULL DAMAGE ACTIVE"
			if damage.pressure_damage_per_second == 0.0:
				consequence = "pressure damage disabled by profile"
			elif damage.grace_remaining_seconds > 0.0:
				consequence = "damage in %.1f s" % damage.grace_remaining_seconds
			warning.text = "DANGER — " + rating + ". " + consequence + " — ASCEND."
			warning.modulate = Color(1.0, 0.45, 0.4)
