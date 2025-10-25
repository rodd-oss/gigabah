class_name CameraController
extends Node

@export_group("Links")
@export var camera: Camera3D
@export var view_target: Node3D

@export_group("Behaviour")
@export var distance: float = 10.0
## In degrees
@export var pitch: float = 60.0
## In degrees
@export var yaw: float = 0.0
## TODO: for now rotation feels weird with damping < 1.0
@export_range(0.0, 1.0, 0.0001) var catchup_damping: float = 0.999

@export_group("Input")
@export var mouse_rotating_multiplier := 10.0
## Degrees per second
@export var actions_rotating_speed := 100.0

var _local_client := true
var _mouse_rotating_cam := false
var _mouse_delta := Vector2.ZERO
var _mouse_prev_mode: Input.MouseMode
var _mouse_prev_pos := Vector2.ZERO


func _ready() -> void:
	var cl := owner as NetworkClient
	if cl and cl.name.to_int() != multiplayer.get_unique_id():
		_local_client = false
		set_process_unhandled_input(false)


func _process(delta: float) -> void:
	if not camera or not view_target:
		return

	var local_target_campos := Vector3.BACK
	local_target_campos *= Quaternion.from_euler(Vector3(deg_to_rad(pitch), 0.0, 0.0))
	local_target_campos *= Quaternion.from_euler(Vector3(0.0, deg_to_rad(yaw), 0.0))
	local_target_campos *= distance

	var current_viewpos := camera.global_position - local_target_campos

	camera.global_position = current_viewpos.lerp(view_target.global_position, 1.0 - ((1.0 - catchup_damping) ** delta))
	camera.global_position += local_target_campos
	camera.global_basis = Basis.looking_at(
		current_viewpos - camera.global_position,
		Quaternion.from_euler(view_target.global_rotation) * Vector3.UP,
	)

	if _local_client:
		_handle_input(delta)


func _unhandled_input(event: InputEvent) -> void:
	match event:
		_ when event.is_action(&"mouse_camera_rotation") and not event.is_echo():
			if _mouse_rotating_cam != event.is_pressed():
				if not _mouse_rotating_cam:
					# set mouse captured and remember previous capture mode
					# and mouse position because position after releasing
					# mouse capture become in middle of viewport
					_mouse_prev_pos = get_viewport().get_mouse_position()
					_mouse_prev_mode = Input.mouse_mode
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
					_mouse_delta = Vector2.ZERO
				elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
					# restore mouse position and mode
					Input.mouse_mode = _mouse_prev_mode
					Input.warp_mouse(_mouse_prev_pos)

			_mouse_rotating_cam = event.is_pressed()
		_ when event is InputEventMouseMotion:
			var mouse_motion := event as InputEventMouseMotion
			_mouse_delta += mouse_motion.relative
		_:
			return

	get_viewport().set_input_as_handled()


func _handle_input(delta: float) -> void:
	var cam_rot := 0.0

	if _mouse_rotating_cam:
		cam_rot += _mouse_delta.x * mouse_rotating_multiplier
		_mouse_delta = Vector2.ZERO

	cam_rot += Input.get_axis(&"camera_rotation_cw", &"camera_rotation_ccw") * actions_rotating_speed

	yaw += cam_rot * delta
