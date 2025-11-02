extends Node

## Speed (in m/s) of walking animation when foots on floor not slides
const WALK_ANIM_SPEED = 5.0

@export var input_controller: InputController
@export var hero: Hero
@export var caster: Caster
@export var model_root: Node3D
@export var animation_tree: AnimationTree


func _ready() -> void:
	if !multiplayer.is_server():
		return

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
	_set_tree_param(
		&"parameters/Alive/UpperBodyCastAnim/transition_request",
		"Cast1" if Time.get_ticks_msec() % 2 == 0 else "Cast2",
	)
	_set_tree_param(
		&"parameters/Alive/UpperBodyCasts/request",
		AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE,
	)


## intended to use to request one shot animations because NetworkSynchronizer
## can skip window when `*/request` is set and before it unsets by tree
func _set_tree_param(param: StringName, value: Variant) -> void:
	var spawner_inst_id: Variant = owner.get_meta(AdvancedMultiplayerSpawner.META_ADVANCED_SPAWNER)
	if spawner_inst_id == null:
		push_error("no advanced spawner meta for node %s" % owner)
		return

	# TODO: little hack until issue #92 will be fixed
	#       https://github.com/rodd-oss/gigabah/issues/92
	var spawner := instance_from_id(spawner_inst_id) as AdvancedMultiplayerSpawner
	for i: int in range(spawner.get_peers_have_vision_count(owner)):
		var peer_id := spawner.get_peer_have_vision(owner, i)
		_rpc_set_tree_param.rpc_id(peer_id, param, value)


@rpc("authority", "reliable", "call_local")
func _rpc_set_tree_param(param: StringName, value: Variant) -> void:
	animation_tree.set(param, value)
