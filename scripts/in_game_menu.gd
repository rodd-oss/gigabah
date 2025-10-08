extends Control
## In-game pause menu: ESC toggles visibility, Disconnect returns to main menu, Back hides.

@onready var disconnect_button: Button = $Center/VBox/DisconnectButton
@onready var back_button: Button = $Center/VBox/BackButton

var _visible_state: bool = false

func _ready() -> void:
	visible = false
	disconnect_button.pressed.connect(_on_disconnect_pressed)
	back_button.pressed.connect(_on_back_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_toggle()
			# Mark input handled so it doesn't propagate further.
			get_viewport().set_input_as_handled()

func _toggle() -> void:
	_set_visible(not _visible_state)

func _set_visible(v: bool) -> void:
	_visible_state = v
	visible = v

func _on_back_pressed() -> void:
	_set_visible(false)

func _on_disconnect_pressed() -> void:
	var nm: Node = get_tree().root.get_node_or_null("NetworkManager")
	if nm and nm.has_method("close_connection"):
		nm.call("close_connection")
	else:
		print_debug("[InGameMenu] NetworkManager disconnect not available")
	# Return to main menu scene
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
