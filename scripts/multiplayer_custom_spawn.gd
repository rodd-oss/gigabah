class_name MultiplayerCustomSpawn
extends Node

const META_CUSTOM_SPAWN_INSTANCE_ID = &"multiplayer_custom_spawn_instid"

@export var spawn_target: NodePath = ^"."
@export var spawn_function: Callable # (scene_path: String, data: Variant) -> Node

var _spawn_target: Node


static func try_custom_spawn(spawn_parent: Node, create_node: Callable, data: Variant) -> Node:
	if not is_instance_valid(spawn_parent):
		return null

	var meta_instid: Variant = spawn_parent.get_meta(META_CUSTOM_SPAWN_INSTANCE_ID, false)
	if meta_instid is not int:
		return null

	var custom_spawn_node := instance_from_id(meta_instid as int)
	if custom_spawn_node is not MultiplayerCustomSpawn:
		return null

	var custom_spawn := custom_spawn_node as MultiplayerCustomSpawn
	if not custom_spawn.spawn_function.is_valid():
		return null

	return custom_spawn.spawn_function.call(create_node, data)


func _ready() -> void:
	_spawn_target = get_node(spawn_target)
	if not _spawn_target:
		push_error("node spawn_target '%s' not found" % spawn_target)
		return

	_spawn_target.set_meta(META_CUSTOM_SPAWN_INSTANCE_ID, get_instance_id())


func _exit_tree() -> void:
	if is_instance_valid(_spawn_target):
		_spawn_target.remove_meta(META_CUSTOM_SPAWN_INSTANCE_ID)
