@abstract
class_name Ability
extends Node

var caster: Caster
var cooldown: float:
	set(val):
		var started := cooldown == 0.0 and val > 0.0
		cooldown = max(0.0, val)
		if started:
			cooldown_start.emit()

## When cooldown value changed from zero to positive value
signal cooldown_start()
## When cooldown value become zero
signal cooldown_end()
signal start_casting()
signal succesfully_casted()


@abstract func _get_cast_method() -> CastMethod


## Overridable, don't call super it's placeholder
func _cast_notarget() -> CastError:
	return CastError.ABILITY_NOT_NOTARGET

## Overridable, don't call super it's placeholder
# func _cast_targeted(_target: Node) -> CastError:
# 	return CastError.ABILITY_NOT_TARGETED


## Overridable, don't call super it's placeholder
func _cast_in_direction(_dir: Vector3) -> CastError:
	return CastError.ABILITY_NOT_DIRECTIONAL


func cast_notarget() -> CastError:
	var err := _is_castable()
	if err:
		return err

	_pre_cast()

	err = _cast_notarget()
	if err:
		return err

	_post_cast()

	return CastError.OK

# func cast_targeted(target: Node) -> CastError:
# 	var err := _is_castable()
# 	if err:
# 		return err

# 	_pre_cast()

# 	err = _cast_targeted(target)
# 	if err:
# 		return err

# 	_post_cast()

# 	return CastError.OK


func cast_in_direction(dir: Vector3) -> CastError:
	var err := _is_castable()
	if err:
		return err

	_pre_cast()

	err = _cast_in_direction(dir)
	if err:
		return err

	_post_cast()

	return CastError.OK


func _is_castable() -> CastError:
	if not caster:
		return CastError.NO_CASTER

	if cooldown > 0.0:
		return CastError.ON_COOLDOWN

	return CastError.OK


func _pre_cast() -> void:
	caster._cast_started(self)
	start_casting.emit()


func _post_cast() -> void:
	caster._cast_done(self)
	succesfully_casted.emit()


func _process(delta: float) -> void:
	if cooldown > delta:
		cooldown -= delta
	else:
		cooldown = 0.0
		cooldown_end.emit()


enum CastError {
	OK,
	NO_CASTER,
	ON_COOLDOWN,
	ABILITY_NOT_NOTARGET,
	ABILITY_NOT_TARGETED,
	ABILITY_NOT_DIRECTIONAL,
	TARGET_IS_FAR,
}

enum CastMethod {
	NO_TARGET,
	# TARGETED,
	DIRECTIONAL,
}
