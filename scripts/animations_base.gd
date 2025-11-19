extends Node

## Speed (in m/s) of walking animation when foots on floor not slides
const WALK_ANIM_SPEED = 5.0

@export var input_controller: InputController
@export var hero: Hero
@export var caster: Caster
@export var animation_tree: AnimationTree

# Variables for AnimationTree expressions
var chanelling_done: bool


func _ready() -> void:
	if !multiplayer.is_server():
		return

	caster.start_casting.connect(_on_caster_start_casting)
	caster.end_casting.connect(_on_caster_end_casting)

	hero.modifiers.modifier_added.connect(_on_modifier_added, CONNECT_DEFERRED)
	hero.modifiers.modifier_removing.connect(_on_modifier_removing)


func _process(_delta: float) -> void:
	if !multiplayer.is_server():
		return

	var ground_speed := 0.0
	if hero.is_on_floor():
		ground_speed = hero.velocity.length()

	animation_tree.set(
		&"parameters/Alive/WalkBlend/blend_position",
		ground_speed / WALK_ANIM_SPEED,
	)


func _on_caster_start_casting(ability: Ability) -> void:
	var config := ability._get_cast_config()
	if config:
		NetSync.rpc_to_observing_peers(owner, _rpc_start_animation, [config.resource_path])


func _on_caster_end_casting(_ability: Ability) -> void:
	NetSync.rpc_to_observing_peers(owner, _rpc_end_animation, [])


func _on_modifier_added(modifier: Modifier) -> void:
	if modifier.animation_config:
		NetSync.rpc_to_observing_peers(
			owner,
			_rpc_start_animation,
			[modifier.animation_config.resource_path],
		)


func _on_modifier_removing(modifier: Modifier) -> void:
	if modifier.animation_config:
		NetSync.rpc_to_observing_peers(owner, _rpc_end_animation, [])


@rpc("authority", "reliable", "call_local")
func _rpc_start_animation(config_path: String) -> void:
	chanelling_done = false
	var cast_config := load(config_path) as AbilityCastConfig
	cast_config.setup_animation_tree(animation_tree)


@rpc("authority", "reliable", "call_local")
func _rpc_end_animation() -> void:
	chanelling_done = true
