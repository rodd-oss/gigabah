extends MultiplayerSynchronizer

class_name NetworkProjectile

@export var speed: float = 1.0
@export var move_direction: Vector3 = Vector3.FORWARD

@onready var parent: CharacterBody3D = get_parent() as CharacterBody3D


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _physics_process(_delta: float) -> void:
	if multiplayer.is_server():
		parent.move_and_collide(move_direction * speed * _delta)


func _on_decay_timer_timeout() -> void:
	if multiplayer.is_server():
		owner.queue_free()
