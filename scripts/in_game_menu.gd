extends Control
## In-game pause menu: ESC toggles visibility, Settings opens settings menu, Back hides, Quit exits game.

@onready var settings_button: Button = $Center/VBox/SettingsButton
@onready var back_button: Button = $Center/VBox/BackButton
@onready var quit_button: Button = $Center/VBox/QuitButton

var _visible_state: bool = false

func _ready() -> void:
	visible = false
	settings_button.pressed.connect(_on_settings_pressed)
	back_button.pressed.connect(_on_back_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

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

func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/settings_menu.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
