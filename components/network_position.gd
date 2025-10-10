extends MultiplayerSynchronizer
class_name NetworkPosition

@onready var parent: CharacterBody3D = get_parent() as CharacterBody3D

@export var server_position: Vector3 = Vector3.ZERO
@export var server_rotation_y: float = 0.0

@export var enable_interpolation: bool = true
@export var interpolation_speed: float = 18.0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if parent != null:
		server_position = parent.position
		server_rotation_y = parent.rotation.y
	else:
		printerr("NetworkPosition: Parent is null")


# Called every frame. 'delta' is the elapsed time since the previous frame.
# func _process(delta: float) -> void:
	# if !multiplayer.is_server():
	# 	parent.position = parent.position.lerp(server_position, clamp(interpolation_speed * delta, 0, 1))

func _physics_process(delta: float) -> void:
	# Only the server moves the player
	if multiplayer.is_server():
		parent.move_and_slide()
		server_position = parent.position
		server_rotation_y = parent.rotation.y
	else:
		if enable_interpolation:
			parent.position = parent.position.lerp(server_position, clamp(interpolation_speed * delta, 0, 1))
			parent.rotation.y = lerp_angle(parent.rotation.y, server_rotation_y, clamp(interpolation_speed * delta, 0, 1))
		else:
			parent.position = server_position
			parent.rotation.y = server_rotation_y
