class_name NetworkVision
extends Node

@export var vision_radius: float = 3.0
@export var vision_area: Area3D
@export var vision_owner_peer_id: int

func _enter_tree() -> void:
	if vision_area:
		vision_area.body_entered.connect(_on_body_entered)
		vision_area.body_exited.connect(_on_body_exited)
		vision_area.area_entered.connect(_on_area_entered)
		vision_area.area_exited.connect(_on_area_exited)

func _exit_tree() -> void:
	if vision_area:
		vision_area.body_entered.disconnect(_on_body_entered)
		vision_area.body_exited.disconnect(_on_body_exited)
		vision_area.area_entered.disconnect(_on_area_entered)
		vision_area.area_exited.disconnect(_on_area_exited)

func _on_body_entered(body: Node3D) -> void:
	if !is_multiplayer_authority():
		return

	_try_set_vision_for(body, true)

func _on_body_exited(body: Node3D) -> void:
	if !is_multiplayer_authority():
		return
	
	_try_set_vision_for(body, false)

func _on_area_entered(area: Area3D) -> void:
	if !is_multiplayer_authority():
		return
	
	_try_set_vision_for(area, true)

func _on_area_exited(area: Area3D) -> void:
	if !is_multiplayer_authority():
		return
	
	_try_set_vision_for(area, false)

func _try_set_vision_for(node: Node, vision: bool) -> void:
	if !node:
		return

	if node.owner:
		AdvancedMultiplayerSpawner.set_visibility_for(vision_owner_peer_id, node.owner, vision)
	elif not node.scene_file_path.is_empty():
		AdvancedMultiplayerSpawner.set_visibility_for(vision_owner_peer_id, node, vision)
