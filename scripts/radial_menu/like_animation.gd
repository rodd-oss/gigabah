extends AnimationPlayer

var playing = false

func _on_radial_menu_behavior_on_hower() -> void:
	play("radial_menu_animations/sin")
	playing = true


func _on_radial_menu_behavior_on_unhower() -> void:
	playing = false


func _on_animation_finished(anim_name: StringName) -> void:
	if playing:
		play("radial_menu_animations/sin")
