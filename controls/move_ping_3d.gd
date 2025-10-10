extends Node3D
class_name MovePing3D

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null

@export var ping_duration: float = 1.5  # Длительность анимации
@export var ping_color: Color = Color(0.2, 0.8, 0.2, 0.8)  # Зеленый
@export var ping_size: float = 1.0

var time_elapsed: float = 0.0
var is_playing: bool = false


func _ready() -> void:
	setup_mesh()
	play()


func setup_mesh() -> void:
	"""Создание меша для пинга (кольцо/круг)"""
	if not mesh_instance:
		mesh_instance = MeshInstance3D.new()
		add_child(mesh_instance)
	
	# Создаем плоский круг (цилиндр с маленькой высотой)
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = ping_size
	mesh.bottom_radius = ping_size
	mesh.height = 0.05
	mesh.radial_segments = 32
	
	mesh_instance.mesh = mesh
	
	# Создаем материал
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = ping_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.disable_receive_shadows = true
	
	mesh_instance.material_override = material
	
	# Поворачиваем чтобы круг был параллелен земле
	mesh_instance.rotation_degrees.x = 0


func play() -> void:
	"""Запуск анимации пинга"""
	is_playing = true
	time_elapsed = 0.0


func _process(delta: float) -> void:
	if not is_playing:
		return
	
	time_elapsed += delta
	
	# Нормализованное время (0 to 1)
	var progress: float = time_elapsed / ping_duration
	
	if progress >= 1.0:
		# Анимация завершена - удаляем пинг
		queue_free()
		return
	
	# Анимация: пульсация + исчезновение
	animate_ping(progress)


func animate_ping(progress: float) -> void:
	"""Анимация пинга: пульсация и fade out"""
	
	# Пульсация размера (sin волна)
	var pulse: float = 1.0 + sin(progress * PI * 4) * 0.2
	mesh_instance.scale = Vector3(pulse, 1.0, pulse)
	
	# Fade out (исчезновение к концу)
	var alpha: float = 1.0 - pow(progress, 2)  # Квадратичное затухание
	
	# Обновление прозрачности материала
	if mesh_instance.material_override:
		var material: StandardMaterial3D = mesh_instance.material_override as StandardMaterial3D
		if material:
			var color: Color = ping_color
			color.a = alpha * ping_color.a
			material.albedo_color = color


func set_color(color: Color) -> void:
	"""Установка цвета пинга"""
	ping_color = color
	if mesh_instance and mesh_instance.material_override:
		var material: StandardMaterial3D = mesh_instance.material_override as StandardMaterial3D
		if material:
			material.albedo_color = color


func set_size(size: float) -> void:
	"""Установка размера пинга"""
	ping_size = size
	if mesh_instance and mesh_instance.mesh:
		var mesh: CylinderMesh = mesh_instance.mesh as CylinderMesh
		if mesh:
			mesh.top_radius = size
			mesh.bottom_radius = size
