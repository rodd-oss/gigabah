class_name HeroBaseModifier
extends Modifier

func _modifier_start() -> void:
	modify_property(&"move_speed", 5.0)
	modify_property(&"reverse_speed_factor", 0.5)
	modify_property(&"turn_rate", deg_to_rad(360.0))
	modify_property(&"hp_regen", 1.0)
