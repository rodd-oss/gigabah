@abstract
class_name ModifiableProperty
extends Resource

@abstract
func get_property_type() -> Variant.Type


@abstract
func get_default_value() -> Variant


@abstract
func calculate_value(mods: Array[Modifier.PropertyMod]) -> Variant


@abstract
func create_typed_property() -> Modifiers.Property
