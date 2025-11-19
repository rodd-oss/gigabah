class_name ModifiableInteger
extends ModifiableProperty

@export var has_min: bool = false
@export var min_value: int = 0
@export var has_max: bool = false
@export var max_value: int = 100


func get_property_type() -> Variant.Type:
	return TYPE_INT


func get_default_value() -> Variant:
	return 0


func calculate_value(mods: Array[Modifier.PropertyMod]) -> Variant:
	var pre_add := 0
	var multiplier := 1.0
	var post_add := 0

	for mod: Modifier.PropertyMod in mods:
		match mod.kind:
			Modifier.ModifyKind.PRE_ADDITIVE:
				pre_add += mod.amount
			Modifier.ModifyKind.MULTIPLY:
				multiplier *= 1.0 + mod.amount / 100.0
			Modifier.ModifyKind.POST_ADDITIVE:
				post_add += mod.amount

	var result := int(pre_add * multiplier + post_add)
	if has_min:
		result = maxi(result, min_value)
	if has_max:
		result = mini(result, max_value)

	return result


func create_typed_property() -> Modifiers.Property:
	return IntProperty.new()


class IntProperty extends Modifiers.Property:
	var final_value: int:
		get:
			return 0 if untyped_final_value == null else untyped_final_value as int
