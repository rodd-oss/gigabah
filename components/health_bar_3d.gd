extends Node3D
class_name HealthBar3D

## Визуальный индикатор здоровья в 3D пространстве

@export var max_health: float = 100.0
@export var current_health: float = 100.0
@export var bar_width: float = 1.0
@export var bar_height: float = 0.15
@export var offset_y: float = 2.5  # Высота над игроком

# Компоненты healthbar
var background: MeshInstance3D
var health_fill: MeshInstance3D
var camera: Camera3D

func _ready() -> void:
	create_health_bar()
	update_health_display()


func create_health_bar() -> void:
	"""Создаёт визуальные компоненты healthbar"""
	# Фон (тёмный)
	background = MeshInstance3D.new()
	add_child(background)
	
	var bg_mesh: QuadMesh = QuadMesh.new()
	bg_mesh.size = Vector2(bar_width, bar_height)
	background.mesh = bg_mesh
	
	var bg_material: StandardMaterial3D = StandardMaterial3D.new()
	bg_material.albedo_color = Color(0.2, 0.2, 0.2, 0.8)
	bg_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Видно с обеих сторон
	bg_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED  # Всегда смотрит на камеру
	background.material_override = bg_material
	
	# Полоска здоровья (зелёная/жёлтая/красная)
	health_fill = MeshInstance3D.new()
	add_child(health_fill)
	
	var fill_mesh: QuadMesh = QuadMesh.new()
	fill_mesh.size = Vector2(bar_width, bar_height)
	health_fill.mesh = fill_mesh
	
	var fill_material: StandardMaterial3D = StandardMaterial3D.new()
	fill_material.albedo_color = Color(0.0, 1.0, 0.0, 1.0)  # Зелёный
	fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	fill_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	health_fill.material_override = fill_material
	
	# Небольшое смещение вперёд чтобы полоска была поверх фона
	health_fill.position.z = -0.01
	
	# Позиционируем весь healthbar над игроком
	position.y = offset_y
	
	print("HealthBar3D: Created health bar")


func update_health_display() -> void:
	"""Обновляет визуальное отображение здоровья"""
	if not health_fill:
		return
	
	var health_percent: float = clamp(current_health / max_health, 0.0, 1.0)
	
	# Масштабируем полоску здоровья по X
	health_fill.scale.x = health_percent
	
	# Сдвигаем полоску влево чтобы она заполнялась слева направо
	var offset: float = bar_width * (1.0 - health_percent) * 0.5
	health_fill.position.x = -offset
	
	# Меняем цвет в зависимости от процента здоровья
	var material: StandardMaterial3D = health_fill.material_override as StandardMaterial3D
	if material:
		if health_percent > 0.6:
			material.albedo_color = Color(0.0, 1.0, 0.0, 1.0)  # Зелёный
		elif health_percent > 0.3:
			material.albedo_color = Color(1.0, 1.0, 0.0, 1.0)  # Жёлтый
		else:
			material.albedo_color = Color(1.0, 0.0, 0.0, 1.0)  # Красный


func set_health(new_health: float) -> void:
	"""Устанавливает текущее здоровье"""
	current_health = clamp(new_health, 0.0, max_health)
	update_health_display()


func set_max_health(new_max: float) -> void:
	"""Устанавливает максимальное здоровье"""
	max_health = new_max
	current_health = clamp(current_health, 0.0, max_health)
	update_health_display()


func damage(amount: float) -> void:
	"""Наносит урон"""
	set_health(current_health - amount)


func heal(amount: float) -> void:
	"""Лечит"""
	set_health(current_health + amount)
