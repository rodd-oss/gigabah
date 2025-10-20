extends Control

class_name RadialMenu

signal on_show()
signal on_begin_hiding()
signal on_hide()

@export var dead_zone: float = 0.005
@export var show_action_button := "show_radial_menu"
@export var click_selected_on_exit := false
@export var enable_click := true

var _hide_tween: Tween

var _hovered_item: RadialMenuItemBehavior
var _shown: bool = false
var _last_mouse_mode: Input.MouseMode
var _last_mouse_pos: Vector2
var _mouse_rel_pos: Vector2 = Vector2.ZERO
var _children_behaviors: Array[RadialMenuItemBehavior] = []
var _is_local: bool = false


func _enter_tree() -> void:
	if Engine.is_editor_hint(): return
	# Only show on clients, not on server or other players
	if get_parent().name.to_int() != multiplayer.get_unique_id():
		queue_free()
		return
	_is_local = true
	visible = !multiplayer.is_server()

func _exit_tree() -> void:
	if Engine.is_editor_hint(): return
	if _hide_tween:
		_hide_tween.kill()
		_hide_tween = null

func delay(sec: float) -> Signal:
	return get_tree().create_timer(sec).timeout

func draw_segment(center: Vector2, radius_a: float, radius_b: float, radius_padding: float, start_angle: float, end_angle: float, angle_padding: float, point_count: int, color: Color) -> void:
	var points := RadialMenuUtils.create_segment_polygon(center, radius_a, radius_b, radius_padding, start_angle, end_angle, angle_padding, point_count)

	var colors := PackedColorArray()
	colors.resize(points.size())
	colors.fill(color)
	
	draw_polygon(points.slice(0, points.size()), colors)
	draw_polyline(points, color, 2, true)

func to_2PI(rads: float, off: float = 0.0) -> float:
	var _rads := rads - off
	if _rads < 0:
		return TAU + _rads
	return _rads
	
func num() -> int:
	return _children_behaviors.size()
	
func _recalc_children_behaviors() -> void:
	if !_is_local: return
	var bhs: Array[RadialMenuItemBehavior] = []
	for ch: Node in get_children():
		for ch2: Node in ch.get_children():
			if ch2 is RadialMenuItemBehavior:
				bhs.append(ch2)
				continue
	_children_behaviors = bhs
	
func recalc_children_behaviors() -> void:
	call_deferred("_recalc_children_behaviors")

func get_children_behavior() -> Array[RadialMenuItemBehavior]:
	return _children_behaviors

func get_mouse_vector() -> Vector2:
	return _mouse_rel_pos

func get_mouse_angle() -> float:
	var vec := get_mouse_vector()
	var off: float
	if num() == 1:
		off = 0
	else:
		off = (TAU / num() / 2) + PI / 2
	return to_2PI(atan2(vec.y, vec.x), -off)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_rel_pos = event.relative
	
	if event.is_action_pressed("show_radial_menu"):
		_last_mouse_mode = Input.mouse_mode
		_last_mouse_pos = get_viewport().get_mouse_position()
		
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_shown = true
		for beh in get_children_behavior():
			beh.enter()
		if _hide_tween:
			_hide_tween.kill()
		on_show.emit()
		

	if _shown && event.is_action_released("show_radial_menu"):
		Input.mouse_mode = _last_mouse_mode
		Input.warp_mouse(_last_mouse_pos)
		_last_mouse_pos = Vector2.ZERO
		
		if _hovered_item:
			if click_selected_on_exit:
				_hovered_item.click()
			_hovered_item.button_unhover()
		if _hovered_item:
			_hovered_item = null
		var max_exit_time := 0.0
		for beh in get_children_behavior():
			if max_exit_time < beh.exit_speed:
				max_exit_time = beh.exit_speed
			beh.exit()
		if _hide_tween:
			_hide_tween.kill()
		_hide_tween = create_tween()
		_hide_tween.tween_interval(max_exit_time)
		_hide_tween.tween_callback(func() -> void:
			_shown = false
			on_hide.emit()
			)
		on_begin_hiding.emit()
		
	if !_shown: return
	
	for beh in get_children_behavior():
		beh.input(event)
	
	accept_event()
	

func _process(_delta: float) -> void:
	if !_shown: return
	if multiplayer.is_server(): return

	if get_parent() is Control:
		size = get_parent().size
	else:
		size = get_viewport().size
	
	var vec := get_mouse_vector()
	var mouse_angle := get_mouse_angle()
	for beh in get_children_behavior():
		if vec.length() > size.y * dead_zone:
			if beh.has_angle(mouse_angle):
				if _hovered_item != beh:
					if _hovered_item:
						_hovered_item.button_unhover()
					_hovered_item = beh
					beh.button_hover()


func _draw() -> void:
	if !_shown: return
	if multiplayer.is_server(): return
	var center: Vector2 = size / 2
	var off := (TAU / num() / 2) + PI / 2
	var item_angle := (TAU / num())
	var angle := -off
	
	for beh in get_children_behavior():
		beh.set_angles(to_2PI(angle, -off), to_2PI(angle + item_angle, -off))
		beh.draw_segment(center, angle, angle + item_angle)
		beh.edit_item(center, angle, angle + item_angle)
		angle += item_angle

func _on_child_exiting_tree(node: Node) -> void:
	if _hovered_item == node:
		_hovered_item = null

func _on_child_order_changed() -> void:
	recalc_children_behaviors()
