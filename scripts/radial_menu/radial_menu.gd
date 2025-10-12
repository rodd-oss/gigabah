

extends Control

class_name RadialMenu




@export var dead_zone:float = 0.1
@export var show_action_button := "show_radial_menu"
var hide_tween:Tween

var hovered_item:RadialMenuItemBehavior
var shown:bool = false
func _enter_tree() -> void:
	visible = !multiplayer.is_server()
	

func _ready() -> void:
	if multiplayer.is_server():return

func delay(sec:float)->Signal:
	return get_tree().create_timer(sec).timeout

func draw_segment(center: Vector2, radius_a: float, radius_b: float,radius_padding: float, start_angle: float, end_angle: float,angle_padding:float, point_count: int, color: Color)->void:
	var points: =RadialMenuUtils.create_segment_polygon(center, radius_a, radius_b,radius_padding, start_angle, end_angle,angle_padding, point_count)

	var colors := PackedColorArray()
	colors.resize(points.size())
	colors.fill(color)
	
	draw_polygon(points.slice(0,points.size()),colors)
	draw_polyline(points,color,2,true)

func to_2PI(rads:float,off:float = 0.0)->float:
	var _rads := rads-off
	if _rads<0:
		return TAU+_rads
	return _rads
	
func num()->int:
	var c := 0
	for ch:Node in get_children():
		for ch2:Node in ch.get_children():
			if ch2 is RadialMenuItemBehavior:
				c+=1
				break
	return c
	
func get_children_behavior()->Array[RadialMenuItemBehavior]:
	var out:Array[RadialMenuItemBehavior] = []
	for ch:Node in get_children():
		for ch2:Node in ch.get_children():
			if ch2 is RadialMenuItemBehavior:
				out.append(ch2)
	return out



func get_mouse_vector()->Vector2:
	return get_local_mouse_position()-size/2

func get_mouse_angle()->float:
	var vec: = get_mouse_vector()
	var off:float
	if num() == 1:
		off = 0
	else:
		off = (TAU/num()/2)+PI/2
	return to_2PI(atan2(vec.y,vec.x),-off)

func _input(event: InputEvent) -> void:

	if event.is_action_pressed("show_radial_menu"):
		shown = true
		for beh in get_children_behavior():
			beh.enter()
		if hide_tween!=null:
			hide_tween.kill()

			
	if event.is_action_released("show_radial_menu"):
		var max_exit_time:= 0.0
		for beh in get_children_behavior():
			if max_exit_time<beh.exit_speed:
				max_exit_time = beh.exit_speed
			beh.exit()
		if hide_tween!=null:
			hide_tween.kill()
		hide_tween = create_tween()
		hide_tween.tween_interval(max_exit_time)
		hide_tween.tween_callback(func()->void:shown = false)
		

	if !shown: return

	var vec := get_mouse_vector()
	var mouse_angle := get_mouse_angle()
	for beh in get_children_behavior():
		var howered: = false
		if vec.length()>size.y*dead_zone:
			if beh.has_angle(mouse_angle):
				howered = true
		beh.input(event,howered)
	

func _process(_delta: float) -> void:
	if !shown: return
	if multiplayer.is_server():return

	if get_parent() is Control:
		size = get_parent().size
	else:
		size = get_viewport().size
		
	var vec := get_mouse_vector()
	var mouse_angle := get_mouse_angle()
	for beh in get_children_behavior():

		if vec.length()>size.y*dead_zone:
			if beh.has_angle(mouse_angle):
				
				if hovered_item != beh:
					if hovered_item!=null:
						hovered_item.button_unhover()
					hovered_item = beh
					beh.button_hover()
		else:
			if hovered_item!=null:
					hovered_item.button_unhover()
			if hovered_item != null:
				hovered_item = null
		

func _draw() -> void:
	if !shown: return
	if multiplayer.is_server():return
	var center:Vector2 = size/2
	var off := (TAU/num()/2)+PI/2
	var item_angle := (TAU/num())
	var angle := -off
	
	for beh in get_children_behavior():
		beh.set_angles(to_2PI(angle,-off),to_2PI(angle+item_angle,-off))
		beh.draw_segment(center,angle,angle+item_angle)
		beh.edit_item(center,angle,angle+item_angle)
		angle+=item_angle


func _on_child_exiting_tree(node: Node) -> void:
	if hovered_item == node:
		hovered_item = null
