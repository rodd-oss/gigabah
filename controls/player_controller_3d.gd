extends Node
class_name PlayerController3D


signal move_command_issued(target_position: Vector3)

@export var camera: RTSCamera3D = null
@export var ping_scene: PackedScene = null  # Сцена визуального пинга
@export var auto_select_own_player: bool = true  # Автовыбор своего игрока

var selected_unit: Node3D = null
var current_ping: Node3D = null
var own_player_id: int = -1


func _ready() -> void:
	if not camera:
		var cameras: Array[Node] = get_tree().get_nodes_in_group("rts_camera")
		if cameras.size() > 0:
			camera = cameras[0] as RTSCamera3D
	
	# Получаем ID своего игрока
	own_player_id = multiplayer.get_unique_id()
	print("PlayerController: Own player ID = ", own_player_id)
	
	# Даем камере время инициализироваться
	await get_tree().process_frame
	
	# Автоматически выбираем своего игрока
	if auto_select_own_player:
		await get_tree().create_timer(1.0).timeout
		auto_select_player()


func auto_select_player() -> void:
	"""Автоматически выбрать своего игрока"""
	var units: Array[Node] = get_tree().get_nodes_in_group("units")
	print("PlayerController: Looking for own player among ", units.size(), " units")
	
	for unit: Node in units:
		if unit is Node3D:
			# Проверяем имя узла - оно должно соответствовать ID игрока
			var unit_id: int = unit.name.to_int()
			if unit_id == own_player_id:
				select_unit(unit as Node3D)
				print("PlayerController: Auto-selected own player: ", unit.name)
				return
	
	print("PlayerController: WARNING - Own player not found!")


func _input(event: InputEvent) -> void:
	"""Обработка кликов мыши"""
	
	if event is InputEventMouseButton and not event.pressed:
		match event.button_index:
			# ПКМ - Приказ на движение (ЛКМ больше не используется для выбора)
			MOUSE_BUTTON_RIGHT:
				handle_right_click()


func handle_right_click() -> void:
	"""Обработка правого клика - приказ на движение"""
	if not camera:
		print("PlayerController: Camera not found!")
		return
	
	var target_position: Vector3 = camera.get_mouse_position_3d()
	
	print("PlayerController: RMB clicked at ", target_position)
	
	if selected_unit:
		print("PlayerController: Issuing move command to ", selected_unit.name)
		issue_move_command(target_position)
		show_ping_at_position(target_position)
	else:
		print("PlayerController: No unit selected!")


func select_unit(unit: Node3D) -> void:
	"""Выбор юнита (только для внутреннего использования)"""
	selected_unit = unit
	print("PlayerController: Selected unit ", unit.name)


func issue_move_command(target_position: Vector3) -> void:
	"""Отдать приказ на движение выбранному юниту"""
	if not selected_unit:
		return
	
	# Проверка наличия метода движения
	if selected_unit.has_method("move_to"):
		selected_unit.move_to(target_position)
		emit_signal("move_command_issued", target_position)
		print("PlayerController: move_to() called on ", selected_unit.name)
	elif selected_unit.has_method("set_target_position"):
		selected_unit.set_target_position(target_position)
		emit_signal("move_command_issued", target_position)
		print("PlayerController: set_target_position() called on ", selected_unit.name)
	else:
		print("PlayerController: Unit has no movement methods!")


func show_ping_at_position(position: Vector3) -> void:
	"""Показать визуальный пинг в точке назначения"""
	# Удалить предыдущий пинг
	if current_ping and is_instance_valid(current_ping):
		current_ping.queue_free()
	
	# Создать новый пинг
	if ping_scene:
		current_ping = ping_scene.instantiate()
		get_tree().current_scene.add_child(current_ping)
		current_ping.global_position = position
		
		print("PlayerController: Ping shown at ", position)
		
		# Если у пинга есть метод play() - запустить анимацию
		if current_ping.has_method("play"):
			current_ping.play()
	else:
		print("PlayerController: ping_scene is not set!")


func get_selected_unit() -> Node3D:
	"""Получить текущий выбранный юнит"""
	return selected_unit


func has_selected_unit() -> bool:
	"""Проверка наличия выбранного юнита"""
	return selected_unit != null
