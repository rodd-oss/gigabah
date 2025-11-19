class_name HUDModifier
extends Control

@export var modifier: Modifier:
	set(val):
		modifier = val
		_link_modifier()
		_update_visual()
		call_deferred(&"_set_icon_texture")

@onready var modifier_icon: TextureRect = %ModifierIcon
@onready var expire_bar: TextureProgressBar = %ExpireBar

var _prev_expire_time := 0.0


func _link_modifier() -> void:
	modifier.icon_path_changed.connect(_set_icon_texture)


func _set_icon_texture() -> void:
	var texture_path := modifier.icon_path
	if texture_path.is_empty():
		modifier_icon.texture = null
		return

	var res := load(texture_path)
	if not res or res is not Texture2D:
		modifier_icon.texture = null
		return

	modifier_icon.texture = res as Texture2D


func _update_visual() -> void:
	if not modifier or multiplayer.is_server():
		return

	var expire_time := modifier.expire_time
	if expire_time > _prev_expire_time:
		expire_bar.max_value = expire_time
	_prev_expire_time = expire_time

	if expire_time > 0.0:
		expire_bar.value = modifier.expire_time

		expire_bar.visible = true
	else:
		expire_bar.visible = false


func _process(_delta: float) -> void:
	_update_visual()


func _make_custom_tooltip(_for_text: String) -> Object:
	var tooltip := Label.new()

	var text := "modifier_%s" % modifier.get_script().get_global_name()
	tooltip.text = text

	tooltip.set_script(TooltipPosition)
	var tooltip_position := tooltip as Node as TooltipPosition
	tooltip_position.source_control = self
	tooltip_position.tooltip_side = SIDE_TOP
	tooltip_position.spacing = 5

	return tooltip
