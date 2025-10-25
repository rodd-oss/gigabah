extends CharacterBody3D

@export var SPEED: float = 5.0
@export var JUMP_VELOCITY: float = 4.5

@export var input_controller: InputController
@export var caster: Caster

var _local_peer := true
var _prev_cast_mask := 0


func _ready() -> void:
	_local_peer = owner.name.to_int() == multiplayer.get_unique_id()


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		# Add the gravity.
		if is_on_floor():
			if input_controller.jump_input:
				velocity.y = JUMP_VELOCITY
		else:
			velocity += get_gravity() * delta

		velocity.x = input_controller.move_direction.x * SPEED
		velocity.z = input_controller.move_direction.y * SPEED

		move_and_slide()


func _process(_delta: float) -> void:
	if multiplayer.is_server() and caster:
		var pressed_cast_mask := input_controller.cast_mask
		# var just_pressed_cast_mask := pressed_cast_mask & ~_prev_cast_mask
		_prev_cast_mask = pressed_cast_mask

		for cast_slot_idx: int in range(3):
			if (pressed_cast_mask & (1 << cast_slot_idx)) == 0:
				continue

			var ability := caster.get_ability(cast_slot_idx)
			if ability:
				push_warning("casting %s" % ability.name)
				_cast_ability(ability)


func _cast_ability(ability: Ability) -> void:
	match ability._get_cast_method():
		Ability.CastMethod.NO_TARGET:
			ability.cast_notarget()
		Ability.CastMethod.DIRECTIONAL:
			if not is_nan(input_controller.cursor_world_pos.x):
				push_warning("cursor_world_pos: %v" % input_controller.cursor_world_pos)
				var dir := input_controller.cursor_world_pos - global_position
				ability.cast_in_direction(dir.normalized())
