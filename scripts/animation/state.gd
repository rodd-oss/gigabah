class_name State
extends Node

signal state_changed(new_state_name: String)

@export var animation_name: String = ""

var animation_player: AnimationPlayer

func enter() -> void:
	if animation_player and animation_name:
		animation_player.play(animation_name)

func exit() -> void:
	pass

func process_logic(_delta: float) -> void:
	pass

func physics_logic(_delta: float) -> void:
	pass
