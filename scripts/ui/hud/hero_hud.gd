class_name HeroHUD
extends Node

static var instance: HeroHUD

@export var ability_icon_scene: PackedScene = preload("res://scenes/ui/elements/hero_hud_ability.tscn")
@export var modifier_icon_scene: PackedScene = preload("res://scenes/ui/elements/hero_hud_modifier.tscn")

@export var hero: Hero:
	set(val):
		if hero:
			_unlink_hero()
		hero = val
		if hero:
			_link_hero()

@onready var modifiers_bar: Container = %ModifiersBar
@onready var abilities_bar: Container = %AbilitiesBar
@onready var health_bar: TextureProgressBar = %HealthBar
@onready var health_num: Label = %HealthNumber
@onready var health_regen_num: Label = %HealthRegenNumber

var _ability_icon_map: Dictionary[Ability, HUDAbility] = { }
var _modifier_icon_map: Dictionary[Modifier, HUDModifier] = { }

var _prop_hp_regen: ModifiableFloat.FloatProperty


func _ready() -> void:
	instance = self


func _unlink_hero() -> void:
	if hero.caster:
		hero.caster.ability_added.disconnect(_on_ability_added)
		hero.caster.ability_removed.disconnect(_on_ability_removed)
		hero.modifiers.modifier_added.disconnect(_on_modifier_added)
		hero.modifiers.modifier_removing.disconnect(_on_modifier_removing)

	for icon: HUDAbility in _ability_icon_map.values():
		icon.queue_free()
	_ability_icon_map.clear()

	for icon: HUDModifier in _modifier_icon_map.values():
		icon.queue_free()
	_modifier_icon_map.clear()

	_prop_hp_regen = null


func _link_hero() -> void:
	if hero.caster:
		for i: int in range(hero.caster.get_ability_count()):
			_on_ability_added(i)

		for i: int in range(hero.modifiers.get_modifiers_count()):
			_on_modifier_added(hero.modifiers.get_modifier(i))

		hero.caster.ability_added.connect(_on_ability_added)
		hero.caster.ability_removed.connect(_on_ability_removed)
		hero.modifiers.modifier_added.connect(_on_modifier_added)
		hero.modifiers.modifier_removing.connect(_on_modifier_removing)

	_prop_hp_regen = hero.modifiers.get_float_property(&"hp_regen")


func _on_ability_added(ability_index: int) -> void:
	var ability := hero.caster.get_ability(ability_index)
	var hud_ability := ability_icon_scene.instantiate() as HUDAbility

	abilities_bar.add_child(hud_ability)
	_ability_icon_map[ability] = hud_ability
	hud_ability.ability = ability


func _on_ability_removed(ability: Ability) -> void:
	var hud_ability: HUDAbility = _ability_icon_map.get(ability)
	if not hud_ability:
		return

	_ability_icon_map.erase(ability)
	hud_ability.queue_free()


func _on_modifier_added(modifier: Modifier) -> void:
	var hud_icon := modifier_icon_scene.instantiate() as HUDModifier

	modifiers_bar.add_child(hud_icon)
	_modifier_icon_map[modifier] = hud_icon
	hud_icon.modifier = modifier


func _on_modifier_removing(modifier: Modifier) -> void:
	var hud_icon: HUDModifier = _modifier_icon_map.get(modifier)
	if not hud_icon:
		return

	_modifier_icon_map.erase(modifier)
	hud_icon.queue_free()


func _update_visual(_delta: float) -> void:
	if not hero:
		return

	if hero.health:
		health_bar.max_value = hero.health.max_health
		health_bar.value = hero.health.current_health
		health_num.text = "%d/%d" % [hero.health.current_health, hero.health.max_health]

	if _prop_hp_regen:
		health_regen_num.text = "%+.1f" % _prop_hp_regen.final_value
	else:
		health_regen_num.text = "0"


func _process(delta: float) -> void:
	_update_visual(delta)
