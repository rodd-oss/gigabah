extends Node

signal connectivity_phase_changed(phase: String) # offline | connecting | online

var peer: ENetMultiplayerPeer
const ADDRESS: String = "gigabuh.d.roddtech.ru"
const PORT: int = 25445

var _phase: String = "offline"

func _ready() -> void:
	# Dedicated server стартует сразу. Клиент ждёт кнопку.
	if OS.has_feature("dedicated_server"):
		start_server()
	else:
		_set_phase("offline")

## Start as server
func start_server() -> void:
	peer = ENetMultiplayerPeer.new()
	var err: int = peer.create_server(PORT)
	if err != OK:
		print("[NetworkManager] create_server error %d" % err)
		return
	multiplayer.multiplayer_peer = peer
	_set_phase("online")
	print("Server started on port %d" % PORT)

## Start as client
func start_client(address: String) -> void:
	peer = ENetMultiplayerPeer.new()
	var err: int = peer.create_client(address, PORT)
	if err != OK:
		print("[NetworkManager] create_client error %d" % err)
		_set_phase("offline")
		return
	multiplayer.multiplayer_peer = peer
	_set_phase("connecting")
	multiplayer.connected_to_server.connect(_on_connected_to_server, CONNECT_ONE_SHOT)
	multiplayer.connection_failed.connect(_on_connection_failed, CONNECT_ONE_SHOT)
	multiplayer.server_disconnected.connect(_on_server_disconnected, CONNECT_ONE_SHOT)
	print("Connecting to %s:%d..." % [address, PORT])

## Client connection handlers
func _on_connected_to_server() -> void:
	_set_phase("online")
	print("Connected to server.")

func _on_connection_failed() -> void:
	_set_phase("offline")
	print("Failed to connect to server.")

func _on_server_disconnected() -> void:
	print("Disconnected from server.")
	_set_phase("offline")
	multiplayer.multiplayer_peer = null
	peer = null

func request_client_connect(address: String = ADDRESS) -> void:
	if _phase != "offline":
		print("[NetworkManager] Ignoring connect request in phase %s" % _phase)
		return
	start_client(address)

func get_current_phase() -> String:
	return _phase

func _set_phase(p: String) -> void:
	if _phase == p:
		return
	_phase = p
	emit_signal("connectivity_phase_changed", _phase)