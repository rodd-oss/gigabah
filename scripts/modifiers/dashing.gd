class_name Dashing
extends Modifier

@export var direction := Vector3.FORWARD
@export var distance := 5.0
@export var speed := 25.0

var _traveled := 0.0


func _modifier_start() -> void:
	modify_property(&"cant_move", true)
	modify_property(&"cant_turn", true)
	modify_property(&"no_gravity", true)

	carrier.facing_angle = Vector2(direction.x, direction.z).normalized().angle()

	expire_time = distance / speed

	icon_path = "res://assets/textures/ui/ability_icons/Dash.png"


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return

	var step_dist := speed

	carrier.velocity = direction.normalized() * step_dist
	carrier.move_and_slide()

	_traveled += step_dist * delta

	if _traveled >= distance:
		queue_free()
		carrier.velocity = Vector3.ZERO
