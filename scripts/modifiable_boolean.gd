class_name ModifiableBoolean
extends ModifiableProperty

func get_property_type() -> Variant.Type:
	return TYPE_BOOL


func get_default_value() -> Variant:
	return false


func calculate_value(mods: Array[Modifier.PropertyMod]) -> Variant:
	var any := false

	for mod: Modifier.PropertyMod in mods:
		any = any or mod.amount

	return any


func create_typed_property() -> Modifiers.Property:
	return BoolProperty.new()


class BoolProperty extends Modifiers.Property:
	var final_value: bool:
		get:
			return false if untyped_final_value == null else untyped_final_value as bool
