extends MultiplayerSynchronizer

class_name NetworkTransform

@export var entity: Node3D

@export var server_position: Vector3 = Vector3(NAN, NAN, NAN)
@export var server_rotation: Vector3 = Vector3(NAN, NAN, NAN)
@export var server_scale: Vector3 = Vector3(NAN, NAN, NAN)

@export var enable_interpolation: bool = true
@export var interpolation_speed: float = 18.0

var _initialized: bool = false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if entity != null:
		if multiplayer.is_server():
			server_position = entity.position
			server_rotation = entity.rotation
			server_scale = entity.scale
	else:
		printerr("NetworkPosition: Parent is null")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if !multiplayer.is_server():
		var pos_is_nan: bool = _vec3_is_nan(server_position)
		var rot_is_nan: bool = _vec3_is_nan(server_rotation)
		var scale_is_nan: bool = _vec3_is_nan(server_scale)

		if !_initialized:
			entity.visible = false
		else:
			entity.visible = true

		if not _initialized:
			if !pos_is_nan && !rot_is_nan && !scale_is_nan:
				entity.position = server_position
				entity.rotation = server_rotation
				entity.scale = server_scale
				_initialized = true
		elif enable_interpolation:
			entity.position = entity.position.lerp(
				server_position,
				clamp(interpolation_speed * delta, 0, 1),
			)
			entity.rotation = entity.rotation.slerp(
				server_rotation,
				clamp(interpolation_speed * delta, 0, 1),
			)
			entity.scale = entity.scale.lerp(
				server_scale,
				clamp(interpolation_speed * delta, 0, 1),
			)
		else:
			entity.position = server_position
			entity.rotation = server_rotation
			entity.scale = server_scale


func _physics_process(_delta: float) -> void:
	if multiplayer.is_server():
		server_position = entity.position
		server_rotation = entity.rotation
		server_scale = entity.scale


func _vec3_is_nan(vec: Vector3) -> bool:
	return is_nan(vec.x) or is_nan(vec.y) or is_nan(vec.z)
