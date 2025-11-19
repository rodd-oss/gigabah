class_name Modifiers
extends MultiplayerCustomSpawn

const _META_KNOWN_MODIFIER = "known_modifier"

@export var modifiers_container: NodePath = ^"."
@export var modifiable_properties: ModifiablesMap
@export var carrier: Hero

signal modifier_added(modifier: Modifier)
signal modifier_removing(modifier: Modifier)

@onready var _modifiers_container: Node = get_node(modifiers_container)
var _modifiers: Array[Modifier] = []
var _properties: Dictionary[StringName, Property] = { }
var _to_recalc: Array[StringName] = []


func add_modifier(modifier: Modifier) -> void:
	if not is_instance_valid(modifier):
		push_error("attempt to add modifier, but node instance is invalid")
		return

	assert(not modifier.is_inside_tree(), "modifier already in tree")

	if modifier in _modifiers:
		return

	_init_added_modifier(modifier)

	_modifiers_container.add_child(modifier)

	NetSync.inherit_visibility(owner, modifier, true)

	modifier._modifier_start()


func remove_modifier(modifier: Modifier) -> void:
	if not is_instance_valid(modifier):
		push_error("attempt to remove modifier, but node isntance is invalid")
		return

	if modifier not in _modifiers:
		push_error("attempt to remove foreign modifier")
		return

	if modifier.get_parent() == _modifiers_container and not modifier.is_queued_for_deletion():
		modifier.queue_free()
		return

	if multiplayer.is_server():
		# remove all property modifications from property._mods
		for prop_name: StringName in modifier.modified_properties.keys():
			var prop := _properties[prop_name]
			var mod := modifier.modified_properties[prop_name]
			prop.mods.erase(mod)
			_recalc_property(prop_name)

	modifier.property_mod_changed.disconnect(_on_modifier_property_mod_changed)

	modifier_removing.emit(modifier)

	Utils.array_erase_replacing(_modifiers, _modifiers.find(modifier))


func _get_property(property_name: StringName) -> Property:
	assert(
		property_name in modifiable_properties.properties,
		"attempt to get unknown property '%s'" % property_name,
	)
	return _get_or_create_prop(property_name)


func get_bool_property(property_name: StringName) -> ModifiableBoolean.BoolProperty:
	return _get_property(property_name) as ModifiableBoolean.BoolProperty


func get_float_property(property_name: StringName) -> ModifiableFloat.FloatProperty:
	return _get_property(property_name) as ModifiableFloat.FloatProperty


func get_int_property(property_name: StringName) -> ModifiableInteger.IntProperty:
	return _get_property(property_name) as ModifiableInteger.IntProperty


func get_modifiers_count() -> int:
	return _modifiers.size()


func get_modifier(index: int) -> Modifier:
	if index >= 0 and index < _modifiers.size():
		return _modifiers[index]

	return null


func _get_or_create_prop(prop_name: StringName) -> Property:
	var prop := _properties.get(prop_name) as Property
	if not prop:
		var modifiable_prop := modifiable_properties.properties[prop_name]
		prop = modifiable_prop.create_typed_property()
		_properties[prop_name] = prop
	return prop


func _ready() -> void:
	super._ready()
	spawn_function = _custom_spawn_modifier

	if not is_instance_valid(_modifiers_container):
		push_error("modifiers_container pointing to invalid node")
	else:
		for i: int in range(_modifiers_container.get_child_count()):
			var child := _modifiers_container.get_child(i)
			if child is not Modifier:
				continue

			var modifier := child as Modifier
			add_modifier(modifier)

		_modifiers_container.child_entered_tree.connect(_on_modifiers_container_child_entered)
		_modifiers_container.child_exiting_tree.connect(_on_modifiers_container_child_exiting)


func _process(_delta: float) -> void:
	if multiplayer.is_server():
		call_deferred(&"_recalc_properties")


func _init_added_modifier(modifier: Modifier) -> void:
	if multiplayer.is_server():
		# add all modifier's already existing property modifications
		for prop_name: StringName in modifier.modified_properties.keys():
			var prop := _get_or_create_prop(prop_name)
			var mod := modifier.modified_properties[prop_name]
			prop.mods.append(mod)
			_recalc_property(prop_name)

	modifier.name = modifier.to_string()
	modifier.carrier = carrier
	modifier.property_mod_changed.connect(_on_modifier_property_mod_changed)
	modifier.set_meta(_META_KNOWN_MODIFIER, true)

	_modifiers.append(modifier)

	modifier_added.emit(modifier)


func _custom_spawn_modifier(create_node: Callable, _data: Variant) -> Modifier:
	var modifier := create_node.call() as Modifier
	_init_added_modifier(modifier)
	modifier._modifier_start()
	return modifier


func _recalc_properties() -> void:
	for prop_name: StringName in _to_recalc:
		_recalc_property(prop_name)

	_to_recalc.clear()


func _recalc_property(prop_name: StringName) -> void:
	var prop := _properties[prop_name]
	var prop_scheme: ModifiableProperty = modifiable_properties.properties.get(prop_name)

	assert(prop_scheme, "attempt to modify unknown modifiable property '%s'" % prop_name)

	prop.untyped_final_value = prop_scheme.calculate_value(prop.mods)
	prop.changed.emit()

	if multiplayer.is_server():
		NetSync.rpc_to_observing_peers(
			owner,
			_rpc_property_final_value,
			[prop_name.hash(), prop.untyped_final_value],
		)


func _on_modifiers_container_child_entered(node: Node) -> void:
	if node is not Modifier or node.has_meta(_META_KNOWN_MODIFIER):
		return

	add_modifier(node as Modifier)


func _on_modifiers_container_child_exiting(node: Node) -> void:
	if node is not Modifier:
		return

	remove_modifier(node as Modifier)


func _on_modifier_property_mod_changed(
		prop_name: StringName,
		mod: Modifier.PropertyMod,
		_modifier: Modifier,
) -> void:
	var prop: Property = _get_or_create_prop(prop_name)

	if mod not in prop.mods:
		prop.mods.append(mod)

	if multiplayer.is_server() and prop_name not in _to_recalc:
		_to_recalc.append(prop_name)


func network_serialize() -> Variant:
	# [prop_hash(int), prop_value(Variant), ...]
	var snapshot := []

	for prop_name: StringName in modifiable_properties.properties:
		var scheme := modifiable_properties.properties[prop_name]
		var prop := _get_or_create_prop(prop_name)

		if prop.untyped_final_value == null:
			continue
		if prop.untyped_final_value == scheme.get_default_value():
			continue

		snapshot.append(prop_name.hash())
		snapshot.append(prop.untyped_final_value)

	if not snapshot.is_empty():
		return snapshot

	return null


func network_deserialize(data: Variant) -> void:
	var data_arr := data as Array
	@warning_ignore("integer_division")
	for i: int in range(data_arr.size() / 2):
		var prop_name_hash := data_arr[i * 2 + 0] as int
		var prop_value: Variant = data_arr[i * 2 + 1]
		var prop_name := modifiable_properties.get_property_name_by_hash(prop_name_hash)
		var prop := _get_or_create_prop(prop_name)

		prop.untyped_final_value = prop_value


@rpc("authority", "reliable")
func _rpc_property_final_value(prop_name_hash: int, prop_value: Variant) -> void:
	var prop_name := modifiable_properties.get_property_name_by_hash(prop_name_hash)
	assert(prop_name != null, "Server sent unknown hash of property name")

	var prop := _get_or_create_prop(prop_name)
	prop.untyped_final_value = prop_value
	prop.changed.emit()


class Property:
	var untyped_final_value: Variant
	var mods: Array[Modifier.PropertyMod] = []

	signal changed()
