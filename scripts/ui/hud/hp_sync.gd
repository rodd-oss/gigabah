class_name HPSync
extends Node

@export var range_control: Range
@export var hp: NetworkHP:
	set(val):
		if hp:
			_unhook()

		hp = val

		if hp:
			_hook()


func _ready() -> void:
	_update_visual()


func _hook() -> void:
	hp.health_changed.connect(_on_health_changed)


func _unhook() -> void:
	hp.health_changed.disconnect(_on_health_changed)


func _on_health_changed(_new_health: int, _max_health: int) -> void:
	_update_visual()


func _update_visual() -> void:
	if not range_control or not hp:
		return

	range_control.max_value = hp.max_health
	range_control.value = hp.current_health
