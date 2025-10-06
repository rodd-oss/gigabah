extends Node

signal connectivity_phase_changed(phase: String) # offline | connecting | online
signal ping_updated(ms: int) # Round-trip time during active session

var peer: ENetMultiplayerPeer
var _phase: String = "offline"
var _last_ping_ms: int = -1
var _ping_timer: SceneTreeTimer
var _pending_ping_sent_ms: int = -1

func _ready() -> void:
	# Dedicated server стартует сразу. Клиент ждёт кнопку.
	if OS.has_feature("dedicated_server"):
		start_server()
	else:
		_set_phase("offline")

## Start as server
func start_server() -> void:
	peer = ENetMultiplayerPeer.new()
	var err: int = peer.create_server(NetworkConfig.PORT)
	if err != OK:
		print("[NetworkManager] create_server error %d" % err)
		return
	multiplayer.multiplayer_peer = peer
	_set_phase("online")
	print("Server started on port %d" % NetworkConfig.PORT)

## Start as client
func start_client(address: String) -> void:
	peer = ENetMultiplayerPeer.new()
	var err: int = peer.create_client(address, NetworkConfig.PORT)
	if err != OK:
		print("[NetworkManager] create_client error %d" % err)
		_set_phase("offline")
		return
	multiplayer.multiplayer_peer = peer
	_set_phase("connecting")
	multiplayer.connected_to_server.connect(_on_connected_to_server, CONNECT_ONE_SHOT)
	multiplayer.connection_failed.connect(_on_connection_failed, CONNECT_ONE_SHOT)
	multiplayer.server_disconnected.connect(_on_server_disconnected, CONNECT_ONE_SHOT)
	print("Connecting to %s:%d..." % [address, NetworkConfig.PORT])

func request_client_connect(address: String = NetworkConfig.ADDRESS) -> void:
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

func get_last_ping_ms() -> int:
	return _last_ping_ms

func _start_ping_loop() -> void:
	_cancel_ping_loop()
	_schedule_next_ping()

func _schedule_next_ping() -> void:
	_ping_timer = get_tree().create_timer(NetworkConfig.PING_INTERVAL_SEC)
	_ping_timer.timeout.connect(_on_ping_timer, CONNECT_ONE_SHOT)

func _cancel_ping_loop() -> void:
	_ping_timer = null
	_pending_ping_sent_ms = -1

func _on_ping_timer() -> void:
	if _phase != "online":
		return
	_send_ping()
	_schedule_next_ping()

@rpc
func _rpc_ping(sent_ms: int) -> void:
	# Only server should answer pings.
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id <= 0:
		return
	rpc_id(sender_id, "_rpc_pong", sent_ms)

@rpc
func _rpc_pong(sent_ms: int) -> void:
	# Only client should process pong.
	if multiplayer.is_server():
		return
	if _pending_ping_sent_ms != sent_ms:
		return
	var rtt: int = Time.get_ticks_msec() - sent_ms
	_last_ping_ms = rtt
	emit_signal("ping_updated", rtt)
	_pending_ping_sent_ms = -1

func _send_ping() -> void:
	if multiplayer.is_server():
		return # Server does not measure RTT here.
	var now: int = Time.get_ticks_msec()
	_pending_ping_sent_ms = now
	rpc_id(1, "_rpc_ping", now) # Server has ID 1

## Client connection handlers (with ping integration)
func _on_connected_to_server() -> void:
	_set_phase("online")
	print("Connected to server.")
	_start_ping_loop()

func _on_connection_failed() -> void:
	_set_phase("offline")
	print("Failed to connect to server.")
	_cancel_ping_loop()

func _on_server_disconnected() -> void:
	print("Disconnected from server.")
	_set_phase("offline")
	multiplayer.multiplayer_peer = null
	peer = null
	_cancel_ping_loop()