class_name AnimationStateMachine
extends Node

@export var animation_player_node: AnimationPlayer
@export var init_state: State

var current_state: State
var states: Dictionary = { }

func _ready() -> void:
	for child in get_children():
		if child is State:
			states[child.name] = child
			child.animation_player = animation_player_node
			child.state_changed.connect(_on_state_changed)

	if init_state:
		current_state = init_state
		current_state.enter()

func _process(delta: float) -> void:
	if current_state:
		current_state.process_logic(delta)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_logic(delta)

func _on_state_changed(new_state_name: String) -> void:
	if !multiplayer.is_server():
		return
	if new_state_name not in states:
		return
	if current_state.name == new_state_name:
		return
	rpc("transition_to", new_state_name)

@rpc("any_peer", "call_local")
func transition_to(new_state_name: String) -> void:
	if current_state:
		current_state.exit()
	
	current_state = states[new_state_name]
	current_state.enter()
