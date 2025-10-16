## Advanced version of MultiplayerSpawner which allows control visibility
## of nodes. Nodes replicates only to those clients who allowed to see this
## node.
##
## TODO: currently changing authority in middle of lifetime not supported
## and can lead to undefined behaviour.
class_name AdvancedMultiplayerSpawner
extends Node

var spawn_function: Callable ## must be func(data: Variant) -> Node
@export var spawn_limit: int = 0
@export var spawn_path: NodePath = "."
@export var auto_spawnable_scenes: Array[PackedScene] = []
var _watching_node: Node
var _tracking_nodes: Dictionary[int, _NetworkNodeInfo] = {}

signal spawned(node: Node)
signal despawning(node: Node)

func add_spawnable_scene(path: String) -> void:
	auto_spawnable_scenes.append(load(path))

func clear_spawnable_scenes() -> void:
	auto_spawnable_scenes.clear()

func get_spawnable_scene(index: int) -> String:
	if index >= 0 && index < len(auto_spawnable_scenes):
		return auto_spawnable_scenes[index].resource_path
	return ""

func get_spawnable_count() -> int:
	return len(auto_spawnable_scenes)

func spawn(data: Variant = null) -> Node:
	if !is_multiplayer_authority():
		printerr("attempt to call spawn method by non authority")
		return null

	if !spawn_function:
		printerr("spawn_function must be set before calling spawn method")
		return null

	var node: Node = spawn_function.call(data)
	if !node:
		printerr("spawn_function doesn't returned node")
		return null

	var spawn_target: Node = get_node(spawn_path)
	if !spawn_target:
		printerr("spawn_path pointing to invalid node")
		return null

	spawn_target.add_child(node)

	var net_node: _NetworkNodeInfo = _NetworkNodeInfo.new(_alloc_network_id(node))
	_tracking_nodes[node.get_instance_id()] = net_node
	_on_start_tracking_node(node, net_node)

	return node

func is_visible_for(peer_id: int, node: Node) -> bool:
	if not is_multiplayer_authority():
		push_warning("non authority doesn't have visibility knowledge")
		return false

	# owner always see its own nodes
	if node.get_multiplayer_authority() == peer_id:
		return true

	var net_node: _NetworkNodeInfo = _tracking_nodes.get(node.get_instance_id())
	if !net_node:
		return false

	return peer_id in net_node.peers_vision

## Set visibility of node for specific peer.
## 
## Note: you can't disable visibility for node owner
func set_visibility_for(peer_id: int, node: Node, visibility: bool) -> void:
	if !is_multiplayer_authority():
		push_error("attempt to change network visibility by non authority")
		return
	if peer_id < 1:
		push_error("changing network visibility possibly only for clients")
		return
	if node.get_multiplayer_authority() == peer_id:
		push_error("attempt to change visibility for node authority")
		return

	var net_node: _NetworkNodeInfo = _tracking_nodes.get(node.get_instance_id())
	if !net_node:
		if !_try_get_auto_spawnable_scene(node):
			# TODO: would be better to change api and move set_visibility_for
			#       into singleton class which will know what spawner spawned
			#       this node
			push_error("attempt to change network visibility of node not spawned by this spawner")
			return

		if visibility:
			net_node = _NetworkNodeInfo.new(_alloc_network_id(node))
			net_node.peers_vision.push_back(peer_id)
			_tracking_nodes[node.get_instance_id()] = net_node
			_on_start_tracking_node(node, net_node)
			_on_peer_got_vision(node, net_node, peer_id)
	else:
		if visibility and peer_id not in net_node.peers_vision:
			net_node.peers_vision.append(peer_id)
			_on_peer_got_vision(node, net_node, peer_id)
		elif !visibility and peer_id in net_node.peers_vision:
			var idx: int = net_node.peers_vision.find(peer_id)
			if idx >= 0:
				_erase_replacing(net_node.peers_vision, idx)
			_on_peer_lost_vision(node, net_node, peer_id)

## Returns number of peers can see node, excluding owner
func get_peers_have_vision_count(node: Node) -> int:
	var net_node: _NetworkNodeInfo = _tracking_nodes.get(node.get_instance_id())
	if net_node:
		return net_node.peers_vision.size()
	return 0

## Get Nth peer id that can see node or -1 if index out of bounds
func get_peer_have_vision(node: Node, index: int) -> int:
	var net_node: _NetworkNodeInfo = _tracking_nodes.get(node.get_instance_id())
	if net_node:
		if index >= 0 && index < net_node.peers_vision.size():
			return net_node.peers_vision[index]

	return -1

func _enter_tree() -> void:
	if is_multiplayer_authority():
		_watching_node = get_node_or_null(spawn_path)
		if _watching_node:
			_watching_node.child_entered_tree.connect(_on_child_entered)
			_watching_node.child_exiting_tree.connect(_on_child_exiting)

		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _exit_tree() -> void:
	if is_multiplayer_authority():
		if _watching_node:
			_watching_node.child_entered_tree.connect(_on_child_entered)
			_watching_node.child_exiting_tree.connect(_on_child_exiting)

			_watching_node = null

		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)

func _on_peer_disconnected(peer_id: int) -> void:
	_iter_all_node_instance_ids_peer_see(peer_id, func(_node_id: int, net_node: _NetworkNodeInfo) -> void:
		var peer_vis_idx: int = net_node.peers_vision.find(peer_id)
		if peer_vis_idx >= 0:
			_erase_replacing(net_node.peers_vision, peer_vis_idx)
	)

func _on_child_entered(node: Node) -> void:
	var auto_spawn_scene: PackedScene = _try_get_auto_spawnable_scene(node)
	if !auto_spawn_scene:
		# not replicatable node or node that should be spawned manually
		# using spawn method
		return

	var net_node: _NetworkNodeInfo = _tracking_nodes.get(node.get_instance_id())
	if net_node:
		# node already tracking
		return

	net_node = _NetworkNodeInfo.new(_alloc_network_id(node))
	_tracking_nodes[node.get_instance_id()] = net_node
	_on_start_tracking_node(node, net_node)

func _on_child_exiting(node: Node) -> void:
	var net_node: _NetworkNodeInfo = _tracking_nodes.get(node.get_instance_id())
	if !net_node:
		return

	_on_end_tracking_node(node, net_node)

	for peer_id: int in net_node.peers_vision:
		_on_peer_lost_vision(node, net_node, peer_id)
	
	_release_network_id(node, net_node.network_id)
	_tracking_nodes.erase(node.get_instance_id())

func _on_start_tracking_node(node: Node, net_node: _NetworkNodeInfo) -> void:
	net_node.synchronizers.assign(
		node.find_children("", "MultiplayerSynchronizer", true, true),
	)

	for syncer: MultiplayerSynchronizer in net_node.synchronizers:
		syncer.set_visibility_for(0, false)

func _on_end_tracking_node(_node: Node, _net_node: _NetworkNodeInfo) -> void:
	pass

## called only on owner side
func _on_peer_got_vision(node: Node, net_node: _NetworkNodeInfo, peer_id: int) -> void:
	for syncer: MultiplayerSynchronizer in net_node.synchronizers:
		syncer.set_visibility_for(peer_id, true)

	var pos: Vector3 = Vector3.ZERO
	if node.is_inside_tree():
		var node3d: Node3D = node as Node3D
		if node3d:
			pos = node3d.global_position
		else:
			var node2d: Node2D = node as Node2D
			if node2d:
				pos = Vector3(node2d.global_position.x, node2d.global_position.y, 0)

	_rpc_spawn.rpc_id(peer_id, node.scene_file_path, node.name, pos, net_node.network_id, null)

## called only on owner side
## not called when peer disconnects (see _on_peer_disconnected)
func _on_peer_lost_vision(_node: Node, net_node: _NetworkNodeInfo, peer_id: int) -> void:
	for syncer: MultiplayerSynchronizer in net_node.synchronizers:
		syncer.set_visibility_for(peer_id, false)

	_rpc_despawn.rpc_id(peer_id, net_node.network_id)

func _try_get_auto_spawnable_scene(node: Node) -> PackedScene:
	for scene: PackedScene in auto_spawnable_scenes:
		if scene.resource_path == node.scene_file_path:
			return scene

	return null

func _find_node_id_by_network_id(network_id: int) -> int:
	for node_id: int in _tracking_nodes.keys():
		if _tracking_nodes[node_id].network_id == network_id:
			return node_id

	return 0

## callback: func(node_id: int, net_node: _NetworkNodeInfo)
func _iter_all_node_instance_ids_peer_see(peer_id: int, callback: Callable) -> void:
	for node_id: int in _tracking_nodes.keys():
		var net_node: _NetworkNodeInfo = _tracking_nodes[node_id]
		if peer_id in net_node.peers_vision:
			callback.call(node_id, net_node)

func _alloc_network_id(node: Node) -> int:
	return node.get_instance_id()

func _release_network_id(_node: Node, _network_id: int) -> void:
	pass

@rpc("reliable")
func _rpc_spawn(scene_path: String, node_name: String, pos: Vector3, network_id: int, data: Variant) -> void:
	var spawn_target: Node = get_node(spawn_path)
	if !spawn_target:
		push_error("spawn_path pointing to invalid node")
		return
	
	var existing_node: Node = spawn_target.find_child(node_name, false, true)
	if existing_node:
		push_error("authority sent rpc to spawn node with name that already occupied in spawn_path by %s" % existing_node)
		return

	var node: Node
	if data:
		node = spawn_function.call(data)
		if !node:
			printerr("spawn_function doesn't returned node")
			return
	else:
		node = (load(scene_path) as PackedScene).instantiate()

	node.name = node_name

	var net_node: _NetworkNodeInfo = _NetworkNodeInfo.new(network_id)
	_tracking_nodes[node.get_instance_id()] = net_node

	spawn_target.add_child(node)

	var node3d: Node3D = node as Node3D
	if node3d:
		node3d.global_position = pos
	else:
		var node2d: Node2D = node as Node2D
		if node2d:
			node2d.global_position = Vector2(pos.x, pos.y)

	spawned.emit(node)

@rpc("reliable")
func _rpc_despawn(network_id: int) -> void:
	var node_id: int = _find_node_id_by_network_id(network_id)
	if !is_instance_id_valid(node_id):
		printerr("authority sent despawn rpc with unknown node network_id")
		return

	_tracking_nodes.erase(node_id)
	var node: Node = instance_from_id(node_id)
	if !is_instance_valid(node):
		printerr("got despawn rpc but local node instance is invalid")
		return

	despawning.emit(node)
	node.queue_free()

func _erase_replacing(arr: Array, index: int) -> void:
	if index < 0 or index >= arr.size():
		return

	if arr.size() == 1:
		arr.clear()
		return

	var last_idx: int = arr.size() - 1
	if index < last_idx:
		arr[index] = arr[last_idx]
	arr.resize(last_idx)

class _NetworkNodeInfo:
	var network_id: int
	var peers_vision: Array[int] = []
	var synchronizers: Array[MultiplayerSynchronizer] = []

	func _init(net_id: int) -> void:
		self.network_id = net_id
