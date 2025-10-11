extends Node

const REMOTE_ADDRESS: String = "gigabuh.d.roddtech.ru"
const LOCAL_ADDRESS: String = "127.0.0.1"
const PORT: int = 25445

var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()

func _ready() -> void:
	if OS.has_feature("dedicated_server"):
		start_server()
	elif OS.has_feature("client"):
		start_client(REMOTE_ADDRESS)
	else:
		start_client(LOCAL_ADDRESS)

## Start as server
func start_server() -> void:
	peer.create_server(PORT)
	multiplayer.multiplayer_peer = peer
	print("Server started on port %d" % PORT)

## Start as client
func start_client(address: String) -> void:
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
