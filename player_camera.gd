extends Camera3D

@export var move_speed: float = 20.0
@export var fast_move_speed: float = 40.0
@export var mouse_sensitivity: float = 0.003
@export var zoom_speed: float = 5.0
@export var min_zoom: float = 5.0
@export var max_zoom: float = 100.0

var _mouse_captured: bool = false
var _rotation_x: float = -30.0
var _rotation_y: float = 0.0

func _ready() -> void:
	_rotation_x = rotation_degrees.x
	_rotation_y = rotation_degrees.y

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				_mouse_captured = true
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				_mouse_captured = false
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			position += -global_transform.basis.z * zoom_speed
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			position += global_transform.basis.z * zoom_speed

	if event is InputEventMouseMotion and _mouse_captured:
		_rotation_y -= event.relative.x * mouse_sensitivity * 100
		_rotation_x -= event.relative.y * mouse_sensitivity * 100
		_rotation_x = clamp(_rotation_x, -89.0, 89.0)
		rotation_degrees = Vector3(_rotation_x, _rotation_y, 0)

func _process(delta: float) -> void:
	var input_dir := Vector3.ZERO

	if Input.is_action_pressed("move_forward"):
		input_dir.z -= 1
	if Input.is_action_pressed("move_backward"):
		input_dir.z += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1
	if Input.is_action_pressed("move_up"):
		input_dir.y += 1
	if Input.is_action_pressed("move_down"):
		input_dir.y -= 1

	input_dir = input_dir.normalized()

	var current_speed := fast_move_speed if Input.is_key_pressed(KEY_SHIFT) else move_speed

	var move_dir := global_transform.basis * input_dir
	position += move_dir * current_speed * delta

	if position.y < 1.0:
		position.y = 1.0
