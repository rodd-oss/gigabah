extends CharacterBody3D

@export var SPEED: float = 5.0

@export var camera: Camera3D = null

# === RTS CONTROL ===
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D if has_node("NavigationAgent3D") else null
var target_position: Vector3 = Vector3.ZERO
var is_moving_to_target: bool = false
var use_simple_movement: bool = true  # Простое движение без навигации
@export var force_simple_movement: bool = true  # Принудительно использовать простое движение

# === DIRECTION INDICATOR ===
@onready var direction_indicator: MeshInstance3D = null

# === HEALTH SYSTEM ===
@export var max_health: float = 100.0
var current_health: float = 100.0
var health_bar: Node3D = null

func _ready() -> void:
	# Добавляем в группу units для RTS контроллера
	add_to_group("units")
	print("Player: Added to 'units' group, name = ", name)
	
	# Создаём индикатор направления
	create_direction_indicator()
	
	# Создаём healthbar
	create_health_bar()
	
	# Настройка навигационного агента
	if nav_agent:
		nav_agent.target_position = global_position
		print("Player: NavigationAgent3D found and configured")
		
		# Проверяем принудительное простое движение
		if force_simple_movement:
			use_simple_movement = true
			print("Player: Force simple movement enabled")
		else:
			# Проверяем наличие навигационной карты
			await get_tree().create_timer(0.5).timeout
			var nav_map: RID = nav_agent.get_navigation_map()
			if nav_map.is_valid():
				print("Player: Navigation map is valid")
				use_simple_movement = false
			else:
				print("Player: WARNING - No navigation map found! Using simple movement.")
				use_simple_movement = true
	else:
		print("Player: WARNING - NavigationAgent3D not found! Using simple movement.")
		use_simple_movement = true


func create_direction_indicator() -> void:
	"""Создаёт визуальный индикатор направления взгляда игрока"""
	# Создаём узел для индикатора
	direction_indicator = MeshInstance3D.new()
	add_child(direction_indicator)
	
	# Создаём конусообразную стрелку
	var cone_mesh: CylinderMesh = CylinderMesh.new()
	cone_mesh.top_radius = 0.0  # Острый верх
	cone_mesh.bottom_radius = 0.3  # Широкое основание
	cone_mesh.height = 0.8
	
	direction_indicator.mesh = cone_mesh
	
	# Создаём яркий материал для индикатора
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.8, 0.0, 0.8)  # Жёлто-оранжевый полупрозрачный
	material.emission_enabled = true
	material.emission = Color(1.0, 0.8, 0.0)
	material.emission_energy_multiplier = 2.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	direction_indicator.material_override = material
	
	# Позиционируем индикатор впереди игрока на уровне земли
	direction_indicator.position = Vector3(0, 0.4, -1.0)  # Впереди на 1 метр
	# Поворачиваем конус острым концом вперёд (конус направлен по умолчанию вверх, поворачиваем на 90 градусов)
	direction_indicator.rotation_degrees = Vector3(-90, 0, 0)
	
	print("Player: Direction indicator created")


func create_health_bar() -> void:
	"""Создаёт полоску здоровья над игроком"""
	# Загружаем скрипт HealthBar3D
	var health_bar_script: Script = load("res://components/health_bar_3d.gd")
	
	# Создаём экземпляр healthbar
	health_bar = Node3D.new()
	health_bar.set_script(health_bar_script)
	add_child(health_bar)
	
	# Устанавливаем начальное здоровье
	health_bar.max_health = max_health
	health_bar.current_health = current_health
	
	print("Player: Health bar created")


func _enter_tree() -> void:
	# Always set authority to server (ID 1)
	set_multiplayer_authority(1)
	if multiplayer.get_unique_id() == 1:
		# Server does not need to set camera
		return
	if name.to_int() == multiplayer.get_unique_id():
		if camera:
			camera.make_current()

func _physics_process(delta: float) -> void:
	# Клиент больше не отправляет WASD ввод - только RTS управление через контроллер
	
	if multiplayer.is_server():
		# === RTS MOVEMENT ===
		if is_moving_to_target:
			if use_simple_movement:
				process_simple_movement(delta)
			elif nav_agent:
				process_rts_movement(delta)
		else:
			# Игрок стоит на месте
			if not is_on_floor():
				velocity += get_gravity() * delta
			else:
				velocity.y = 0
			
			velocity.x = 0
			velocity.z = 0
		
		move_and_slide()


func process_simple_movement(delta: float) -> void:
	"""Простое движение напрямую к точке (без навигации)"""
	# Применяем гравитацию
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0
	
	# Вычисляем направление к цели
	var direction: Vector3 = (target_position - global_position)
	direction.y = 0  # Игнорируем вертикальную составляющую
	var distance: float = direction.length()
	
	# Проверяем достижение цели
	if distance < 0.5:
		is_moving_to_target = false
		velocity.x = 0
		velocity.z = 0
		print("Player: Reached target (simple movement)")
		return
	
	direction = direction.normalized()
	
	# Двигаемся к цели
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED
	
	# Поворачиваемся в направлении движения
	if direction.length() > 0.01:
		var target_rotation: float = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, delta * 10.0)


func process_rts_movement(delta: float) -> void:
	"""Обработка движения к целевой точке (RTS с навигацией)"""
	if not nav_agent:
		print("Player: ERROR - nav_agent is null in process_rts_movement!")
		return
	
	# Применяем гравитацию
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0
	
	# Проверяем готовность навигации
	var is_finished: bool = nav_agent.is_navigation_finished()
	var target_pos: Vector3 = nav_agent.target_position
	var distance_to_target: float = global_position.distance_to(target_pos)
	
	print("Player: Nav status - finished: ", is_finished, ", distance: ", distance_to_target)
	
	if not is_finished:
		# Получаем следующую позицию от навигационного агента
		var next_position: Vector3 = nav_agent.get_next_path_position()
		var direction: Vector3 = (next_position - global_position).normalized()
		
		print("Player: Next nav position: ", next_position)
		print("Player: Direction: ", direction)
		
		# Двигаемся к цели
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		
		# Поворачиваемся в направлении движения
		if direction.length() > 0.01:
			var look_dir: Vector3 = direction
			look_dir.y = 0
			if look_dir.length() > 0.01:
				var target_rotation: float = atan2(look_dir.x, look_dir.z)
				rotation.y = lerp_angle(rotation.y, target_rotation, delta * 10.0)
		
		print("Player: Following nav path, velocity: ", velocity)
	else:
		# Проверяем достижение цели
		is_moving_to_target = false
		velocity.x = 0
		velocity.z = 0
		print("Player: Reached target destination (nav)")


# === RTS METHODS ===
func move_to(target: Vector3) -> void:
	"""Приказ двигаться к точке (вызывается RTS контроллером)"""
	print("Player: move_to() called - target: ", target)
	print("Player: Current position: ", global_position)
	print("Player: multiplayer.is_server(): ", multiplayer.is_server())
	print("Player: name.to_int(): ", name.to_int())
	print("Player: multiplayer.get_unique_id(): ", multiplayer.get_unique_id())
	
	# Если это клиент - отправляем команду на сервер
	if not multiplayer.is_server():
		print("Player: Sending move command to server via RPC")
		rpc_move_to.rpc_id(1, target)
		return
	
	# Код ниже выполняется только на сервере
	_execute_move_to(target)


@rpc("any_peer", "call_remote", "reliable")
func rpc_move_to(target: Vector3) -> void:
	"""RPC метод для передачи команды движения на сервер"""
	print("Player: RPC move_to received on server")
	if multiplayer.is_server():
		_execute_move_to(target)


func _execute_move_to(target: Vector3) -> void:
	"""Внутренний метод выполнения движения (только на сервере)"""
	target_position = target
	
	if use_simple_movement:
		# Простое движение без навигации
		is_moving_to_target = true
		print("Player: Started simple movement to ", target)
	elif nav_agent:
		# Движение с навигацией
		nav_agent.target_position = target
		is_moving_to_target = true
		print("Player: Navigation started to ", target)
	else:
		print("Player: ERROR - Cannot move, no movement method available!")


func set_target_position(target: Vector3) -> void:
	"""Альтернативный метод установки цели"""
	move_to(target)


# === HEALTH METHODS ===
func take_damage(amount: float) -> void:
	"""Получить урон"""
	if not multiplayer.is_server():
		return
	
	current_health = max(0, current_health - amount)
	
	# Обновляем healthbar
	if health_bar and health_bar.has_method("set_health"):
		health_bar.set_health(current_health)
	
	print("Player: Took ", amount, " damage. Health: ", current_health, "/", max_health)
	
	# Проверка смерти
	if current_health <= 0:
		die()


func heal(amount: float) -> void:
	"""Вылечиться"""
	if not multiplayer.is_server():
		return
	
	current_health = min(max_health, current_health + amount)
	
	# Обновляем healthbar
	if health_bar and health_bar.has_method("set_health"):
		health_bar.set_health(current_health)
	
	print("Player: Healed ", amount, ". Health: ", current_health, "/", max_health)


func die() -> void:
	"""Обработка смерти игрока"""
	print("Player: Died!")
	# Здесь можно добавить логику смерти (анимация, респавн и т.д.)
