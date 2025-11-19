class_name Dash
extends Ability

static func _static_init() -> void:
	preload("res://scripts/modifiers/jumping.gd")


func _get_cast_method() -> CastMethod:
	return CastMethod.DIRECTIONAL

# func _get_cast_config() -> AbilityCastConfig:
# 	return null


func _cast() -> CastResult:
	if not _has_target_direction():
		return CastResult.ERROR_NO_TARGET

	var modifier := Dashing.new()
	modifier.direction = (_target_direction * Vector3(1.0, 0.0, 1.0)).normalized()
	caster.hero.modifiers.add_modifier(modifier)

	cooldown = 3.0

	return CastResult.OK
