extends Control

@onready var new_lobby_button: Button = %NewLobbyButton
@onready var exit_button: Button = %ExitButton

func _ready() -> void:
	new_lobby_button.pressed.connect(_on_new_lobby_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

func _on_new_lobby_pressed() -> void:
	# For now just change to the existing index scene (game world)
	var error := get_tree().change_scene_to_file("res://scenes/index.tscn")
	if error != OK:
		push_error("Failed to load game scene: %s" % error)

func _on_exit_pressed() -> void:
	get_tree().quit()
