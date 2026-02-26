extends CharacterBody3D

@export var move_speed: float = 1.5
@export var arrival_threshold: float = 0.5
@export var pause_time_min: float = 1.0
@export var pause_time_max: float = 4.0

var _nav_agent: NavigationAgent3D
var _is_paused: bool = false
var _pause_timer: float = 0.0
var _rng: RandomNumberGenerator
var _initialized: bool = false

func _ready() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()

	# Get navigation agent (added by world generator)
	_nav_agent = get_node_or_null("NavigationAgent3D")
	if _nav_agent == null:
		push_warning("Pedestrian: No NavigationAgent3D found")
		return

	# Wait for navigation to be ready
	await get_tree().physics_frame
	await get_tree().physics_frame
	_initialized = true
	_pick_new_target()

func _physics_process(delta: float) -> void:
	if not _initialized or _nav_agent == null:
		return

	if _is_paused:
		_pause_timer -= delta
		if _pause_timer <= 0:
			_is_paused = false
			_pick_new_target()
		return

	if _nav_agent.is_navigation_finished():
		_start_pause()
		return

	var current_pos := global_position
	var next_pos := _nav_agent.get_next_path_position()

	var direction := (next_pos - current_pos).normalized()
	direction.y = 0  # Keep movement horizontal

	if direction.length_squared() > 0.001:
		velocity = direction * move_speed
		move_and_slide()

func _pick_new_target() -> void:
	if _nav_agent == null:
		return

	# Get the navigation map for sidewalks (layer 1)
	var nav_map := NavigationServer3D.get_maps()[0] if NavigationServer3D.get_maps().size() > 0 else RID()
	if not nav_map.is_valid():
		return

	# Pick a random offset from current position
	var random_offset := Vector3(
		_rng.randf_range(-50.0, 50.0),
		0,
		_rng.randf_range(-50.0, 50.0)
	)

	var target_pos := global_position + random_offset

	# Find closest point on nav mesh
	var closest_point := NavigationServer3D.map_get_closest_point(nav_map, target_pos)

	_nav_agent.target_position = closest_point

func _start_pause() -> void:
	_is_paused = true
	_pause_timer = _rng.randf_range(pause_time_min, pause_time_max)
