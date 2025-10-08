extends Node

signal connectivity_status_changed(status: int)
signal ping_updated(ms: int)

const ADDRESS: String = "gigabuh.d.roddtech.ru"
const PORT: int = 25445
const PING_INTERVAL_SEC: float = 2.0

enum ConnectionStatus { OFFLINE, CONNECTING, ONLINE }

var peer: ENetMultiplayerPeer
var _status: ConnectionStatus = ConnectionStatus.OFFLINE
var _last_ping_ms: int = -1
var _ping_timer: SceneTreeTimer
var _pending_ping_sent_ms: int = -1

func _ready() -> void:
	if OS.has_feature("dedicated_server"):
		start_server()
	else:
		_set_status(ConnectionStatus.OFFLINE)

func start_server() -> void:
	peer = ENetMultiplayerPeer.new()
	_set_status(ConnectionStatus.CONNECTING)
	var err: int = peer.create_server(PORT)
	if err != OK:
		print("[NetworkManager] create_server error %d" % err)
		_set_status(ConnectionStatus.OFFLINE)
		return
	multiplayer.multiplayer_peer = peer
	_set_status(ConnectionStatus.ONLINE)
	print("Server started on port %d" % PORT)

func start_client(address: String) -> void:
	# Clear previous client if it exists.
	if peer:
		close_connection()
	peer = ENetMultiplayerPeer.new()
	_set_status(ConnectionStatus.CONNECTING)
	# Connect signals once (guard against duplicates).
	var connected_cb: Callable = Callable(self, "_on_connected_to_server")
	var failed_cb: Callable = Callable(self, "_on_connection_failed")
	var disconnected_cb: Callable = Callable(self, "_on_server_disconnected")
	if not multiplayer.connected_to_server.is_connected(connected_cb):
		multiplayer.connected_to_server.connect(connected_cb)
	if not multiplayer.connection_failed.is_connected(failed_cb):
		multiplayer.connection_failed.connect(failed_cb)
	if not multiplayer.server_disconnected.is_connected(disconnected_cb):
		multiplayer.server_disconnected.connect(disconnected_cb)
	var err: int = peer.create_client(address, PORT)
	if err != OK:
		print("[NetworkManager] create_client error %d" % err)
		_set_status(ConnectionStatus.OFFLINE)
		return
	multiplayer.multiplayer_peer = peer
	print("Connecting to %s:%d..." % [address, PORT])

func request_client_connect(address: String = ADDRESS) -> void:
	if _status != ConnectionStatus.OFFLINE:
		print("[NetworkManager] Ignoring connect request in status %s" % str(_status))
		return
	start_client(address)

func get_status() -> ConnectionStatus:
	return _status

func get_status_string() -> String:
	match _status:
		ConnectionStatus.CONNECTING:
			return "connecting"
		ConnectionStatus.ONLINE:
			return "online"
		_:
			return "offline"


func _set_status(s: ConnectionStatus) -> void:
	if _status == s:
		return
	_status = s
	emit_signal("connectivity_status_changed", _status)

func get_last_ping_ms() -> int:
	return _last_ping_ms

func _start_ping_loop() -> void:
	_cancel_ping_loop()
	_schedule_next_ping()

func _schedule_next_ping() -> void:
	_ping_timer = get_tree().create_timer(PING_INTERVAL_SEC)
	_ping_timer.timeout.connect(_on_ping_timer, CONNECT_ONE_SHOT)

func _cancel_ping_loop() -> void:
	_ping_timer = null
	_pending_ping_sent_ms = -1

func _on_ping_timer() -> void:
	if _status != ConnectionStatus.ONLINE:
		return
	_send_ping()
	_schedule_next_ping()

@rpc
func _rpc_ping(sent_ms: int) -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id <= 0:
		return
	rpc_id(sender_id, "_rpc_pong", sent_ms)

@rpc
func _rpc_pong(sent_ms: int) -> void:
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
		return
	var now: int = Time.get_ticks_msec()
	_pending_ping_sent_ms = now
	rpc_id(1, "_rpc_ping", now) # Server has ID 1

func _on_connected_to_server() -> void:
	_set_status(ConnectionStatus.ONLINE)
	print("Connected to server.")
	_start_ping_loop()

func _on_connection_failed() -> void:
	_set_status(ConnectionStatus.OFFLINE)
	print("Failed to connect to server.")
	_cancel_ping_loop()

func _on_server_disconnected() -> void:
	print("Disconnected from server.")
	_set_status(ConnectionStatus.OFFLINE)
	multiplayer.multiplayer_peer = null
	peer = null
	_cancel_ping_loop()

func close_connection() -> void:
	"""Close current ENet peer and reset state to OFFLINE (idempotent)."""
	if peer:
		peer.close()
	multiplayer.multiplayer_peer = null
	peer = null
	_cancel_ping_loop()
	_set_status(ConnectionStatus.OFFLINE)
