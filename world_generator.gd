extends Node3D

@export_group("Seed Settings")
@export var world_seed: int = 0
@export var use_random_seed: bool = true

@export_group("Grid Settings")
@export var grid_size: int = 5
@export var block_size: float = 30.0
@export var street_width: float = 8.0

@export_group("Sidewalk Settings")
@export var sidewalk_width: float = 1.5

@export_group("Building Settings")
@export var min_building_height: float = 5.0
@export var max_building_height: float = 25.0
@export var min_building_width: float = 4.0
@export var max_building_width: float = 10.0
@export var building_depth: float = 6.0
@export var building_spacing: float = 1.0
@export var setback_from_street: float = 1.0
@export_range(0.0, 1.0) var building_density: float = 0.9
@export var color_variation: float = 0.1

@export_group("People Settings")
@export var people_count: int = 50
@export var min_person_height: float = 1.6
@export var max_person_height: float = 2.0
@export var person_radius: float = 0.3
@export var person_speed: float = 1.5

@export_group("Car Settings")
@export var car_count: int = 20
@export var car_speed: float = 8.0

var _streets_node: Node3D
var _sidewalks_node: Node3D
var _buildings_node: Node3D
var _people_node: Node3D
var _cars_node: Node3D
var _nav_sidewalks: NavigationRegion3D
var _nav_roads: NavigationRegion3D
var _street_material: StandardMaterial3D
var _sidewalk_material: StandardMaterial3D
var _base_building_colors: Array = []
var _rng: RandomNumberGenerator
var _current_seed: int = 0

# Track geometry for nav mesh building
var _road_segments: Array = []
var _sidewalk_segments: Array = []

# Track placed building footprints (Rect2 in X-Z) to prevent overlaps
var _placed_buildings: Array = []

const PedestrianScript = preload("res://pedestrian.gd")
const CarScript = preload("res://car.gd")

func _ready() -> void:
	_streets_node = $Streets
	_sidewalks_node = $Sidewalks
	_buildings_node = $Buildings
	_people_node = $People
	_cars_node = $Cars
	_nav_sidewalks = $NavigationSidewalks
	_nav_roads = $NavigationRoads
	_rng = RandomNumberGenerator.new()
	_setup_base_colors()
	_generate_world_sync()
	# Spawn agents after a short delay for navigation to be ready
	call_deferred("_spawn_agents")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			use_random_seed = true
			regenerate()
		elif event.keycode == KEY_T:
			# Regenerate with same seed
			use_random_seed = false
			world_seed = _current_seed
			regenerate()

func _setup_base_colors() -> void:
	_base_building_colors = [
		Color(0.7, 0.7, 0.75),   # Light gray
		Color(0.5, 0.5, 0.55),   # Medium gray
		Color(0.6, 0.55, 0.5),   # Tan
		Color(0.55, 0.5, 0.45),  # Brown-gray
		Color(0.65, 0.6, 0.55),  # Beige
		Color(0.4, 0.42, 0.45),  # Dark gray-blue
		Color(0.72, 0.68, 0.65), # Warm white
		Color(0.45, 0.48, 0.52), # Steel blue
	]

func _initialize_seed() -> void:
	if use_random_seed:
		_rng.randomize()
		_current_seed = _rng.seed
	else:
		_current_seed = world_seed
		_rng.seed = world_seed
	print("World generated with seed: ", _current_seed)

func _setup_materials() -> void:
	_street_material = StandardMaterial3D.new()
	_street_material.albedo_color = Color(0.2, 0.2, 0.25, 1.0)

	_sidewalk_material = StandardMaterial3D.new()
	_sidewalk_material.albedo_color = Color(0.6, 0.6, 0.65, 1.0)

func _generate_world_sync() -> void:
	_initialize_seed()
	_setup_materials()
	_clear_world()
	_generate_streets()
	_generate_buildings()
	_build_navigation_meshes()

func _spawn_agents() -> void:
	_generate_people()
	_generate_cars()

func regenerate() -> void:
	_generate_world_sync()
	call_deferred("_spawn_agents")

func regenerate_with_seed(new_seed: int) -> void:
	use_random_seed = false
	world_seed = new_seed
	regenerate()

func get_current_seed() -> int:
	return _current_seed

func _get_varied_building_color() -> Color:
	var base_color: Color = _base_building_colors[_rng.randi() % _base_building_colors.size()]

	# Apply random variation to the color
	var h := base_color.h + _rng.randf_range(-color_variation, color_variation)
	var s := clampf(base_color.s + _rng.randf_range(-color_variation, color_variation), 0.0, 1.0)
	var v := clampf(base_color.v + _rng.randf_range(-color_variation * 0.5, color_variation * 0.5), 0.2, 1.0)

	return Color.from_hsv(wrapf(h, 0.0, 1.0), s, v)

func _clear_world() -> void:
	for child in _streets_node.get_children():
		child.queue_free()
	for child in _sidewalks_node.get_children():
		child.queue_free()
	for child in _buildings_node.get_children():
		child.queue_free()
	for child in _people_node.get_children():
		child.queue_free()
	for child in _cars_node.get_children():
		child.queue_free()

	_road_segments.clear()
	_sidewalk_segments.clear()
	_placed_buildings.clear()

func _generate_streets() -> void:
	var half_grid := grid_size / 2
	var total_size := grid_size * block_size
	var road_width := street_width - sidewalk_width * 2
	# Sidewalks should extend to meet the corner pieces at outer intersections
	var sidewalk_length := total_size + road_width

	# Generate horizontal streets (along X axis)
	for i in range(grid_size + 1):
		var z_pos := (i - half_grid) * block_size - block_size / 2

		# Road (center portion)
		_create_street_segment(
			Vector3(0, 0.01, z_pos),
			total_size,
			road_width,
			true
		)
		_road_segments.append({
			"pos": Vector3(0, 0.01, z_pos),
			"length": total_size,
			"width": road_width,
			"horizontal": true
		})

		# Sidewalks (both sides) - shortened to not extend past outer intersections
		var sidewalk_offset := (road_width + sidewalk_width) / 2.0
		_create_sidewalk_segment(
			Vector3(0, 0.05, z_pos - sidewalk_offset),
			sidewalk_length,
			sidewalk_width,
			true
		)
		_create_sidewalk_segment(
			Vector3(0, 0.05, z_pos + sidewalk_offset),
			sidewalk_length,
			sidewalk_width,
			true
		)
		_sidewalk_segments.append({
			"pos": Vector3(0, 0.05, z_pos - sidewalk_offset),
			"length": sidewalk_length,
			"width": sidewalk_width,
			"horizontal": true
		})
		_sidewalk_segments.append({
			"pos": Vector3(0, 0.05, z_pos + sidewalk_offset),
			"length": sidewalk_length,
			"width": sidewalk_width,
			"horizontal": true
		})

	# Generate vertical streets (along Z axis)
	for i in range(grid_size + 1):
		var x_pos := (i - half_grid) * block_size - block_size / 2

		# Road (center portion)
		_create_street_segment(
			Vector3(x_pos, 0.01, 0),
			total_size,
			road_width,
			false
		)
		_road_segments.append({
			"pos": Vector3(x_pos, 0.01, 0),
			"length": total_size,
			"width": road_width,
			"horizontal": false
		})

		# Sidewalks (both sides) - shortened to not extend past outer intersections
		var sidewalk_offset := (road_width + sidewalk_width) / 2.0
		_create_sidewalk_segment(
			Vector3(x_pos - sidewalk_offset, 0.05, 0),
			sidewalk_length,
			sidewalk_width,
			false
		)
		_create_sidewalk_segment(
			Vector3(x_pos + sidewalk_offset, 0.05, 0),
			sidewalk_length,
			sidewalk_width,
			false
		)
		_sidewalk_segments.append({
			"pos": Vector3(x_pos - sidewalk_offset, 0.05, 0),
			"length": sidewalk_length,
			"width": sidewalk_width,
			"horizontal": false
		})
		_sidewalk_segments.append({
			"pos": Vector3(x_pos + sidewalk_offset, 0.05, 0),
			"length": sidewalk_length,
			"width": sidewalk_width,
			"horizontal": false
		})

	# Generate intersections with corner sidewalk pieces
	for i in range(grid_size + 1):
		for j in range(grid_size + 1):
			var x_pos := (i - half_grid) * block_size - block_size / 2
			var z_pos := (j - half_grid) * block_size - block_size / 2
			_create_intersection(Vector3(x_pos, 0.02, z_pos), road_width)
			_road_segments.append({
				"pos": Vector3(x_pos, 0.02, z_pos),
				"length": road_width,
				"width": road_width,
				"horizontal": true,
				"is_intersection": true
			})

			# Add corner sidewalk pieces at each intersection
			var corner_offset := (road_width + sidewalk_width) / 2.0
			var corner_positions := [
				Vector3(x_pos - corner_offset, 0.05, z_pos - corner_offset),  # NW
				Vector3(x_pos + corner_offset, 0.05, z_pos - corner_offset),  # NE
				Vector3(x_pos - corner_offset, 0.05, z_pos + corner_offset),  # SW
				Vector3(x_pos + corner_offset, 0.05, z_pos + corner_offset),  # SE
			]
			for corner_pos in corner_positions:
				_create_sidewalk_corner(corner_pos, sidewalk_width)
				_sidewalk_segments.append({
					"pos": corner_pos,
					"length": sidewalk_width,
					"width": sidewalk_width,
					"horizontal": true
				})

func _create_street_segment(pos: Vector3, length: float, width: float, horizontal: bool) -> void:
	var mesh_instance := MeshInstance3D.new()
	var plane_mesh := PlaneMesh.new()

	if horizontal:
		plane_mesh.size = Vector2(length, width)
	else:
		plane_mesh.size = Vector2(width, length)

	mesh_instance.mesh = plane_mesh
	mesh_instance.material_override = _street_material
	mesh_instance.position = pos

	_streets_node.add_child(mesh_instance)

func _create_sidewalk_segment(pos: Vector3, length: float, width: float, horizontal: bool) -> void:
	var mesh_instance := MeshInstance3D.new()
	var plane_mesh := PlaneMesh.new()

	if horizontal:
		plane_mesh.size = Vector2(length, width)
	else:
		plane_mesh.size = Vector2(width, length)

	mesh_instance.mesh = plane_mesh
	mesh_instance.material_override = _sidewalk_material
	mesh_instance.position = pos

	_sidewalks_node.add_child(mesh_instance)

func _create_sidewalk_corner(pos: Vector3, size: float) -> void:
	var mesh_instance := MeshInstance3D.new()
	var plane_mesh := PlaneMesh.new()

	plane_mesh.size = Vector2(size, size)

	mesh_instance.mesh = plane_mesh
	mesh_instance.material_override = _sidewalk_material
	mesh_instance.position = pos

	_sidewalks_node.add_child(mesh_instance)

func _create_intersection(pos: Vector3, road_width: float) -> void:
	var mesh_instance := MeshInstance3D.new()
	var plane_mesh := PlaneMesh.new()

	plane_mesh.size = Vector2(road_width, road_width)

	mesh_instance.mesh = plane_mesh
	mesh_instance.material_override = _street_material
	mesh_instance.position = pos

	_streets_node.add_child(mesh_instance)

func _build_navigation_meshes() -> void:
	# Build sidewalk navigation mesh
	var sidewalk_nav_mesh := NavigationMesh.new()
	sidewalk_nav_mesh.agent_radius = 0.3
	sidewalk_nav_mesh.agent_height = 2.0

	var sidewalk_vertices := PackedVector3Array()
	var sidewalk_polygons: Array = []

	for seg in _sidewalk_segments:
		var base_idx := sidewalk_vertices.size()
		var half_len: float = seg.length / 2.0
		var half_wid: float = seg.width / 2.0
		var y := 0.05

		if seg.horizontal:
			sidewalk_vertices.append(seg.pos + Vector3(-half_len, y, -half_wid))
			sidewalk_vertices.append(seg.pos + Vector3(half_len, y, -half_wid))
			sidewalk_vertices.append(seg.pos + Vector3(half_len, y, half_wid))
			sidewalk_vertices.append(seg.pos + Vector3(-half_len, y, half_wid))
		else:
			sidewalk_vertices.append(seg.pos + Vector3(-half_wid, y, -half_len))
			sidewalk_vertices.append(seg.pos + Vector3(half_wid, y, -half_len))
			sidewalk_vertices.append(seg.pos + Vector3(half_wid, y, half_len))
			sidewalk_vertices.append(seg.pos + Vector3(-half_wid, y, half_len))

		var poly := PackedInt32Array([base_idx, base_idx + 1, base_idx + 2, base_idx + 3])
		sidewalk_polygons.append(poly)

	sidewalk_nav_mesh.vertices = sidewalk_vertices
	for poly in sidewalk_polygons:
		sidewalk_nav_mesh.add_polygon(poly)

	_nav_sidewalks.navigation_mesh = sidewalk_nav_mesh
	_nav_sidewalks.navigation_layers = 1

	# Build road navigation mesh
	var road_nav_mesh := NavigationMesh.new()
	road_nav_mesh.agent_radius = 1.0
	road_nav_mesh.agent_height = 1.5

	var road_vertices := PackedVector3Array()
	var road_polygons: Array = []

	for seg in _road_segments:
		var base_idx := road_vertices.size()
		var half_len: float = seg.length / 2.0
		var half_wid: float = seg.width / 2.0
		var y := 0.01

		if seg.get("is_intersection", false):
			# Square intersection
			road_vertices.append(seg.pos + Vector3(-half_len, y, -half_wid))
			road_vertices.append(seg.pos + Vector3(half_len, y, -half_wid))
			road_vertices.append(seg.pos + Vector3(half_len, y, half_wid))
			road_vertices.append(seg.pos + Vector3(-half_len, y, half_wid))
		elif seg.horizontal:
			road_vertices.append(seg.pos + Vector3(-half_len, y, -half_wid))
			road_vertices.append(seg.pos + Vector3(half_len, y, -half_wid))
			road_vertices.append(seg.pos + Vector3(half_len, y, half_wid))
			road_vertices.append(seg.pos + Vector3(-half_len, y, half_wid))
		else:
			road_vertices.append(seg.pos + Vector3(-half_wid, y, -half_len))
			road_vertices.append(seg.pos + Vector3(half_wid, y, -half_len))
			road_vertices.append(seg.pos + Vector3(half_wid, y, half_len))
			road_vertices.append(seg.pos + Vector3(-half_wid, y, half_len))

		var poly := PackedInt32Array([base_idx, base_idx + 1, base_idx + 2, base_idx + 3])
		road_polygons.append(poly)

	road_nav_mesh.vertices = road_vertices
	for poly in road_polygons:
		road_nav_mesh.add_polygon(poly)

	_nav_roads.navigation_mesh = road_nav_mesh
	_nav_roads.navigation_layers = 2

func _footprint_overlaps(center: Vector3, w: float, d: float) -> bool:
	var new_rect := Rect2(center.x - w / 2.0, center.z - d / 2.0, w, d)
	for existing in _placed_buildings:
		if new_rect.intersects(existing):
			return true
	return false

func _generate_buildings() -> void:
	var half_grid := grid_size / 2
	var usable_block_size := block_size - street_width

	# Iterate through each city block
	for block_x in range(grid_size):
		for block_z in range(grid_size):
			var block_center_x := (block_x - half_grid) * block_size
			var block_center_z := (block_z - half_grid) * block_size

			# Generate buildings along all four edges of the block
			_generate_buildings_along_edge(block_center_x, block_center_z, usable_block_size, 0)  # North
			_generate_buildings_along_edge(block_center_x, block_center_z, usable_block_size, 1)  # South
			_generate_buildings_along_edge(block_center_x, block_center_z, usable_block_size, 2)  # East
			_generate_buildings_along_edge(block_center_x, block_center_z, usable_block_size, 3)  # West

func _generate_buildings_along_edge(block_x: float, block_z: float, usable_size: float, edge: int) -> void:
	var half_usable := usable_size / 2.0
	var half_street := street_width / 2.0

	# Determine edge position and orientation
	var is_horizontal := edge < 2  # North/South edges run along X
	var edge_length := usable_size - building_depth * 2  # Leave room at corners

	var current_pos := -edge_length / 2.0

	while current_pos < edge_length / 2.0:
		var width := _rng.randf_range(min_building_width, max_building_width)

		# Check if building fits
		if current_pos + width > edge_length / 2.0:
			width = edge_length / 2.0 - current_pos
			if width < min_building_width:
				break

		# Density check - randomly skip some buildings
		var should_place := _rng.randf() < building_density

		if should_place:
			var height := _rng.randf_range(min_building_height, max_building_height)
			var depth := building_depth

			var building_pos := Vector3.ZERO

			match edge:
				0:  # North edge (negative Z)
					building_pos = Vector3(
						block_x + current_pos + width / 2.0,
						height / 2.0,
						block_z - half_usable + half_street + setback_from_street + depth / 2.0
					)
				1:  # South edge (positive Z)
					building_pos = Vector3(
						block_x + current_pos + width / 2.0,
						height / 2.0,
						block_z + half_usable - half_street - setback_from_street - depth / 2.0
					)
				2:  # East edge (positive X)
					building_pos = Vector3(
						block_x + half_usable - half_street - setback_from_street - depth / 2.0,
						height / 2.0,
						block_z + current_pos + width / 2.0
					)
				3:  # West edge (negative X)
					building_pos = Vector3(
						block_x - half_usable + half_street + setback_from_street + depth / 2.0,
						height / 2.0,
						block_z + current_pos + width / 2.0
					)

			# Swap width and depth for East/West edges
			var final_width := width if is_horizontal else depth
			var final_depth := depth if is_horizontal else width

			if not _footprint_overlaps(building_pos, final_width, final_depth):
				_create_building(building_pos, final_width, height, final_depth)
				_placed_buildings.append(Rect2(
					building_pos.x - final_width / 2.0,
					building_pos.z - final_depth / 2.0,
					final_width,
					final_depth
				))

		current_pos += width + building_spacing

func _create_building(pos: Vector3, width: float, height: float, depth: float) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()

	box_mesh.size = Vector3(width, height, depth)

	var material := StandardMaterial3D.new()
	material.albedo_color = _get_varied_building_color()

	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = material
	mesh_instance.position = pos
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	# Add collision for selection (layer 2 = selection only, no physical interaction)
	var static_body := StaticBody3D.new()
	static_body.collision_layer = 2  # Selection layer
	static_body.collision_mask = 0   # Don't collide with anything
	var collision_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(width, height, depth)
	collision_shape.shape = box_shape
	static_body.add_child(collision_shape)
	mesh_instance.add_child(static_body)

	# Mark as selectable
	mesh_instance.set_meta("selectable_type", "building")

	_buildings_node.add_child(mesh_instance)

func _generate_people() -> void:
	for i in range(people_count):
		var pos := _get_random_sidewalk_position()
		var height := _rng.randf_range(min_person_height, max_person_height)
		var color := _get_person_color()
		_create_pedestrian(pos, height, color)

func _get_random_sidewalk_position() -> Vector3:
	if _sidewalk_segments.is_empty():
		return Vector3.ZERO

	# Pick a random sidewalk segment
	var seg: Dictionary = _sidewalk_segments[_rng.randi() % _sidewalk_segments.size()]

	var half_len: float = seg.length / 2.0
	var pos_along := _rng.randf_range(-half_len + 1.0, half_len - 1.0)

	var result: Vector3
	if seg.horizontal:
		result = Vector3(seg.pos.x + pos_along, 0, seg.pos.z)
	else:
		result = Vector3(seg.pos.x, 0, seg.pos.z + pos_along)

	return result

func _create_pedestrian(pos: Vector3, height: float, color: Color) -> void:
	var pedestrian := CharacterBody3D.new()
	pedestrian.set_script(PedestrianScript)
	pedestrian.position = pos
	pedestrian.collision_layer = 2  # Selection layer
	pedestrian.collision_mask = 0   # Don't collide with anything

	# Create capsule mesh
	var capsule := CapsuleMesh.new()
	capsule.radius = person_radius
	capsule.height = height

	var material := StandardMaterial3D.new()
	material.albedo_color = color

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	mesh_instance.mesh = capsule
	mesh_instance.material_override = material
	mesh_instance.position.y = height / 2.0
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	pedestrian.add_child(mesh_instance)

	# Create collision shape for selection
	var collision_shape := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = person_radius
	capsule_shape.height = height
	collision_shape.shape = capsule_shape
	collision_shape.position.y = height / 2.0
	pedestrian.add_child(collision_shape)

	# Create navigation agent
	var nav_agent := NavigationAgent3D.new()
	nav_agent.name = "NavigationAgent3D"
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 0.5
	nav_agent.navigation_layers = 1  # Sidewalks
	pedestrian.add_child(nav_agent)

	pedestrian.move_speed = person_speed

	# Mark as selectable
	pedestrian.set_meta("selectable_type", "pedestrian")

	_people_node.add_child(pedestrian)

func _get_person_color() -> Color:
	# Varied skin tones and clothing colors
	var colors := [
		Color(0.85, 0.7, 0.6),    # Light skin
		Color(0.7, 0.55, 0.45),   # Medium skin
		Color(0.5, 0.35, 0.25),   # Dark skin
		Color(0.2, 0.3, 0.5),     # Blue clothing
		Color(0.5, 0.2, 0.2),     # Red clothing
		Color(0.2, 0.4, 0.2),     # Green clothing
		Color(0.3, 0.3, 0.3),     # Gray clothing
		Color(0.1, 0.1, 0.15),    # Dark clothing
	]
	return colors[_rng.randi() % colors.size()]

func _generate_cars() -> void:
	for i in range(car_count):
		var pos := _get_random_road_position()
		var color := _get_car_color()
		_create_car(pos, color)

func _get_random_road_position() -> Vector3:
	# Filter to non-intersection road segments
	var road_only: Array = []
	for seg in _road_segments:
		if not seg.get("is_intersection", false):
			road_only.append(seg)

	if road_only.is_empty():
		return Vector3.ZERO

	# Pick a random road segment
	var seg: Dictionary = road_only[_rng.randi() % road_only.size()]

	var half_len: float = seg.length / 2.0
	var pos_along := _rng.randf_range(-half_len + 5.0, half_len - 5.0)

	var result: Vector3
	if seg.horizontal:
		result = Vector3(seg.pos.x + pos_along, 0, seg.pos.z)
	else:
		result = Vector3(seg.pos.x, 0, seg.pos.z + pos_along)

	return result

func _get_car_color() -> Color:
	var colors := [
		Color(0.7, 0.1, 0.1),     # Red
		Color(0.1, 0.2, 0.5),     # Blue
		Color(0.9, 0.9, 0.9),     # White
		Color(0.1, 0.1, 0.1),     # Black
		Color(0.6, 0.6, 0.65),    # Silver
	]
	return colors[_rng.randi() % colors.size()]

func _create_car(pos: Vector3, body_color: Color) -> void:
	var car := CharacterBody3D.new()
	car.set_script(CarScript)
	car.position = pos
	car.collision_layer = 2  # Selection layer
	car.collision_mask = 0   # Don't collide with anything

	var body_size := Vector3(3.5, 1.0, 1.8)
	var wheel_radius := 0.35
	var wheel_height := 0.2

	# Create body mesh
	var body_box := BoxMesh.new()
	body_box.size = body_size

	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = body_color

	var body_mesh := MeshInstance3D.new()
	body_mesh.name = "BodyMesh"
	body_mesh.mesh = body_box
	body_mesh.material_override = body_material
	body_mesh.position.y = wheel_radius + body_size.y / 2.0
	body_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	car.add_child(body_mesh)

	# Create wheel material (dark gray)
	var wheel_material := StandardMaterial3D.new()
	wheel_material.albedo_color = Color(0.15, 0.15, 0.15)

	# Create 4 wheels
	var wheel_positions := [
		Vector3(body_size.x / 2.0 - 0.5, wheel_radius, body_size.z / 2.0 - 0.1),   # Front right
		Vector3(body_size.x / 2.0 - 0.5, wheel_radius, -body_size.z / 2.0 + 0.1),  # Front left
		Vector3(-body_size.x / 2.0 + 0.5, wheel_radius, body_size.z / 2.0 - 0.1),  # Rear right
		Vector3(-body_size.x / 2.0 + 0.5, wheel_radius, -body_size.z / 2.0 + 0.1), # Rear left
	]

	for wheel_pos in wheel_positions:
		var wheel_mesh := CylinderMesh.new()
		wheel_mesh.top_radius = wheel_radius
		wheel_mesh.bottom_radius = wheel_radius
		wheel_mesh.height = wheel_height

		var wheel_instance := MeshInstance3D.new()
		wheel_instance.mesh = wheel_mesh
		wheel_instance.material_override = wheel_material
		wheel_instance.position = wheel_pos
		wheel_instance.rotation.x = PI / 2.0  # Rotate to align wheels properly
		wheel_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		car.add_child(wheel_instance)

	# Create collision shape for selection
	var collision_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = body_size
	collision_shape.shape = box_shape
	collision_shape.position.y = wheel_radius + body_size.y / 2.0
	car.add_child(collision_shape)

	# Create navigation agent
	var nav_agent := NavigationAgent3D.new()
	nav_agent.name = "NavigationAgent3D"
	nav_agent.path_desired_distance = 1.0
	nav_agent.target_desired_distance = 1.0
	nav_agent.navigation_layers = 2  # Roads
	car.add_child(nav_agent)

	car.drive_speed = car_speed

	# Mark as selectable
	car.set_meta("selectable_type", "car")

	_cars_node.add_child(car)
