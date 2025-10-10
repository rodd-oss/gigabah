extends Control

@onready var exit_button: Button = $Center/VBox/ExitButton
@onready var server_id_label: Label = $Center/VBox/ServerInfo/ServerIdLabel
@onready var settings_button: Button = $Center/VBox/SettingsButton
@onready var connect_button: Button = $Center/VBox/ConnectButton

const SERVER_ID: String = "#0001" # Заглушка до интеграции реального списка серверов
var _connected: bool = false
var _connect_in_progress: bool = false

func _ready() -> void:
	print_debug("[MainMenu] _ready() called")
	server_id_label.text = "Server: %s" % SERVER_ID
	exit_button.pressed.connect(_on_exit_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	connect_button.pressed.connect(_on_connect_pressed)
	# If this instance is a dedicated server, hide/disable the connect button entirely.
	if OS.has_feature("dedicated_server"):
		print_debug("[MainMenu] Dedicated server detected - hiding Connect button")
		connect_button.disabled = true
		connect_button.visible = false
	else:
		print_debug("[MainMenu] Client mode - Connect button available")
	_update_connect_button()


func _process(_delta: float) -> void:
	# Нет активной логики в процессе кадра.
	pass

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/settings_menu.tscn")

func _update_connect_button() -> void:
	if _connected:
		connect_button.text = "Disconnect"
	elif _connect_in_progress:
		connect_button.text = "Connecting..."
	else:
		connect_button.text = "Connect"
	connect_button.disabled = _connect_in_progress

func _on_connect_pressed() -> void:
	print_debug("[MainMenu] Connect button pressed")
	var nm: Node = get_tree().root.get_node_or_null("NetworkManager")
	if not nm:
		print_debug("[MainMenu] ERROR: NetworkManager not found")
		return
	if not _connected:
		# Change scene; menu will be destroyed so no signal handlers needed
		var target_address: String = nm.ADDRESS if OS.has_feature("client") else "127.0.0.1"
		print_debug("[MainMenu] Target address: %s" % target_address)
		print_debug("[MainMenu] Changing scene to index.tscn")
		get_tree().change_scene_to_file("res://scenes/index.tscn")
		if nm.has_method("request_client_connect"):
			print_debug("[MainMenu] Requesting client connection")
			nm.call("request_client_connect", target_address)
	else:
		print_debug("[MainMenu] Disconnecting from server")
		if nm.has_method("close_connection"):
			nm.call("close_connection")
		_connected = false
		_connect_in_progress = false
		_update_connect_button()
