class_name ModifierAura
extends Area3D

## You can add node with Modifier script and assign it here.
@export var modifier: Modifier

var _affected: Dictionary[Hero, Modifier] = { }
var _tree_exiting_binds: Dictionary[Hero, Callable] = { }


func _ready() -> void:
	if not multiplayer.is_server():
		return

	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _exit_tree() -> void:
	if not multiplayer.is_server():
		return

	area_entered.disconnect(_on_area_entered)
	area_exited.disconnect(_on_area_exited)

	for mod: Modifier in _affected.values():
		mod.queue_free()


func _on_area_entered(other: Area3D) -> void:
	if other is not HitBox3D:
		return

	var hitbox := other as HitBox3D
	var new_modifier := modifier.duplicate() as Modifier

	hitbox.hero.modifiers.add_modifier(new_modifier)

	var tree_exiting_bind := _on_hitbox_tree_exiting.bind(hitbox)

	_affected[hitbox.hero] = new_modifier
	_tree_exiting_binds[hitbox.hero] = tree_exiting_bind

	hitbox.tree_exiting.connect(tree_exiting_bind, CONNECT_ONE_SHOT)
	new_modifier.tree_exiting.connect(_on_modifier_tree_exiting.bind(hitbox.hero), CONNECT_ONE_SHOT)


func _on_area_exited(other: Area3D) -> void:
	if other is not HitBox3D:
		return

	var hitbox := other as HitBox3D

	if not _affected.has(hitbox.hero):
		# modifier freed earlier
		return

	var modifier_on_hero := _affected[hitbox.hero]

	modifier_on_hero.queue_free()

	var bind := _tree_exiting_binds[hitbox.hero]
	hitbox.tree_exiting.disconnect(bind)

	_affected.erase(hitbox.hero)
	_tree_exiting_binds.erase(hitbox.hero)


func _on_hitbox_tree_exiting(hitbox: HitBox3D) -> void:
	var modifier_on_hero := _affected[hitbox.hero]
	modifier_on_hero.queue_free()
	_affected.erase(hitbox.hero)
	_tree_exiting_binds.erase(hitbox.hero)


func _on_modifier_tree_exiting(hero: Hero) -> void:
	_affected.erase(hero)
	_tree_exiting_binds.erase(hero)
