extends MultiplayerSynchronizer

class_name InputController

@export var move_direction: Vector2 = Vector2.ZERO
@export var jump_input: bool = false
@export var cast_mask: int = 0
# cursor_world_pos with NaNs means client's cursor doesn't
# pointing to anything
@export var cursor_world_pos: Vector3 = Vector3(NAN, NAN, NAN)
## Camera is reference for calculating cursor_world_pos
@export var camera: Camera3D
@export var cursor_raycast: RayCast3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var peer_id := owner.name.to_int()
	set_multiplayer_authority(peer_id, false)
	set_visibility_for(1, true)


func _process(_delta: float) -> void:
	if multiplayer.is_server():
		return

	if is_multiplayer_authority():
		var new_move_direction: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

		if camera:
			new_move_direction = new_move_direction.rotated(-camera.global_rotation.y)

		if new_move_direction != move_direction:
			move_direction = new_move_direction

		var new_jump_input: bool = Input.is_action_pressed("ui_accept")
		if new_jump_input != jump_input:
			jump_input = new_jump_input

		var new_cast_mask: int = 0
		if Input.is_action_pressed(&"cast_1"):
			new_cast_mask |= 1 << 0
		if Input.is_action_pressed(&"cast_2"):
			new_cast_mask |= 1 << 1
		if Input.is_action_pressed(&"cast_3"):
			new_cast_mask |= 1 << 2
		if Input.is_action_pressed(&"cast_4"):
			new_cast_mask |= 1 << 3
		if new_cast_mask != cast_mask:
			cast_mask = new_cast_mask

		if camera:
			var mouse_dir := camera.project_ray_normal(get_viewport().get_mouse_position())
			cursor_raycast.global_position = camera.global_position
			cursor_raycast.target_position = cursor_raycast.global_position + mouse_dir * 1000.0
			cursor_raycast.force_raycast_update()

			if not cursor_raycast.is_colliding():
				cursor_world_pos = Vector3(NAN, NAN, NAN)
			else:
				cursor_world_pos = cursor_raycast.get_collision_point()
