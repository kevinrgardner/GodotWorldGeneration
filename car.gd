extends CharacterBody3D

@export var drive_speed: float = 8.0
@export var arrival_threshold: float = 1.0

var _nav_agent: NavigationAgent3D
var _rng: RandomNumberGenerator
var _initialized: bool = false

func _ready() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()

	# Get navigation agent (added by world generator)
	_nav_agent = get_node_or_null("NavigationAgent3D")
	if _nav_agent == null:
		push_warning("Car: No NavigationAgent3D found")
		return

	# Wait for navigation to be ready
	await get_tree().physics_frame
	await get_tree().physics_frame
	_initialized = true
	_pick_new_target()

func _physics_process(delta: float) -> void:
	if not _initialized or _nav_agent == null:
		return

	if _nav_agent.is_navigation_finished():
		_pick_new_target()
		return

	var current_pos := global_position
	var next_pos := _nav_agent.get_next_path_position()

	var direction := (next_pos - current_pos).normalized()
	direction.y = 0  # Keep movement horizontal

	# Rotate car to face movement direction
	# Car body is oriented with length along X, so offset by -PI/2
	if direction.length_squared() > 0.01:
		var target_rotation := atan2(direction.x, direction.z) - PI / 2.0
		rotation.y = lerp_angle(rotation.y, target_rotation, 5.0 * delta)

		velocity = direction * drive_speed
		move_and_slide()

func _pick_new_target() -> void:
	if _nav_agent == null:
		return

	# Get the navigation map for roads (layer 2)
	var maps := NavigationServer3D.get_maps()
	if maps.size() < 2:
		# Fallback to first map if only one exists
		if maps.size() > 0:
			_pick_target_on_map(maps[0])
		return

	_pick_target_on_map(maps[1])

func _pick_target_on_map(nav_map: RID) -> void:
	if not nav_map.is_valid():
		return

	# Pick a random offset from current position
	var random_offset := Vector3(
		_rng.randf_range(-80.0, 80.0),
		0,
		_rng.randf_range(-80.0, 80.0)
	)

	var target_pos := global_position + random_offset

	# Find closest point on nav mesh (road layer)
	var closest_point := NavigationServer3D.map_get_closest_point(nav_map, target_pos)

	_nav_agent.target_position = closest_point
