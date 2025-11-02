extends MultiplayerSynchronizer

class_name NetworkProjectile

@export var speed: float = 1.0
@export var move_direction: Vector3 = Vector3.FORWARD
@export var hit_area: Area3D
@export var move_controller: CharacterBody3D

@onready var parent: CharacterBody3D = get_parent() as CharacterBody3D

## Emits when hit area of projectile enters someone's hitbox
signal entered_hitbox(hitbox: HitBox3D)
## Emits when hit area of projectile leaves someone's hitbox
signal leaved_hitbox(hitbox: HitBox3D)
## Emits when hits regular solid collider
signal hit_wall(collision: KinematicCollision3D)


func _ready() -> void:
	if multiplayer.is_server():
		if hit_area:
			hit_area.area_entered.connect(_on_hit_area_area_entered)
			hit_area.area_exited.connect(_on_hit_area_area_exited)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _physics_process(_delta: float) -> void:
	if multiplayer.is_server():
		var collision := move_controller.move_and_collide(move_direction * speed * _delta)
		if collision:
			hit_wall.emit(collision)


func _on_decay_timer_timeout() -> void:
	if multiplayer.is_server():
		owner.queue_free()


func _on_hit_area_area_entered(other: Area3D) -> void:
	var hitbox_area := other as HitBox3D
	if not hitbox_area:
		return

	entered_hitbox.emit(hitbox_area)


func _on_hit_area_area_exited(other: Area3D) -> void:
	var hitbox_area := other as HitBox3D
	if not hitbox_area:
		return

	leaved_hitbox.emit(hitbox_area)
