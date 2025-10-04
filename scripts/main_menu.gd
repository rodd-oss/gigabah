extends Control

## Main screen (first level)
@onready var new_game_button: Button = $MainScreen/MainVBox/NewGameButton
@onready var exit_button: Button = $MainScreen/MainVBox/ExitButton

## Second screen (game actions)
@onready var game_screen: Control = $GameScreen
@onready var main_screen: Control = $MainScreen
@onready var create_lobby_button: Button = $GameScreen/GameVBox/CreateLobbyButton
@onready var connect_lobby_button: Button = $GameScreen/GameVBox/ConnectLobbyButton
@onready var back_button: Button = $GameScreen/GameVBox/BackButton

## Connect dialog
@onready var connect_dialog: Window = $ConnectDialog
@onready var invite_code_edit: LineEdit = $ConnectDialog/ConnectVBox/InviteCodeEdit
@onready var connect_confirm_button: Button = $ConnectDialog/ConnectVBox/ConnectButtons/ConnectConfirmButton
@onready var connect_cancel_button: Button = $ConnectDialog/ConnectVBox/ConnectButtons/ConnectCancelButton

func _ready() -> void:
	# Wire up first screen
	new_game_button.pressed.connect(_on_new_game_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

	# Second screen buttons
	create_lobby_button.pressed.connect(_on_create_lobby_pressed)
	connect_lobby_button.pressed.connect(_on_connect_lobby_pressed)
	back_button.pressed.connect(_on_back_pressed)

	# Dialog buttons
	connect_confirm_button.pressed.connect(_on_connect_confirm_pressed)
	connect_cancel_button.pressed.connect(_on_connect_cancel_pressed)

func _show_screen(main: bool) -> void:
	main_screen.visible = main
	game_screen.visible = !main
	if !main:
		# Prepare secondary screen state if needed
		pass

func _on_new_game_pressed() -> void:
	_show_screen(false)

func _on_back_pressed() -> void:
	_show_screen(true)

func _on_create_lobby_pressed() -> void:
	# Placeholder: actual lobby creation logic will be added later
	print("[Menu] Create lobby clicked (not implemented yet)")

func _on_connect_lobby_pressed() -> void:
	invite_code_edit.text = ""
	connect_dialog.visible = true
	connect_dialog.grab_focus()
	invite_code_edit.grab_focus()

func _on_connect_cancel_pressed() -> void:
	connect_dialog.visible = false

func _on_connect_confirm_pressed() -> void:
	var code := invite_code_edit.text.strip_edges()
	if code.is_empty():
		push_warning("Invite code is empty")
		return
	print("[Menu] Attempting connect with code: %s" % code)
	# TODO: Implement lookup / connect by invite code
	connect_dialog.visible = false

func _on_exit_pressed() -> void:
	get_tree().quit()
