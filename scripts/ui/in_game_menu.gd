extends CanvasLayer
## In-game pause menu: ESC toggles visibility, Settings opens settings menu, Back hides, Quit exits game.
## Only active on client (not on server).

@onready var settings_button: Button = $Control/Center/VBox/SettingsButton
@onready var back_button: Button = $Control/Center/VBox/BackButton
@onready var quit_button: Button = $Control/Center/VBox/QuitButton

var _visible_state: bool = false
var _settings_menu_instance: Control = null


func _ready() -> void:
	# Hide menu on server (UI not needed)
	if multiplayer.is_server():
		visible = false
		set_process_unhandled_input(false)
		return

	visible = false
	settings_button.pressed.connect(_on_settings_pressed)
	back_button.pressed.connect(_on_back_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			# If settings menu is open, close it first
			if _settings_menu_instance and _settings_menu_instance.visible:
				_close_settings()
				get_viewport().set_input_as_handled()
				return
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


func _on_settings_pressed() -> void:
	# Load and instance settings menu
	var settings_scene: PackedScene = preload("res://scenes/ui/settings_menu.tscn")
	if settings_scene:
		_settings_menu_instance = settings_scene.instantiate()
		get_tree().root.add_child(_settings_menu_instance)
		# Connect to back button signal if possible
		if _settings_menu_instance.has_signal("back_pressed"):
			_settings_menu_instance.back_pressed.connect(_close_settings)
		# Hide pause menu while settings is open
		visible = false


func _close_settings() -> void:
	if _settings_menu_instance:
		_settings_menu_instance.queue_free()
		_settings_menu_instance = null
	# Show pause menu again
	visible = true


func _on_quit_pressed() -> void:
	get_tree().quit()
