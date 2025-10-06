extends Node3D
## In-game menu controller attached to Index3d root.
## Responsibilities:
##  - Capture ESC key (unhandled input) to toggle a modal pause menu
##  - Build a simple UI (created in code) with two buttons: Disconnect & Back
##  - Back: closes modal (no network changes)
##  - Disconnect: calls NetworkManager.disconnect() and returns to main menu scene
##  - Should not interfere with gameplay nodes when hidden
##  - No actual pausing of physics implemented (can be added later if needed)

var _ui_root: Control
var _visible: bool = false

func _ready() -> void:
	_build_ui()
	_set_visible(false)

func _build_ui() -> void:
	_ui_root = Control.new()
	_ui_root.name = "InGameMenuUI"
	_ui_root.anchor_right = 1.0
	_ui_root.anchor_bottom = 1.0
	_ui_root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_ui_root.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_ui_root)

	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0,0,0,0.55)
	backdrop.anchor_right = 1.0
	backdrop.anchor_bottom = 1.0
	_ui_root.add_child(backdrop)

	var center: CenterContainer = CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	_ui_root.add_child(center)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	center.add_child(vbox)

	var title: Label = Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	vbox.add_child(title)

	var disconnect_btn: Button = Button.new()
	disconnect_btn.text = "Disconnect"
	disconnect_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	disconnect_btn.pressed.connect(_on_disconnect_pressed)
	vbox.add_child(disconnect_btn)

	var back_btn: Button = Button.new()
	back_btn.text = "Back"
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_btn.pressed.connect(_on_back_pressed)
	vbox.add_child(back_btn)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_toggle()
			# Mark input handled so it doesn't propagate further.
			get_viewport().set_input_as_handled()

func _toggle() -> void:
	_set_visible(not _visible)

func _set_visible(v: bool) -> void:
	_visible = v
	if _ui_root:
		_ui_root.visible = v

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
