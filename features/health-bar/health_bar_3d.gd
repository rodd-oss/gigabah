extends Node3D
class_name HealthBar3D

## 3D Health bar that displays above game objects
## Uses mesh instances to render in 3D space

@onready var background: MeshInstance3D = $Background
@onready var fill: MeshInstance3D = $Fill

@export var bar_width: float = 1.0
@export var bar_height: float = 0.1
@export var background_color: Color = Color(0.2, 0.2, 0.2, 0.8)
@export var fill_color: Color = Color(0.0, 0.8, 0.0, 1.0)
@export var low_health_color: Color = Color(0.8, 0.0, 0.0, 1.0)
@export var low_health_threshold: float = 0.3

var current_health: int = 100
var max_health: int = 100

func _ready() -> void:
	_setup_health_bar()

## Update the health bar display
func update_health(new_health: int, new_max_health: int) -> void:
	current_health = new_health
	max_health = new_max_health
	_update_fill()

## Setup initial health bar appearance
func _setup_health_bar() -> void:
	if not background or not fill:
		push_error("HealthBar3D: Background or Fill node not found!")
		return
	
	# Create quad meshes
	var bg_mesh: QuadMesh = QuadMesh.new()
	bg_mesh.size = Vector2(bar_width, bar_height)
	background.mesh = bg_mesh
	
	var fill_mesh: QuadMesh = QuadMesh.new()
	fill_mesh.size = Vector2(bar_width, bar_height)
	fill.mesh = fill_mesh
	
	# Create materials for background
	var bg_material: StandardMaterial3D = StandardMaterial3D.new()
	bg_material.albedo_color = background_color
	bg_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	bg_material.no_depth_test = true
	bg_material.disable_receive_shadows = true
	background.material_override = bg_material
	background.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	# Rotate to face upward (visible from top-down camera)
	background.rotation_degrees = Vector3(-45, 0, 0)
	
	# Create materials for fill
	var fill_material: StandardMaterial3D = StandardMaterial3D.new()
	fill_material.albedo_color = fill_color
	fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	fill_material.no_depth_test = true
	fill_material.disable_receive_shadows = true
	fill.material_override = fill_material
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	# Rotate to face upward (visible from top-down camera)
	fill.rotation_degrees = Vector3(-45, 0, 0)
	
	# Position fill slightly in front of background
	fill.position.z = -0.01
	
	_update_fill()

## Update fill bar width and color based on current health
func _update_fill() -> void:
	var health_percentage: float = float(current_health) / float(max_health)
	health_percentage = clampf(health_percentage, 0.0, 1.0)
	
	# Update fill mesh size
	var fill_quad: QuadMesh = fill.mesh as QuadMesh
	if fill_quad:
		fill_quad.size = Vector2(bar_width * health_percentage, bar_height)
	
	# Position fill on left edge
	fill.position.x = - (bar_width * (1.0 - health_percentage)) / 2.0
	
	# Change color based on health percentage
	if fill.material_override:
		if health_percentage <= low_health_threshold:
			fill.material_override.albedo_color = fill_color.lerp(low_health_color, 1.0 - (health_percentage / low_health_threshold))
		else:
			fill.material_override.albedo_color = fill_color
