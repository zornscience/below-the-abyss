class_name AmbientFishSchool
extends Node2D
## One acoustic receiver and one draw batch per bounded, non-colliding school.
var configuration: FishSchoolProfile
var school_id: StringName
var model: FishSchoolState = FishSchoolState.new()
var receiver: AcousticReceiver
var _game: ShelfPrototype
var _batch: MultiMeshInstance2D
var _redraw_clock: float = 0.0
var _habitat_clear: bool = false
var _checked: bool = false
var _swim: ShaderMaterial
var _swim_phase: float = 0.0

func setup(game: ShelfPrototype) -> Error:
	_game = game
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if not PointOfInterest.valid_id(school_id) or model.configure(configuration)!=OK: return ERR_INVALID_PARAMETER
	_batch = MultiMeshInstance2D.new()
	_batch.multimesh = MultiMesh.new()
	_batch.multimesh.transform_format = MultiMesh.TRANSFORM_2D
	_batch.multimesh.use_custom_data = true
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(48,48)
	_batch.multimesh.mesh = quad
	_batch.multimesh.instance_count = configuration.population
	_batch.texture = configuration.sprite_sheet
	_swim = ShaderMaterial.new()
	_swim.shader = preload("res://assets/shaders/fauna_swim.gdshader")
	_swim.set_shader_parameter("atlas_input",false)
	_swim.set_shader_parameter("cell",Vector4(configuration.species/3.0,0,1.0/3.0,1))
	_batch.material = _swim
	for index: int in range(configuration.population): _batch.multimesh.set_instance_custom_data(index,Color(fmod(index*0.381966,1.0),0,0,0))
	_batch.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_batch)
	receiver = AcousticReceiver.new()
	receiver.receiver_id = StringName("school/"+String(school_id))
	receiver.profile = AcousticReceiverProfile.new()
	receiver.profile.accepted_event_types = [&"active_sonar",&"explosion"]
	receiver.profile.maximum_range_units = configuration.hearing_range
	receiver.enabled = false
	add_child(receiver)
	receiver.event_received.connect(_received)
	var result: Error = receiver.bind_bus(game.get_node("AcousticBus") as AcousticBus)
	game.submarine.simulation_enabled_changed.connect(_simulation)
	if game.saves!=null: game.saves.checkpoint_restored.connect(reset_session)
	_update_batch()
	return result

func _received(event: AcousticEvent,_strength: float,_distance: float) -> void:
	model.hear(event,to_local(event.origin))

func _simulation(enabled: bool) -> void:
	receiver.enabled = enabled and _game.chapter.active

func reset_session() -> void:
	model.reset()
	_checked = false
	_update_batch()

func _physics_process(delta: float) -> void:
	if _game==null: return
	var active: bool = _game.chapter.active and _game.submarine.is_physics_processing()
	receiver.enabled = active
	visible = _game.chapter.active
	if not active: return
	if not _checked:
		var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = configuration.habitat.size
		query.shape = shape
		query.transform = Transform2D(0,to_global(configuration.habitat.get_center()))
		query.collision_mask = 1
		_habitat_clear = get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()
		_checked = true
	_batch.visible = _habitat_clear
	if not _habitat_clear or global_position.distance_to(_game.submarine.global_position)>1800: return
	model.react_to_vessel(to_local(_game.submarine.global_position))
	model.advance(delta)
	_swim_phase = fmod(_swim_phase+delta*4.0,TAU*100)
	_redraw_clock += delta
	if _redraw_clock>=0.05:
		_redraw_clock = fmod(_redraw_clock,0.05)
		_update_batch()

func _update_batch() -> void:
	if _batch==null: return
	var reduced: bool = _game.settings.snapshot().accessibility.reduced_motion
	_swim.set_shader_parameter("phase",_swim_phase)
	_swim.set_shader_parameter("amount",0.0 if reduced else 1.0)
	for index: int in range(model.positions.size()):
		var facing: float = -1.0 if cos(model.headings[index])<0 else 1.0
		var angle: float = model.headings[index]-(PI if facing<0 else 0.0)
		_batch.multimesh.set_instance_transform_2d(index,Transform2D(0 if reduced else angle,Vector2(1 if reduced else facing,1),0,model._formation(index) if reduced else model.positions[index]))
