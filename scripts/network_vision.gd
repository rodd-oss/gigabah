class_name NetworkVision
extends Node

@export var vision_radius: float = 3.0
@export var spawner: AdvancedMultiplayerSpawner
@export var vision_area: Area3D
@export var vision_owner_peer_id: int

func _enter_tree() -> void:
	if vision_area:
		vision_area.body_entered.connect(_on_body_entered)
		vision_area.body_exited.connect(_on_body_exited)

func _exit_tree() -> void:
	if vision_area:
		vision_area.body_entered.disconnect(_on_body_entered)
		vision_area.body_exited.disconnect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if !is_multiplayer_authority():
		return

	var node: Node = body
	if node and !node.scene_file_path.is_empty():
		spawner.set_visibility_for(vision_owner_peer_id, node, true)

func _on_body_exited(body: Node3D) -> void:
	if !is_multiplayer_authority():
		return

	var node: Node = body
	if node and !node.scene_file_path.is_empty():
		spawner.set_visibility_for(vision_owner_peer_id, node, false)
