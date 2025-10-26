## This node updates canvas_layer's offset to match this node's
## 3D position in screen space
class_name ScreenSpacePosition
extends Node3D

@export var canvas_layer: CanvasLayer


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera or not canvas_layer:
		return

	var pos_on_viewport := camera.unproject_position(global_position)
	canvas_layer.offset = pos_on_viewport
