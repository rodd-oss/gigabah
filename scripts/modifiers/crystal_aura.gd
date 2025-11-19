class_name CrystalAuraModifier
extends Modifier

@export var hp_regen: float = 10.0:
	set(val):
		hp_regen = val
		modify_property(&"hp_regen", hp_regen)
