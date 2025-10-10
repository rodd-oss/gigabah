extends Node3D
class_name RTSCamera3D


signal camera_zoom_changed

@onready var camera_arm: Node3D = $CameraArm
@onready var camera: Camera3D = $CameraArm/Camera3D

# === PAN (Панорамирование) ===
var is_panning: bool = false
var pan_position: Vector2 = Vector2.ZERO
var pan_speed: float = 1.0

# === EDGE SCROLLING (Движение к краям экрана) ===
@export var edge_scroll_enabled: bool = true
@export var edge_scroll_margin: int = 20  # Пиксели от края экрана
@export var edge_scroll_speed: float = 0.2

# === ZOOM ===
var zoom_distance: float = 15.0  # Текущее расстояние камеры
var zoom_min: float = 5.0  # Минимальное расстояние (приближение)
var zoom_max: float = 30.0  # Максимальное расстояние (отдаление)
var zoom_speed: float = 2.0
var zoom_smoothing: float = 10.0

# === CAMERA SETTINGS ===
var camera_angle: float = -60.0  # Угол наклона камеры (в градусах)
var camera_height_offset: float = 0.0
var camera_rotation_y: float = 0.0  # Поворот вокруг оси Y (опционально)

# === BOUNDARIES (Границы карты) ===
var boundary_enabled: bool = true
var boundary_min: Vector3 = Vector3(-50, 0, -50)
var boundary_max: Vector3 = Vector3(50, 0, 50)

# === INTERNAL ===
var target_zoom: float = 15.0
var mouse_ray_length: float = 1000.0


func _ready() -> void:
	setup_camera()
	update_camera_position()


func setup_camera() -> void:
	"""Настройка начальных параметров камеры"""
	if not camera_arm:
		camera_arm = Node3D.new()
		camera_arm.name = "CameraArm"
		add_child(camera_arm)
	
	if not camera:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		camera_arm.add_child(camera)
	
	target_zoom = zoom_distance
	camera_arm.rotation_degrees.x = camera_angle
	camera_arm.rotation_degrees.y = camera_rotation_y


func _input(event: InputEvent) -> void:
	"""Обработка ввода мыши"""
	
	# === MOUSE PAN (средняя кнопка мыши) ===
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			is_panning = event.pressed
	
	# Движение мыши для панорамирования
	if event is InputEventMouseMotion and is_panning:
		pan_position = -event.relative * pan_speed
	
	# === ZOOM (колесо мыши) ===
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_camera(-1)  # Приближение
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_camera(1)  # Отдаление


func _process(delta: float) -> void:
	"""Обновление позиции камеры каждый кадр"""
	
	# Применение панорамирования
	if is_panning and pan_position != Vector2.ZERO:
		apply_pan(delta)
	
	# Edge scrolling (движение к краям экрана)
	if edge_scroll_enabled and not is_panning:
		apply_edge_scrolling(delta)
	
	# Плавное приближение к целевому зуму
	if abs(zoom_distance - target_zoom) > 0.01:
		zoom_distance = lerp(zoom_distance, target_zoom, zoom_smoothing * delta)
		update_camera_position()
		emit_signal("camera_zoom_changed")
	
	# Сброс панорамирования
	pan_position = Vector2.ZERO
	
	# Применение границ
	if boundary_enabled:
		apply_boundaries()


func apply_edge_scrolling(delta: float) -> void:
	"""Движение камеры при подводе мыши к краям экрана"""
	var viewport: Viewport = get_viewport()
	if not viewport:
		return
	
	var mouse_pos: Vector2 = viewport.get_mouse_position()
	var viewport_size: Vector2 = viewport.get_visible_rect().size
	var scroll_vector: Vector2 = Vector2.ZERO
	
	# Проверка краев экрана
	if mouse_pos.x < edge_scroll_margin:
		scroll_vector.x = -1.0
	elif mouse_pos.x > viewport_size.x - edge_scroll_margin:
		scroll_vector.x = 1.0
	
	if mouse_pos.y < edge_scroll_margin:
		scroll_vector.y = 1.0  # Инвертировано: мышь вверху - камера вверх
	elif mouse_pos.y > viewport_size.y - edge_scroll_margin:
		scroll_vector.y = -1.0  # Инвертировано: мышь внизу - камера вниз
	
	# Применение движения
	if scroll_vector != Vector2.ZERO:
		var forward: Vector3 = -camera_arm.global_transform.basis.z
		forward.y = 0
		forward = forward.normalized()
		
		var right: Vector3 = camera_arm.global_transform.basis.x
		right.y = 0
		right = right.normalized()
		
		var move: Vector3 = (right * scroll_vector.x + forward * scroll_vector.y) * edge_scroll_speed * zoom_distance * delta * 10.0
		global_position += move


func apply_pan(_delta: float) -> void:
	"""Применение панорамирования камеры"""
	# Конвертируем 2D движение мыши в 3D движение камеры
	var forward: Vector3 = -camera_arm.global_transform.basis.z
	forward.y = 0
	forward = forward.normalized()
	
	var right: Vector3 = camera_arm.global_transform.basis.x
	right.y = 0
	right = right.normalized()
	
	var move: Vector3 = (right * pan_position.x + forward * pan_position.y) * 0.01 * zoom_distance
	global_position += move


func zoom_camera(direction: int) -> void:
	"""Изменение зума камеры"""
	target_zoom += direction * zoom_speed
	target_zoom = clamp(target_zoom, zoom_min, zoom_max)


func update_camera_position() -> void:
	"""Обновление позиции камеры относительно рычага"""
	if camera:
		# Камера находится позади и выше точки фокуса
		camera.position = Vector3(0, 0, zoom_distance)


func apply_boundaries() -> void:
	"""Ограничение движения камеры в пределах карты"""
	global_position.x = clamp(global_position.x, boundary_min.x, boundary_max.x)
	global_position.z = clamp(global_position.z, boundary_min.z, boundary_max.z)
	global_position.y = clamp(global_position.y, boundary_min.y, boundary_max.y)


func set_boundaries(min_bounds: Vector3, max_bounds: Vector3) -> void:
	"""Установка границ карты"""
	boundary_min = min_bounds
	boundary_max = max_bounds
	boundary_enabled = true


func get_mouse_position_3d() -> Vector3:
	"""Получение 3D позиции мыши на плоскости земли через raycast"""
	var viewport: Viewport = get_viewport()
	if not viewport:
		return Vector3.ZERO
	
	var mouse_pos: Vector2 = viewport.get_mouse_position()
	return raycast_to_ground(mouse_pos)


func raycast_to_ground(screen_pos: Vector2) -> Vector3:
	"""Raycast от камеры к плоскости земли (y = 0)"""
	if not camera:
		return Vector3.ZERO
	
	var from: Vector3 = camera.project_ray_origin(screen_pos)
	var direction: Vector3 = camera.project_ray_normal(screen_pos)
	
	# Пересечение с плоскостью y = 0 (земля)
	var plane: Plane = Plane(Vector3.UP, 0)
	var intersection: Variant = plane.intersects_ray(from, direction)
	
	if intersection:
		return intersection as Vector3
	
	return Vector3.ZERO


func focus_position(target_position: Vector3) -> void:
	"""Фокусировка камеры на определенной позиции"""
	global_position = target_position
	global_position.y = camera_height_offset


func reset() -> void:
	"""Сброс камеры к начальным настройкам"""
	global_position = Vector3.ZERO
	zoom_distance = 15.0
	target_zoom = 15.0
	update_camera_position()
