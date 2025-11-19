class_name Jump
extends Ability

var max_distance := 10.0


static func _static_init() -> void:
	preload("res://scripts/modifiers/jumping.gd")


func _get_cast_method() -> CastMethod:
	return Ability.CastMethod.POINT


func _get_cast_config() -> AbilityCastConfig:
	return null


func _cast() -> CastResult:
	if not _has_target_point():
		return CastResult.ERROR_NO_TARGET
	if _target_point.distance_to(caster.global_position) > max_distance:
		return CastResult.ERROR_TARGET_IS_FAR

	var modifier := JumpingModifier.new()
	modifier.jump_height = 15.0
	modifier.land_point = _target_point
	modifier.duration = 2.0
	caster.hero.modifiers.add_modifier(modifier)

	cooldown = 5.0

	return CastResult.OK
