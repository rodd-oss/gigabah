class_name JumpingModifier
extends Modifier

var ground_impact_scene := preload("res://scenes/vfx/abilities/vfx_ground_impact.tscn")

var land_point: Vector3
var jump_height: float = 3.0
var duration: float = 1.0

var _t := 0.0
var _p0: Vector3
var _p1: Vector3
var _p2: Vector3


func _modifier_start() -> void:
	modify_property(&"cant_move", true)
	modify_property(&"cant_turn", true)
	modify_property(&"cant_cast", true)

	_p0 = carrier.global_position
	_p2 = land_point
	_p1 = _p0 + (_p2 - _p0) * 0.5 + Vector3.UP * jump_height

	expire_time = duration

	icon_path = "res://assets/textures/ui/ability_icons/Jump.png"
	animation_config = preload("res://scenes/resources/ability_cast_configs/jump.tres")


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return

	if _t + delta < 1.0:
		_t += delta
		var new_pos := Utils.quadratic_bezier_3d(_p0, _p1, _p2, _t)
		var delta_motion := new_pos - carrier.global_position
		if carrier.move_and_collide(delta_motion):
			queue_free()
	else:
		carrier.global_position = land_point
		queue_free()

		var impact := ground_impact_scene.instantiate() as Node3D
		carrier.get_parent().add_child(impact)
		impact.global_position = carrier.global_position
		NetSync.inherit_visibility(carrier.owner, impact)
