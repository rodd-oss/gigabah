extends AnimationPlayer


func _on_radial_menu_behavior_on_hower() -> void:
	play("radial_menu_animations/rotate")
	get_animation("radial_menu_animations/rotate").loop_mode = Animation.LOOP_LINEAR



func _on_radial_menu_behavior_on_unhower() -> void:
	get_animation("radial_menu_animations/rotate").loop_mode = Animation.LOOP_NONE
	play("radial_menu_animations/rotate")
