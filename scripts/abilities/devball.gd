class_name DevBall
extends Ability

var devball_scene := preload("res://scenes/bullet.tscn")


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
	
	var proj := ball.find_child("NetworkProjectile") as NetworkProjectile
	proj.move_direction = (dir * Vector3(1.0, 0.0, 1.0)).normalized()

	cooldown = 0.5

	return CastError.OK
