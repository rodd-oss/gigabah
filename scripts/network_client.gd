extends Node

class_name NetworkClient

@export var camera: Camera3D
@export var vision_area: NetworkVisionArea3D


func _enter_tree() -> void:
	if multiplayer.is_server():
		vision_area.vision_owner_peer_id = name.to_int()

	# Always set authority to server (ID 1)
	set_multiplayer_authority(1)
	if multiplayer.get_unique_id() == 1:
		# Server does not need to set camera
		return

	if name.to_int() == multiplayer.get_unique_id():
		camera.make_current()
