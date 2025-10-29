extends Node

## Speed (in m/s) of walking animation when foots on floor not slides
const WALK_ANIM_SPEED = 5.0

@export var input_controller: InputController
@export var hero: Hero
@export var caster: Caster
@export var model_root: Node3D
@export var animation_tree: AnimationTree


func _ready() -> void:
	hero.jumped.connect(_on_hero_jumped)
	hero.landed.connect(_on_hero_landed)

	caster.start_casting.connect(_on_caster_start_casting)


func _process(_delta: float) -> void:
	if !multiplayer.is_server():
		return

	if not input_controller.move_direction.is_zero_approx():
		var new_rot := model_root.rotation
		new_rot.y = -input_controller.move_direction.angle() - PI * 0.5
		model_root.rotation = new_rot

	animation_tree.set(
		&"parameters/Alive/BodyBottomGraph/WalkBlend/blend_position",
		hero.velocity.length() / WALK_ANIM_SPEED,
	)
	animation_tree.set(
		&"parameters/Alive/BodyBottomGraph/conditions/grounded",
		hero.is_on_floor(),
	)


func _on_hero_jumped() -> void:
	animation_tree.set(
		&"parameters/Alive/BodyBottomGraph/conditions/jumped",
		true,
	)


func _on_hero_landed() -> void:
	animation_tree.set(
		&"parameters/Alive/BodyBottomGraph/conditions/jumped",
		false,
	)


func _on_caster_start_casting(_ability: Ability) -> void:
	animation_tree.set(
		&"parameters/Alive/UpperBodyCastAnim/transition_request",
		"Cast1",
	)
	animation_tree.set(
		&"parameters/Alive/UpperBodyCasts/request",
		AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE,
	)
