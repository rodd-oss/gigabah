class_name DevballTargetModifier
extends Modifier

func _modifier_start() -> void:
	modify_property(&"move_speed", -0.75, Modifier.ModifyKind.MULTIPLY)

	expire_time = 2.0
	destroy_on_expire = true

	icon_path = "res://assets/textures/ui/ability_icons/DevBall.png"
