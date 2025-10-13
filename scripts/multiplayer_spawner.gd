extends MultiplayerSpawner

@export var player_scene: PackedScene

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print_debug("[MultiplayerSpawner] _ready() - Connecting signals")
	multiplayer.peer_connected.connect(spawn_player)
	multiplayer.peer_disconnected.connect(despawn_player)
	print_debug("[MultiplayerSpawner] Signals connected - ready to spawn/despawn players")

func spawn_player(id: int) -> void:
	"""Spawns a player node for the given peer ID (server-side only)."""
	print_debug("[MultiplayerSpawner] spawn_player(%d) called" % id)
	if !multiplayer.is_server():
		print_debug("[MultiplayerSpawner] Not server - ignoring spawn request")
		return
	if player_scene == null:
		print_debug("[MultiplayerSpawner] ERROR: player_scene is null")
		return
	var player: Node = player_scene.instantiate()
	player.name = str(id)
	player.set_multiplayer_authority(1)
	player.position.x = randf_range(-5, 5)
	player.position.y = 0
	player.position.z = randf_range(-5, 5)
	print("[MultiplayerSpawner] Spawning player %d at position %s" % [id, player.position])
	get_node(spawn_path).call_deferred("add_child", player)

func despawn_player(id: int) -> void:
	"""Removes the player node for the given peer ID."""
	print_debug("[MultiplayerSpawner] despawn_player(%d) called" % id)
	if !multiplayer.is_server():
		print_debug("[MultiplayerSpawner] Not server - ignoring despawn request")
		return
	var player: Node = get_node(spawn_path).get_node_or_null(str(id))
	if player:
		print("[MultiplayerSpawner] Despawning player %d" % id)
		player.queue_free()
	else:
		print_debug("[MultiplayerSpawner] Player %d not found for despawn" % id)
