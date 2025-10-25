extends MultiplayerSynchronizer

class_name NetworkProjectile

@export var speed: float = 1.0
@export var move_direction: Vector3 = Vector3.FORWARD
@export var damage: int = 1
@export var hit_area: Area3D
@export var destroy_on_hitbox_hit: bool = true

@onready var parent: CharacterBody3D = get_parent() as CharacterBody3D

signal entered_hitbox(hitbox: HitBox3D)
signal leaved_hitbox(hitbox: HitBox3D)


func _ready() -> void:
	if hit_area and multiplayer.is_server():
		hit_area.area_entered.connect(_on_hit_area_area_entered)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _physics_process(_delta: float) -> void:
	if multiplayer.is_server():
		parent.move_and_collide(move_direction * speed * _delta)


func _on_decay_timer_timeout() -> void:
	if multiplayer.is_server():
		owner.queue_free()


func _on_hit_area_area_entered(other: Area3D) -> void:
	var hitbox_area := other as HitBox3D
	if not hitbox_area:
		return
	
	hitbox_area.hp.take_damage(damage)

	if destroy_on_hitbox_hit:
		owner.queue_free()
