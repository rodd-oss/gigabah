extends Node

var peer: ENetMultiplayerPeer
const ADDRESS: String = "gigabuh.d.roddtech.ru"
const PORT: int = 25445


func _ready() -> void:
	if OS.has_feature("dedicated_server"):
		start_server()
	elif OS.has_feature("client"):
		start_client(ADDRESS)
	else:
		start_client("127.0.0.1")


## Start as server
func start_server() -> void:
	peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT)
	multiplayer.multiplayer_peer = peer
	print("Server started on port %d" % PORT)


## Start as client
func start_client(address: String) -> void:
	peer = ENetMultiplayerPeer.new()
	peer.create_client(address, PORT)
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	print("Connecting to %s:%d..." % [address, PORT])


## Client connection handlers
func _on_connected_to_server() -> void:
	print("Connected to server.")


func _on_connection_failed() -> void:
	print("Failed to connect to server.")


func _on_server_disconnected() -> void:
	print("Disconnected from server.")
