class_name ModifiablesMap
extends Resource

## All modifiable properties must be declared in editor.
## Adding properties during runtime not supported and will
## lead to undefined behaviour.
@export var properties: Dictionary[StringName, ModifiableProperty] = { }

var _name_by_hash: Dictionary[int, StringName] = { }


func get_property_name_by_hash(name_hash: int) -> StringName:
	return _name_by_hash.get(name_hash)


func _init() -> void:
	call_deferred(&"_compute_hashes")


func _compute_hashes() -> void:
	for prop_name: StringName in properties.keys():
		var name_hash := prop_name.hash()
		if name_hash in _name_by_hash.keys():
			push_error(
				"Found hash collision, string '%s'" % prop_name +
				" and '%s'" % _name_by_hash[name_hash] +
				" have same hash. Rename one of those property.",
			)

		_name_by_hash[name_hash] = prop_name
