@tool
class_name OneShotEffect
extends Node

## List of emitters that will be autostarted and when last of those
## emitters finished this node will be removed
@export var emitters: Array[GPUParticles3D] = []

var _remaining_active_emitters_num := 0


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	for emitter: GPUParticles3D in emitters:
		if not emitter.one_shot:
			push_warning(
				("emitter %s isn't one shot, this instance " +
					"will not be removed automatically" ) % emitter,
			)

		_remaining_active_emitters_num += 1

		emitter.emitting = true
		emitter.finished.connect(_on_emitter_finished, CONNECT_ONE_SHOT)


func _on_emitter_finished() -> void:
	_remaining_active_emitters_num -= 1
	if _remaining_active_emitters_num <= 0:
		queue_free()

@export_tool_button("Start all emitters")
@warning_ignore("unused_private_class_variable")
var _tool_button_play_all: Callable = func() -> void:
	for emitter: GPUParticles3D in emitters:
		emitter.restart()
