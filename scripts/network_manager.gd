extends Node


var peer: ENetMultiplayerPeer
const ADDRESS: String = "gigabuh.d.roddtech.ru"
const PORT: int = 25445

# Pending client connect request (address queued until gameplay scene is present)
var _pending_client_address: String = ""
signal client_connected()
signal client_connection_failed()

func _ready() -> void:
	print_debug("[NetworkManager] _ready() called")
	# Dedicated server needs to load the game scene first, then start server
	if OS.has_feature("dedicated_server"):
		print_debug("[NetworkManager] Detected dedicated_server feature - loading game scene then starting server")
		call_deferred("_start_dedicated_server")
	else:
		print_debug("[NetworkManager] Client mode - waiting for Connect button")

func _start_dedicated_server() -> void:
	get_tree().change_scene_to_file("res://scenes/index.tscn")
	call_deferred("start_server")

## Start as server
func start_server() -> void:
	peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT)
	multiplayer.multiplayer_peer = peer
	print("[NetworkManager] Server started on port %d" % PORT)

## Start as client
func start_client(address: String) -> void:
	print_debug("[NetworkManager] start_client(%s:%d)" % [address, PORT])
	peer = ENetMultiplayerPeer.new()
	peer.create_client(address, PORT)
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	print("[NetworkManager] Connecting to %s:%d..." % [address, PORT])

## Request a client connection after a scene change
func request_client_connect(address: String) -> void:
	print_debug("[NetworkManager] request_client_connect(%s)" % address)
	_pending_client_address = address
	var tree: SceneTree = get_tree()
	if tree == null:
		print_debug("[NetworkManager] ERROR: SceneTree is null")
		return
	# If scene already loaded, connect immediately
	var current: Node = tree.current_scene
	var scene_name: String = str(current.name) if current != null else "null"
	print_debug("[NetworkManager] Current scene: %s" % scene_name)
	if current and current.name == "Index3d":
		print_debug("[NetworkManager] Index3d already loaded - connecting immediately")
		_connect_if_pending()
		return
	# Otherwise listen for scene change (signal emits with no arguments)
	print_debug("[NetworkManager] Waiting for scene_changed signal")
	if not tree.scene_changed.is_connected(_on_scene_changed_for_connect):
		tree.scene_changed.connect(_on_scene_changed_for_connect)

func _on_scene_changed_for_connect() -> void:
	print_debug("[NetworkManager] _on_scene_changed_for_connect() called")
	var tree: SceneTree = get_tree()
	if tree == null:
		print_debug("[NetworkManager] ERROR: SceneTree is null in scene_changed handler")
		return
	var scene: Node = tree.current_scene
	var scene_name_changed: String = str(scene.name) if scene != null else "null"
	print_debug("[NetworkManager] Scene changed to: %s" % scene_name_changed)
	if scene and scene.name == "Index3d":
		print_debug("[NetworkManager] Index3d detected - initiating connection")
		_connect_if_pending()
		if tree.scene_changed.is_connected(_on_scene_changed_for_connect):
			tree.scene_changed.disconnect(_on_scene_changed_for_connect)
			print_debug("[NetworkManager] Disconnected from scene_changed signal")

func _connect_if_pending() -> void:
	if _pending_client_address == "":
		print_debug("[NetworkManager] No pending address - skipping connect")
		return
	var address: String = _pending_client_address
	_pending_client_address = ""
	print_debug("[NetworkManager] Executing pending connection to %s" % address)
	start_client(address)

## Client connection handlers
func _on_connected_to_server() -> void:
	print("[NetworkManager] ✓ Connected to server successfully")
	client_connected.emit()

func _on_connection_failed() -> void:
	print("[NetworkManager] ✗ Connection failed")
	client_connection_failed.emit()

func _on_server_disconnected() -> void:
	print("[NetworkManager] Server disconnected")
