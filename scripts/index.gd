extends Node3D
## Главная игровая сцена с RTS управлением

@onready var rts_camera: RTSCamera3D = $RTSCamera3D
@onready var player_controller: PlayerController3D = $PlayerController


func _ready() -> void:
	# Связываем контроллер с камерой
	if player_controller and rts_camera:
		player_controller.camera = rts_camera
		print("Index: PlayerController linked to RTSCamera")
	else:
		print("Index: WARNING - Camera or Controller not found!")
	
	# Настройка границ камеры для текущей карты
	if rts_camera:
		rts_camera.set_boundaries(
			Vector3(-15, 0, -15),  # Минимум
			Vector3(15, 0, 15)     # Максимум
		)
		
		# Установка начальной позиции камеры
		rts_camera.global_position = Vector3(0, 0, 0)
		
		# Активируем RTS камеру
		if rts_camera.camera:
			rts_camera.camera.make_current()
			print("Index: RTS Camera activated")
	
	# Отключаем камеры игроков
	await get_tree().create_timer(0.5).timeout
	disable_player_cameras()


func disable_player_cameras() -> void:
	"""Отключаем камеры на игроках, используем общую RTS камеру"""
	var players: Array[Node] = get_tree().get_nodes_in_group("units")
	print("Index: Found ", players.size(), " units")
	
	for player: Node in players:
		if player.has_node("Camera3D"):
			var cam: Camera3D = player.get_node("Camera3D") as Camera3D
			if cam:
				cam.current = false
				print("Index: Disabled camera on ", player.name)
