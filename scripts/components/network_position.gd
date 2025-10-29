extends MultiplayerSynchronizer

class_name NetworkPosition

@onready var parent: CharacterBody3D = get_parent() as CharacterBody3D

@export var server_position: Vector3 = Vector3(NAN, NAN, NAN)

@export var enable_interpolation: bool = true
@export var interpolation_speed: float = 18.0

var _initialized: bool = false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if parent != null:
		if multiplayer.is_server():
			server_position = parent.position
	else:
		printerr("NetworkPosition: Parent is null")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if !multiplayer.is_server():
		var pos_is_nan: bool = is_nan(server_position.x) or is_nan(server_position.y) or is_nan(server_position.z)
		if not _initialized:
			if not pos_is_nan:
				parent.position = server_position
				_initialized = true
		elif enable_interpolation:
			parent.position = parent.position.lerp(server_position, clamp(interpolation_speed * delta, 0, 1))
		else:
			parent.position = server_position


func _physics_process(_delta: float) -> void:
	# Only the server moves the player
	if multiplayer.is_server():
		parent.move_and_slide()
		server_position = parent.position
