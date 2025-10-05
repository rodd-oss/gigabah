@tool
extends EditorPlugin

var inspector_ui_scene: PackedScene = preload("res://addons/sprite_frames_generator/inspector_ui_scene/inspector_ui_scene.tscn")

var panel = inspector_ui_scene.instantiate()

func _enter_tree():
	panel = inspector_ui_scene.instantiate()

	var btn = add_control_to_bottom_panel(panel, "SpriteFrames Generator")
	panel.initialize(btn)

func _exit_tree():
	remove_control_from_bottom_panel(panel)