class_name HUDAbility
extends Control

@export var tooltip_scene := preload("res://scenes/ui/elements/ability_tooltip.tscn")

@export var ability: Ability:
	set(val):
		if ability:
			_unlink_ability()

		ability = val

		if ability:
			_link_ability()
			_update_visual()
			call_deferred(&"_set_icon_texture")

@onready var ability_icon: TextureRect = %AbilityIcon
@onready var cooldown_bar: TextureProgressBar = %CooldownBar
@onready var cooldown_num: Label = %CooldownNumber
@onready var casting_bar: TextureProgressBar = %CastingBar

var _prev_cd := 0.0
var _casting := false


func _link_ability() -> void:
	ability.icon_path_changed.connect(_set_icon_texture)
	ability.start_casting.connect(_on_start_casting)
	ability.cast_end.connect(_on_end_casting)


func _unlink_ability() -> void:
	ability.icon_path_changed.disconnect(_set_icon_texture)
	ability.start_casting.disconnect(_on_start_casting)
	ability.cast_end.disconnect(_on_end_casting)


func _on_start_casting() -> void:
	var cfg := ability._get_cast_config()
	if cfg:
		casting_bar.max_value = cfg.cast_point
		casting_bar.value = 0.0
		casting_bar.visible = true

	_casting = true


func _on_end_casting(result: Ability.CastResult) -> void:
	var cfg := ability._get_cast_config()
	if cfg:
		casting_bar.value = 0.0
		casting_bar.visible = false

	_casting = false


func _set_icon_texture() -> void:
	var texture_path := ability.icon_path
	if texture_path.is_empty():
		ability_icon.texture = null
		return

	var res := load(texture_path)
	if not res or res is not Texture2D:
		ability_icon.texture = null
		return

	ability_icon.texture = res as Texture2D


func _update_visual(delta: float = 0.0) -> void:
	if not ability or multiplayer.is_server():
		return

	var cd := ability.cooldown
	if cd > _prev_cd:
		cooldown_bar.max_value = cd
	_prev_cd = cd

	if cd > 0.0:
		cooldown_bar.value = ability.cooldown
		cooldown_num.text = Utils.get_human_readable_duration_short(cd)

		cooldown_bar.visible = true
		cooldown_num.visible = true
	else:
		cooldown_bar.visible = false
		cooldown_num.visible = false

	var cfg := ability._get_cast_config()
	if cfg and _casting:
		casting_bar.value += delta


func _process(delta: float) -> void:
	_update_visual(delta)


func _make_custom_tooltip(_for_text: String) -> Object:
	var tooltip := tooltip_scene.instantiate() as AbilityTooltip
	tooltip.ability = ability

	var tooltip_position := tooltip as TooltipPosition
	tooltip_position.source_control = self
	tooltip_position.tooltip_side = SIDE_TOP
	tooltip_position.spacing = 5

	return tooltip
