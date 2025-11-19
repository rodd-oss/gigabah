class_name InnerSpirit
extends Ability

var cloud_scene := preload("res://scenes/inner_spirit_cloud.tscn")


func _get_cast_method() -> CastMethod:
	return CastMethod.DIRECTIONAL


func _get_cast_config() -> AbilityCastConfig:
	return preload("res://scenes/resources/ability_cast_configs/butt_cast.tres")


func _cast() -> CastResult:
	if not _has_target_direction():
		return CastResult.ERROR_NO_TARGET

	var cloud := cloud_scene.instantiate() as CharacterBody3D
	var projectile := cloud.get_node("%Projectile") as NetworkProjectile

	cloud.name = "inner_spirit_cloud_%d" % cloud.get_instance_id()

	projectile.move_direction = _target_direction
	projectile.speed = 3.0

	caster.owner.get_parent().add_child(cloud)

	cloud.global_position = caster.global_position
	cloud.global_position += Vector3.UP * 1.0
	cloud.global_position += _target_direction * 2.0

	cooldown = 2.0

	return CastResult.OK
