class_name DevBall
extends Ability

var devball_scene := preload("res://scenes/bullet.tscn")
var impact_scene := preload("res://scenes/abilities/vfx_impact.tscn")


func _get_cast_method() -> CastMethod:
	return Ability.CastMethod.DIRECTIONAL


func _cast_in_direction(dir: Vector3) -> CastError:
	var ball := devball_scene.instantiate() as Node3D

	# TODO: temp, find better way to do it
	var spawn_target := caster.owner.get_parent()
	spawn_target.add_child(ball)

	ball.name = "devball_%d" % ball.get_instance_id()

	ball.global_position = caster.global_position + dir.normalized() * 1.0
	ball.global_position += Vector3.UP * 1.5
	ball.look_at(ball.global_position + dir)
	ball.tree_exiting.connect(_on_projectile_despawning.bind(ball), CONNECT_ONE_SHOT)

	var proj := ball.find_child("NetworkProjectile") as NetworkProjectile
	proj.move_direction = (dir * Vector3(1.0, 0.0, 1.0)).normalized()

	cooldown = 0.5

	return CastError.OK


func _on_projectile_despawning(projectile: Node3D) -> void:
	call_deferred(&"_spawn_impact", projectile.get_parent(), projectile.global_position)


func _spawn_impact(parent: Node3D, position: Vector3) -> void:
	var impact_node := impact_scene.instantiate() as Node3D
	impact_node.name = "impact_effect_%d" % impact_node.get_instance_id()

	parent.add_child(impact_node)
	impact_node.global_position = position
	_inherit_network_visibility(impact_node)


func _inherit_network_visibility(target_node: Node) -> void:
	var spawner_inst_id: Variant = owner.get_meta(AdvancedMultiplayerSpawner.META_ADVANCED_SPAWNER)
	if spawner_inst_id == null:
		push_error("no advanced spawner meta for node %s" % owner)
		return

	var spawner := instance_from_id(spawner_inst_id) as AdvancedMultiplayerSpawner
	for i: int in range(spawner.get_peers_have_vision_count(owner)):
		var peer_id := spawner.get_peer_have_vision(owner, i)
		AdvancedMultiplayerSpawner.set_visibility_for(peer_id, target_node, true)
