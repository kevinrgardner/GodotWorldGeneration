extends Node3D

var _camera: Camera3D
var _selected_object: Node3D = null
var _selection_indicator: MeshInstance3D
var _path_visualizer: MeshInstance3D
var _path_mesh: ImmediateMesh

func _ready() -> void:
	_camera = get_node("../PlayerCamera")
	_create_selection_indicator()
	_create_path_visualizer()

func _create_selection_indicator() -> void:
	_selection_indicator = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.8
	torus.outer_radius = 1.2
	torus.rings = 16
	torus.ring_segments = 32
	_selection_indicator.mesh = torus

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.8, 0.2, 0.8)
	material.emission_enabled = true
	material.emission = Color(0.2, 0.8, 0.2)
	material.emission_energy_multiplier = 0.5
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_selection_indicator.material_override = material
	_selection_indicator.visible = false
	add_child(_selection_indicator)

func _create_path_visualizer() -> void:
	_path_visualizer = MeshInstance3D.new()
	_path_mesh = ImmediateMesh.new()
	_path_visualizer.mesh = _path_mesh

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.5, 0.0, 0.9)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.5, 0.0)
	material.emission_energy_multiplier = 0.8
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_path_visualizer.material_override = material
	_path_visualizer.visible = false
	add_child(_path_visualizer)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_handle_click(event.position)

func _handle_click(screen_pos: Vector2) -> void:
	var from := _camera.project_ray_origin(screen_pos)
	var to := from + _camera.project_ray_normal(screen_pos) * 1000.0

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 2  # Only check selection layer

	var result := space_state.intersect_ray(query)

	if result:
		var collider = result.collider
		# Find the parent entity (CharacterBody3D for people/cars, or the building itself)
		var entity = _find_selectable_parent(collider)
		if entity:
			_select_object(entity)
		else:
			_deselect()
	else:
		_deselect()

func _find_selectable_parent(node: Node) -> Node3D:
	var current = node
	while current:
		if current.has_meta("selectable_type"):
			return current
		current = current.get_parent()
	return null

func _select_object(obj: Node3D) -> void:
	_selected_object = obj
	_update_selection_indicator()
	_update_path_visualization()

func _deselect() -> void:
	_selected_object = null
	_selection_indicator.visible = false
	_path_visualizer.visible = false

func _process(_delta: float) -> void:
	if _selected_object and is_instance_valid(_selected_object):
		_update_selection_indicator()
		_update_path_visualization()
	elif _selected_object:
		# Object was deleted (e.g., during regeneration)
		_deselect()

func _update_selection_indicator() -> void:
	if not _selected_object:
		_selection_indicator.visible = false
		return

	_selection_indicator.visible = true
	var entity_type: String = _selected_object.get_meta("selectable_type", "unknown")

	# Position and scale indicator based on entity type
	match entity_type:
		"building":
			var mesh: MeshInstance3D = _selected_object
			var box_mesh: BoxMesh = mesh.mesh
			var size: Vector3 = box_mesh.size
			var scale_factor := maxf(size.x, size.z) / 2.0 + 0.5
			_selection_indicator.scale = Vector3(scale_factor, 0.3, scale_factor)
			_selection_indicator.position = Vector3(
				_selected_object.position.x,
				0.1,
				_selected_object.position.z
			)
			_set_indicator_color(Color(0.2, 0.5, 0.8))  # Blue for buildings
		"pedestrian":
			_selection_indicator.scale = Vector3(0.8, 0.2, 0.8)
			_selection_indicator.position = Vector3(
				_selected_object.global_position.x,
				0.1,
				_selected_object.global_position.z
			)
			_set_indicator_color(Color(0.2, 0.8, 0.2))  # Green for pedestrians
		"car":
			_selection_indicator.scale = Vector3(1.5, 0.2, 1.5)
			_selection_indicator.position = Vector3(
				_selected_object.global_position.x,
				0.1,
				_selected_object.global_position.z
			)
			_set_indicator_color(Color(0.8, 0.2, 0.2))  # Red for cars

func _set_indicator_color(color: Color) -> void:
	var material: StandardMaterial3D = _selection_indicator.material_override
	material.albedo_color = Color(color.r, color.g, color.b, 0.8)
	material.emission = color

func _update_path_visualization() -> void:
	_path_mesh.clear_surfaces()

	if not _selected_object:
		_path_visualizer.visible = false
		return

	var entity_type: String = _selected_object.get_meta("selectable_type", "unknown")

	if entity_type != "pedestrian" and entity_type != "car":
		_path_visualizer.visible = false
		return

	# Get navigation agent
	var nav_agent: NavigationAgent3D = _selected_object.get_node_or_null("NavigationAgent3D")
	if not nav_agent:
		_path_visualizer.visible = false
		return

	var path := nav_agent.get_current_navigation_path()
	if path.size() < 2:
		_path_visualizer.visible = false
		return

	_path_visualizer.visible = true

	# Draw path as a line strip
	_path_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)

	for point in path:
		_path_mesh.surface_add_vertex(Vector3(point.x, 0.15, point.z))

	_path_mesh.surface_end()

	# Set path color based on entity type
	var material: StandardMaterial3D = _path_visualizer.material_override
	if entity_type == "pedestrian":
		material.albedo_color = Color(0.2, 1.0, 0.2, 0.9)
		material.emission = Color(0.2, 1.0, 0.2)
	else:  # car
		material.albedo_color = Color(1.0, 0.3, 0.3, 0.9)
		material.emission = Color(1.0, 0.3, 0.3)
