class_name DevBall
extends Ability

var devball_scene := preload("res://scenes/bullet.tscn")
var impact_scene := preload("res://scenes/vfx/abilities/vfx_impact.tscn")


func _get_cast_method() -> CastMethod:
	return Ability.CastMethod.DIRECTIONAL


func _get_cast_config() -> AbilityCastConfig:
	return preload("res://scenes/resources/ability_cast_configs/hand_cast.tres")


func _cast() -> CastResult:
	if not _has_target_direction():
		return CastResult.ERROR_NO_TARGET

	var ball := devball_scene.instantiate() as Node3D

	# TODO: temp, find better way to do it
	var spawn_target := caster.owner.get_parent()
	spawn_target.add_child(ball)

	ball.name = "devball_%d" % ball.get_instance_id()

	ball.global_position = caster.global_position + _target_direction * 1.0
	ball.global_position += Vector3.UP * 1.5
	ball.look_at(ball.global_position + _target_direction)
	ball.tree_exiting.connect(_on_projectile_despawning.bind(ball), CONNECT_ONE_SHOT)

	var proj := ball.find_child("NetworkProjectile") as NetworkProjectile
	proj.move_direction = (_target_point - ball.global_position).normalized()
	proj.entered_hitbox.connect(_on_projectile_entered_hitbox.bind(ball), CONNECT_ONE_SHOT)
	proj.hit_wall.connect(_on_projectile_hit_wall.bind(ball))

	cooldown = 0.5

	return CastResult.OK


func _on_projectile_entered_hitbox(hitbox: HitBox3D, proj: Node3D) -> void:
	hitbox.hp.take_damage(5)
	hitbox.hero.modifiers.add_modifier(DevballTargetModifier.new())
	proj.queue_free()


func _on_projectile_hit_wall(_collision: KinematicCollision3D, proj: Node3D) -> void:
	proj.queue_free()


func _on_projectile_despawning(projectile: Node3D) -> void:
	call_deferred(
		&"_spawn_impact",
		projectile.get_parent(),
		projectile.global_position,
		NetSync.get_all_peers_have_vision(projectile),
	)


func _spawn_impact(spawn_target: Node, position: Vector3, peers_vision: PackedInt64Array) -> void:
	var impact_node := impact_scene.instantiate() as Node3D
	impact_node.name = "impact_effect_%d" % impact_node.get_instance_id()

	spawn_target.add_child(impact_node)
	impact_node.global_position = position
	NetSync.set_visibility_batch(peers_vision, impact_node, true)
