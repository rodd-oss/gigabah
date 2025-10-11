extends Area3D

var speed: float = 40.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += transform.basis.x * speed * delta

func _on_body_entered(body: Node) -> void:
	if !is_multiplayer_authority():
		return

	if body is Player:
		body.take_damage.rpc_id(1, 10)
		# take $NetworkHp fro m
	remove_bullet.rpc()

@rpc("call_local")
func remove_bullet() -> void:
	queue_free()
