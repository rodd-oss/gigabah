extends Node

signal connectivity_phase_changed(phase: String) # "offline" | "connecting" | "online"
signal ping_updated(ms: int)

const PORT: int = 25445
const ADDRESS: String = "gigabuh.d.roddtech.ru"
const PING_INTERVAL: float = 5.0

var peer: ENetMultiplayerPeer
var _current_phase: String = "offline"
var _last_ping_sent: int = 0
var _ping_roundtrip_ms: int = -1
var _ping_timer: Timer

func _set_phase(phase: String) -> void:
	if _current_phase == phase:
		return
	_current_phase = phase
	emit_signal("connectivity_phase_changed", _current_phase)

func get_current_phase() -> String:
	return _current_phase

func get_last_ping_ms() -> int:
	return _ping_roundtrip_ms

func _ready() -> void:
	_set_phase("offline")
	if OS.has_feature("dedicated_server"):
		start_server()
	elif OS.has_feature("client"):
		start_client(ADDRESS)
	else:
		start_client("127.0.0.1")

## Start as server
func start_server() -> void:
	peer = ENetMultiplayerPeer.new()
	var err: int = peer.create_server(PORT)
	if err != OK:
		print("[NetworkManager] create_server error %d" % err)
		_set_phase("offline")
		return
	multiplayer.multiplayer_peer = peer
	_set_phase("online")
	print("Server started on port %d" % PORT)
	_start_ping_timer(true)

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
	_start_ping_timer(false)

func _on_connection_failed() -> void:
	_set_phase("offline")
	print("Failed to connect to server.")

func _on_server_disconnected() -> void:
	print("Disconnected from server.") 
