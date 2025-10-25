class_name PlayerSpawner
extends AdvancedMultiplayerSpawner

@export var player_scene: PackedScene


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	multiplayer.peer_connected.connect(spawn_player)
	multiplayer.peer_disconnected.connect(despawn_player)


func spawn_player(id: int) -> void:
	"""Spawns a player node for the given peer ID, with server authority."""
	if !multiplayer.is_server():
		return
	var player: Node = player_scene.instantiate()
	player.name = str(id)
	player.set_multiplayer_authority(1) # Ensure server authority
	var hero: CharacterBody3D = player.get_node("Hero") as CharacterBody3D
	hero.position.x = randf_range(-5, 5)
	hero.position.y = 0
	hero.position.z = randf_range(-10, 0)
	get_node(spawn_path).call_deferred("add_child", player)

	var hp := hero.find_child("NetworkHp", true) as NetworkHP
	if hp:
		hp.health_depleted.connect(respawn_client.bind(player as NetworkClient))

	set_visibility_for(id, player, true)


func despawn_player(id: int) -> void:
	"""Removes the player node for the given peer ID."""
	if !multiplayer.is_server():
		return
	var player: Node = get_node(spawn_path).get_node(str(id))
	if player:
		player.queue_free()

func respawn_client(client: NetworkClient) -> void:
	var hero: CharacterBody3D = client.get_node("Hero") as CharacterBody3D

	hero.position.x = randf_range(-5, 5)
	hero.position.y = 0
	hero.position.z = randf_range(-10, 0)

	var hp := hero.find_child("NetworkHp", true) as NetworkHP
	if hp:
		hp.current_health = 50
