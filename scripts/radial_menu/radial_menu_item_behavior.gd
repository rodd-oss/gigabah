@tool
extends Node
class_name RadialMenuItemBehavior

signal on_press()
signal on_release()
signal on_hower()
signal on_unhower()
signal on_enter()
signal on_exit()

@export var color: Color = Color.AQUAMARINE
@export var hower_color: Color = Color.AQUA
@export var press_color: Color = Color.DARK_CYAN
@export var radius_padding: float = 3
@export var hower_radius_padding: float = 3
@export var angle_padding: float = 3
@export var hower_angle_padding: float = 0
@export var radius: float = 0.1
@export var radius_to_button: float = 0.25
@export var num_points: int = 50
@export var enter_speed: float = 0.5
@export var exit_speed: float = 0.1

var _hover_tween: Tween
var _unhover_tween: Tween
var _enter_tween: Tween
var _exit_tween: Tween
var _hover_state: float = 0.0
var _start_angle: float = 0.0
var _end_angle: float = 0.0
var _pressed: bool = false
var _enter_state: float = 0.0
var _howered: bool = false

func get_radial_menu() -> RadialMenu:
	var parent := get_parent()
	if not parent:
		push_error("RadialMenuItemBehavior must have a parent")
		return null
	var radial_menu := parent.get_parent()
	if !radial_menu:
		push_error("radial_menu is null")
		return null
	if not radial_menu is RadialMenu:
		push_error("RadialMenuItemBehavior must be child of child of RadialMenu")
		return null
	return radial_menu

func get_item() -> Control:
	return get_parent()

func _ready() -> void:
	if Engine.is_editor_hint(): return
	var item := get_parent() as Control
	item.visible = false

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if get_radial_menu() is not RadialMenu:
		warnings.append("Behavior must be a child of the child radial menu element")
	return warnings

func draw_segment(center: Vector2, start_angle: float, end_angle: float) -> void:
	var m := get_radial_menu()
	var c := color.lerp(hower_color, _hover_state) if !_pressed else press_color
	var _angle_padding := lerpf(0, lerpf(angle_padding, hower_angle_padding, _hover_state), _enter_state)
	var _radius_a := lerpf(0, m.size.y * radius_to_button, _enter_state)
	var _radius_b := lerpf(0, m.size.y * radius_to_button + m.size.y * radius, _enter_state)
	var _radius_padding := lerpf(0, lerpf(radius_padding, hower_radius_padding, _hover_state), _enter_state)
	m.draw_segment(center, _radius_a, _radius_b, _radius_padding, start_angle, end_angle, deg_to_rad(_angle_padding), num_points, c)
	

func edit_item(center: Vector2, start_angle: float, end_angle: float) -> void:
	var item := get_parent()
		
	var m := get_radial_menu()
	var _angle_padding := lerpf(angle_padding, hower_angle_padding, _hover_state)
	var _radius_a := lerpf(0, m.size.y * radius_to_button, _enter_state)
	var _radius_b := lerpf(0, m.size.y * radius_to_button + m.size.y * radius, _enter_state)
	var _radius_padding := lerpf(0, lerpf(radius_padding, hower_radius_padding, _hover_state), _enter_state)
	var pos := RadialMenuUtils.segment_releative_point(center, _radius_a, _radius_b, _radius_padding, start_angle, end_angle, deg_to_rad(_angle_padding), 0, 0)
	item.position = pos - item.size / 2
	

func set_angles(start_angle: float, end_angle: float) -> void:
	_start_angle = start_angle
	_end_angle = end_angle
	
func has_angle(angle: float) -> bool:
	return _start_angle <= angle && angle <= _end_angle

func click() -> void:
	_pressed = true
	on_press.emit()
	_pressed = false
	on_release.emit()

func input(event: InputEvent) -> void:
	if get_radial_menu().enable_click:
		if _howered && event.is_action_pressed("radial_menu_click"):
			_pressed = true
			on_press.emit()
			get_radial_menu().queue_redraw()
		if _pressed && event.is_action_released("radial_menu_click"):
			_pressed = false
			on_release.emit()
			get_radial_menu().queue_redraw()
		

func enter() -> void:
	on_enter.emit()
	if _enter_tween:
		_enter_tween.kill()
	if _exit_tween:
		_exit_tween.kill()
	var item := get_item()
	item.visible = true
	var tw := create_tween()
	tw.tween_method(button_enter_tween, _enter_state, 1.0, (1.0 - _enter_state) * enter_speed)
	_enter_tween = tw
	

func exit() -> void:
	_pressed = false
	_howered = false
	on_exit.emit()
	if _enter_tween:
		_enter_tween.kill()
	if _exit_tween:
		_exit_tween.kill()

	var item := get_item()
	item.visible = false
	var tw := create_tween()
	tw.tween_method(button_exit_tween, _enter_state, 0, _enter_state * exit_speed)
	_enter_tween = tw

	
func button_enter_tween(t: float) -> void:
	_enter_state = ease(t, 0.1)
	get_radial_menu().queue_redraw()

func button_exit_tween(t: float) -> void:
	_enter_state = t
	get_radial_menu().queue_redraw()
	
func button_hover() -> void:
	_howered = true
	on_hower.emit()
	
	if _unhover_tween:
		_unhover_tween.kill()
	if _hover_tween:
		_hover_tween.kill()

	var tw := create_tween()
	tw.tween_method(button_hover_tween, _hover_state, 1.0, (1.0 - _hover_state) / 6)
	_hover_tween = tw
	
	
func button_unhover() -> void:
	_howered = false
	on_unhower.emit()
	
	if _unhover_tween:
		_unhover_tween.kill()
	if _hover_tween:
		_hover_tween.kill()
	var tw := create_tween()
	tw.tween_method(button_unhover_tween, _hover_state, 0, _hover_state / 6)
	_unhover_tween = tw
	
	
func button_hover_tween(t: float) -> void:
	_hover_state = t
	get_radial_menu().queue_redraw()
	
func button_unhover_tween(t: float) -> void:
	_hover_state = t
	get_radial_menu().queue_redraw()

func _enter_tree() -> void:
	if Engine.is_editor_hint(): return
	get_radial_menu().recalc_children_behaviors()

func _exit_tree() -> void:
	if Engine.is_editor_hint(): return
	if _hover_tween:
		_hover_tween.kill()
		_hover_tween = null
	if _unhover_tween:
		_unhover_tween.kill()
		_unhover_tween = null
	if _enter_tween:
		_enter_tween.kill()
		_enter_tween = null
	if _exit_tween:
		_exit_tween.kill()
		_exit_tween = null
	get_radial_menu().recalc_children_behaviors()
