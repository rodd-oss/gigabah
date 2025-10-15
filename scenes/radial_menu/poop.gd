extends Node3D

var spawn_enter:=false

func _on_area_3d_body_entered(body: Node3D) -> void:
	if multiplayer.is_server():
		if body is CharacterBody3D:
			if spawn_enter:
				scale *= Vector3(1.5,0.1,1.5)
				$Area3D.disconnect("body_entered",_on_area_3d_body_entered)
			else:
				spawn_enter = true
			
