extends AnimationPlayer

@export var anim:String
var playing := false

func _on_radial_menu_behavior_on_hower() -> void:
	play(anim)
	playing = true

func _on_radial_menu_behavior_on_unhower() -> void:
	playing = false

func _on_animation_finished(anim_name: StringName) -> void:
	if playing:
		advance(0)
		play(anim)
