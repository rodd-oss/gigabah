class_name AbilityCastConfig
extends Resource

@export var animation_kind: AnimationKind
@export var animation_name: String
## Delay between cast start and actual effect of ability, in seconds
@export var cast_point: float = 0.0


# TODO: Make this config generic. Currently this configs are specific for
#       player.tscn and its AnimationTree.
func setup_animation_tree(tree: AnimationTree) -> void:
	if animation_kind == AnimationKind.FULL_BODY:
		tree.set(
			&"parameters/Alive/FullBodyCastAnim/transition_request",
			animation_name,
		)
		tree.set(
			&"parameters/Alive/FullBodyCasts/request",
			AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE,
		)
	elif animation_kind == AnimationKind.UPPER_BODY:
		tree.set(
			&"parameters/Alive/UpperBodyCastAnim/transition_request",
			animation_name,
		)
		tree.set(
			&"parameters/Alive/UpperBodyCasts/request",
			AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE,
		)


enum AnimationKind {
	FULL_BODY,
	UPPER_BODY,
}
