class_name MiasmaInfluence
extends Modifier

@export var damage_interval := 0.25
@export var damage_amount := 1

var _next_tick_time := 0.0


func _modifier_start() -> void:
	icon_path = "res://assets/textures/ui/ability_icons/InnerSpirit.png"


func _physics_process(delta: float) -> void:
	if not carrier:
		return

	_next_tick_time -= delta

	if _next_tick_time <= 0.0:
		carrier.health.take_damage(damage_amount)
		_next_tick_time += damage_interval
