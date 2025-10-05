extends Control
## Simplified main menu for single central server architecture.
## Layout nodes (see main_menu.tscn): Title, server info labels, Connect, Exit.

@onready var connect_button: Button = $Center/VBox/ConnectButton
@onready var exit_button: Button = $Center/VBox/ExitButton
@onready var server_id_label: Label = $Center/VBox/ServerInfo/ServerIdLabel
@onready var server_status_label: Label = $Center/VBox/ServerInfo/ServerStatusLabel
@onready var ping_label: Label = $Center/VBox/ServerInfo/PingLabel

const SERVER_ID: String = "#0001" # Placeholder until real server enumeration
var _last_ping_ms: int = -1
var _connecting: bool = false
const AUTO_ENTER: bool = false
const SERVER_ADDRESS: String = "127.0.0.1" # Adjust to remote IP when needed
const SERVER_PORT: int = 25445

# Helper to safely access MultiplayerAPI
func _mp() -> MultiplayerAPI:
	return get_tree().get_multiplayer()

func _ready() -> void:
	server_id_label.text = "Server: %s" % SERVER_ID
	server_status_label.text = "Status: offline"
	ping_label.text = "Ping: -- ms"
	connect_button.pressed.connect(_on_connect_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	if Engine.has_singleton("NetworkManager"):
		NetworkManager.ping_updated.connect(_on_ping_updated)
		NetworkManager.connectivity_phase_changed.connect(_on_phase_changed)
	if AUTO_ENTER:
		call_deferred("_auto_enter_game")

func _auto_enter_game() -> void:
	# If already in index scene skip
	if get_tree().current_scene and get_tree().current_scene.scene_file_path == "res://scenes/index.tscn":
		return
	_on_connect_pressed()

func _process(delta: float) -> void:
	_update_status(delta)

func _update_status(_delta: float) -> void:
	# Fallback visual update if signals missed
	var fallback_online: bool = multiplayer.multiplayer_peer != null and multiplayer.get_unique_id() != 0
	if fallback_online and server_status_label.text.find("online") == -1:
		_set_status_visual("online")
	elif !fallback_online and server_status_label.text.find("offline") == -1:
		_set_status_visual("offline")

func _estimate_ping_ms() -> int:
	return _last_ping_ms

func _on_connect_pressed() -> void:
	if _connecting:
		print("[Menu] Ignored connect press: already connecting")
		return
	print("[Menu] Connection button pressed (connect-first mode)")
	_connecting = true
	connect_button.disabled = true
	var mp: MultiplayerAPI = _mp()
	print("[Menu] Pre-check peer=%s unique_id=%d" % [str(mp.multiplayer_peer), mp.get_unique_id()])
	# If we have a non-ENet (Offline) peer, discard it so we can create a real ENet client
	if mp.multiplayer_peer != null and !(mp.multiplayer_peer is ENetMultiplayerPeer):
		print("[Menu] Detected OfflineMultiplayerPeer -> resetting to establish real network connection")
		mp.multiplayer_peer = null
	# If already connected (must be an ENetMultiplayerPeer and unique id != 0)
	if mp.multiplayer_peer != null and mp.get_unique_id() != 0 and mp.multiplayer_peer is ENetMultiplayerPeer:
		print("[Menu] Already connected (ENet) id=%d; changing scene immediately" % mp.get_unique_id())
		_change_to_game()
		return
	# Start client if needed
	if mp.multiplayer_peer == null:
		print("[Menu] No peer, starting direct client...")
		_start_direct_client(SERVER_ADDRESS, SERVER_PORT)
	else:
		print("[Menu] Existing peer present, waiting for handshake")
	# Subscribe to signals (one-shot) BEFORE connection completes
	if !mp.connected_to_server.is_connected(_on_connected_to_server_menu):
		mp.connected_to_server.connect(_on_connected_to_server_menu, CONNECT_ONE_SHOT)
		print("[Menu] Connected connected_to_server signal")
	if !mp.connection_failed.is_connected(_on_connection_failed_menu):
		mp.connection_failed.connect(_on_connection_failed_menu, CONNECT_ONE_SHOT)
		print("[Menu] Connected connection_failed signal")
	if !mp.server_disconnected.is_connected(_on_disconnected_menu):
		mp.server_disconnected.connect(_on_disconnected_menu, CONNECT_ONE_SHOT)
		print("[Menu] Connected server_disconnected signal")
	_set_status_visual("connecting")
	print("[Menu] Waiting for server handshake...")
	# Start timeout timer
	_start_connect_timeout()
	# Start polling loop in parallel (in case signals missed)
	_start_handshake_poll()

func _start_connect_timeout() -> void:
	var t: Timer = Timer.new()
	t.one_shot = true
	t.wait_time = 3.0
	t.timeout.connect(_on_connect_timeout, CONNECT_ONE_SHOT)
	add_child(t)
	t.start()
	print("[Menu] Started 3s connection timeout timer")

func _on_connect_timeout() -> void:
	if !_connecting:
		return
	var mp: MultiplayerAPI = _mp()
	if mp.get_unique_id() == 0:
		print("[Menu] Connection timeout - no handshake received")
		_connecting = false
		connect_button.disabled = false
		_set_status_visual("offline")
		push_warning("Connection timeout")
	else:
		print("[Menu] Timeout fired but we are connected (id=%d)" % mp.get_unique_id())

func _fallback_start_client() -> void:
	var address: String = "127.0.0.1" # Fallback local
	var port: int = 25445
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: int = peer.create_client(address, port)
	if err != OK:
		push_error("Fallback client create failed: %s" % err)
		return
	multiplayer.multiplayer_peer = peer
	print("[Menu] Fallback connecting to %s:%d" % [address, port])
	if !multiplayer.connected_to_server.is_connected(_on_connected_to_server_menu):
		multiplayer.connected_to_server.connect(_on_connected_to_server_menu, CONNECT_ONE_SHOT)
	if !multiplayer.connection_failed.is_connected(_on_connection_failed_menu):
		multiplayer.connection_failed.connect(_on_connection_failed_menu, CONNECT_ONE_SHOT)
	if !multiplayer.server_disconnected.is_connected(_on_disconnected_menu):
		multiplayer.server_disconnected.connect(_on_disconnected_menu, CONNECT_ONE_SHOT)

func _connect_and_wait() -> void:
	# Keep compatibility; just rely on button path
	_on_connect_pressed()

func _on_connected_to_server_menu() -> void:
	_set_status_visual("online")
	print("[Menu] Connected; switching scene now")
	_change_to_game()

func _start_handshake_poll() -> void:
	# Poll a few times if signal missed (e.g., started before menu scripts ready)
	var attempts: int = 0
	while attempts < 60: # ~3 seconds at 0.05s
		await get_tree().create_timer(0.05).timeout
		var mp: MultiplayerAPI = _mp()
		if mp.multiplayer_peer != null and mp.multiplayer_peer is ENetMultiplayerPeer and mp.get_unique_id() != 0:
			print("[Menu] Poll detected connection (id=%d); transitioning." % mp.get_unique_id())
			_change_to_game()
			return
		attempts += 1
	if _connecting:
		print("[Menu] Polling ended without connection.")

func _on_connection_failed_menu() -> void:
	_set_status_visual("offline")
	push_warning("Connection failed")

func _retry_connect() -> void:
	if !_connecting:
		_connect_and_wait()

func _on_disconnected_menu() -> void:
	_set_status_visual("offline")
	push_warning("Disconnected before start")

func _change_to_game() -> void:
	var tree := get_tree()
	if tree == null:
		push_warning("SceneTree unavailable; cannot change scene now")
		return
	var current_path: String = tree.current_scene.scene_file_path if tree.current_scene else "<none>"
	print("[Menu] _change_to_game called. Current scene=", current_path)
	var target_path := "res://scenes/index.tscn"
	if tree.current_scene and current_path == target_path:
		print("[Menu] Already in index scene, skipping change")
		_connecting = false
		connect_button.disabled = false
		return
	var packed: PackedScene = load(target_path)
	if packed == null:
		push_error("Cannot load target scene: %s" % target_path)
		_connecting = false
		connect_button.disabled = false
		return
	var inst: Node = packed.instantiate()
	# Add BEFORE freeing menu
	tree.root.add_child(inst)
	tree.current_scene = inst
	print("[Menu] Manually switched to "+target_path)
	_connecting = false
	connect_button.disabled = false
	# Remove menu
	queue_free()

func _verify_scene_loaded() -> void:
	# Legacy no-op retained for compatibility; now we manually instantiate scene.
	pass

func _create_network_manager_singleton() -> void:
	var script: Script = load("res://scripts/network_manager.gd")
	if script == null:
		push_error("Cannot load network_manager.gd")
		return
	var nm: Node = script.new()
	nm.name = "NetworkManager"
	get_tree().root.add_child(nm)
	print("[Menu] Created NetworkManager node dynamically")

func _start_direct_client(address: String, port: int) -> void:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: int = peer.create_client(address, port)
	if err != OK:
		push_error("Direct client create failed: %s" % err)
		return
	_mp().multiplayer_peer = peer
	var status := peer.get_connection_status() if peer.has_method("get_connection_status") else -1
	print("[Menu] Direct client connecting to %s:%d (err=%d status=%d)" % [address, port, err, status])

func _on_exit_pressed() -> void:
	get_tree().quit()

func _push_temp_warning(msg: String) -> void:
	print_debug("[MainMenu] WARNING: %s" % msg)

func _on_ping_updated(ms: int) -> void:
	_last_ping_ms = ms
	ping_label.text = "Ping: %d ms" % ms

func _on_phase_changed(phase: String) -> void:
	_set_status_visual(phase)

func _set_status_visual(phase: String) -> void:
	var text: String
	var color: Color
	match phase:
		"connecting":
			text = "Status: connecting"
			color = Color(1,0.85,0.2)
		"online":
			text = "Status: online"
			color = Color(0.3,1,0.3)
		_: # offline or unknown
			text = "Status: offline"
			color = Color(1,0.4,0.4)
	server_status_label.text = text
	server_status_label.add_theme_color_override("font_color", color)
