class_name Caster
extends Node3D

## Where ability nodes will store. Also ability nodes added to this container
## will be automatically added to this caster.
@export var abilities_container: NodePath = "."

signal ability_added(ability_index: int)
signal ability_removed(ability: Ability)
## Emits when all basic checks done but before calling ability's cast code
signal start_casting(ability: Ability)
## Emits after ability's cast code executed and it returned OK
signal successfully_casted(ability: Ability)

var _abilities: Array[Ability] = []
@onready var _container_node: Node = get_node(abilities_container)


func get_ability_count() -> int:
	return _abilities.size()


func get_ability(index: int) -> Ability:
	if index >= 0 and index < _abilities.size():
		return _abilities[index]
	return null


func add_ability(ability: Ability) -> CasterError:
	if not ability:
		return CasterError.ABILITY_IS_NULL

	if ability in _abilities:
		return CasterError.ALREADY_HAVE_THIS_ABILITY

	_abilities.append(ability)
	ability.caster = self

	ability_added.emit(_abilities.size() - 1)

	return CasterError.OK


func remove_ability(ability_index: int) -> CasterError:
	if ability_index < 0 or ability_index >= _abilities.size():
		return CasterError.ABILITY_INDEX_OF_OUT_BOUNDS

	var ability := _abilities[ability_index]

	ability.caster = null
	_abilities.remove_at(ability_index)

	ability_removed.emit(ability)

	return CasterError.OK


func _ready() -> void:
	if _container_node:
		for node: Node in _container_node.get_children():
			if node is not Ability:
				continue

			var err := add_ability(node as Ability)
			if err:
				push_error("failed adding ability: %s" % CasterError.keys()[err])


func _cast_started(ability: Ability) -> void:
	start_casting.emit(ability)


func _cast_done(ability: Ability) -> void:
	successfully_casted.emit(ability)


enum CasterError {
	OK,
	ABILITY_IS_NULL,
	ABILITY_INDEX_OF_OUT_BOUNDS,
	ALREADY_HAVE_THIS_ABILITY,
}
