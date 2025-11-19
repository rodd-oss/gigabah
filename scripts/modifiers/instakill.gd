class_name InstaKillModifier
extends Modifier

func _modifier_start() -> void:
	carrier.health.take_damage(carrier.health.max_health)
	queue_free()
