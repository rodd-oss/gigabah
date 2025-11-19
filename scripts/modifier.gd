@abstract
class_name Modifier
extends Node

const ICON_PATH_PATTERN = "res://assets/textures/ui/modifier_icons/%s.png"

var carrier: Hero:
	set(val):
		assert(not carrier, "you can't change modifier's carrier")
		carrier = val

var icon_path: String = ICON_PATH_PATTERN % get_script().get_global_name():
	set(val):
		if val != icon_path:
			icon_path = val
			icon_path_changed.emit()

var expire_time := 0.0
var destroy_on_expire := false
## Assign to play animation when modifier active
var animation_config: AbilityCastConfig
var modified_properties: Dictionary[StringName, PropertyMod] = { }

signal property_mod_changed(property_name: StringName, mod: PropertyMod, modifier: Modifier)
signal icon_path_changed()


func modify_property(
		property_name: StringName,
		amount: Variant,
		kind: ModifyKind = ModifyKind.PRE_ADDITIVE,
) -> void:
	var prop_changed := false
	var prop_mod: PropertyMod
	if property_name in modified_properties:
		prop_mod = modified_properties[property_name]
	else:
		prop_mod = PropertyMod.new()
		modified_properties[property_name] = prop_mod
		prop_changed = true

	prop_changed = prop_changed or (amount != prop_mod.amount)
	prop_changed = prop_changed or (kind != prop_mod.kind)

	prop_mod.amount = amount
	prop_mod.kind = kind

	if prop_changed:
		property_mod_changed.emit(property_name, prop_mod, self)


## Called when modifier attached to carrier
func _modifier_start() -> void:
	pass


func _physics_process(delta: float) -> void:
	if expire_time > delta:
		expire_time -= delta
	else:
		expire_time = 0.0
		if destroy_on_expire:
			queue_free()


enum ModifyKind {
	PRE_ADDITIVE,
	MULTIPLY,
	POST_ADDITIVE,
}


class PropertyMod:
	var amount: Variant
	var kind: ModifyKind
