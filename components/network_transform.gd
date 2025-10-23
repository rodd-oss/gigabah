extends MultiplayerSynchronizer

class_name NetworkTransform

@onready var parent: CharacterBody3D = get_parent() as CharacterBody3D

@export var server_position: Vector3 = Vector3(NAN, NAN, NAN)
@export var server_rotation: Vector3 = Vector3(NAN, NAN, NAN)
@export var server_scale: Vector3 = Vector3(NAN, NAN, NAN)

@export var enable_interpolation: bool = true
@export var interpolation_speed: float = 18.0

var _initialized: bool = false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if parent != null:
		if multiplayer.is_server():
			server_position = parent.position
			server_rotation = parent.rotation
			server_scale = parent.scale
	else:
		printerr("NetworkPosition: Parent is null")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if !multiplayer.is_server():
		var pos_is_nan: bool = _vec3_is_nan(server_position)
		var rot_is_nan: bool = _vec3_is_nan(server_rotation)
		var scale_is_nan: bool = _vec3_is_nan(server_scale)
		if not _initialized:
			if !pos_is_nan && !rot_is_nan && !scale_is_nan:
				parent.position = server_position
				parent.rotation = server_rotation
				parent.scale = server_scale
				_initialized = true
		elif enable_interpolation:
			parent.position = parent.position.lerp(
				server_position,
				clamp(interpolation_speed * delta, 0, 1),
			)
			parent.rotation = parent.rotation.slerp(
				server_rotation,
				clamp(interpolation_speed * delta, 0, 1),
			)
			parent.scale = parent.scale.lerp(
				server_scale,
				clamp(interpolation_speed * delta, 0, 1),
			)
		else:
			parent.position = server_position
			parent.rotation = server_rotation
			parent.scale = server_scale


func _physics_process(_delta: float) -> void:
	# Only the server moves the player
	if multiplayer.is_server():
		parent.move_and_slide()
		server_position = parent.position
		server_rotation = parent.rotation
		server_scale = parent.scale


func _vec3_is_nan(vec: Vector3) -> bool:
	return is_nan(vec.x) or is_nan(vec.y) or is_nan(vec.z)
