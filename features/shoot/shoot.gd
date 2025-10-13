extends Node3D

const BULLET: PackedScene = preload("./bullet.tscn")

func _enter_tree() -> void:
	set_multiplayer_authority(1)

func _physics_process(_delta: float) -> void:
	if multiplayer.get_unique_id() == get_parent().name.to_int() and multiplayer.get_unique_id() != 1:
		if Input.is_action_just_pressed("shoot"):
			shoot.rpc_id(1)

@rpc("any_peer")
func shoot() -> void:
	if !is_multiplayer_authority(): return
	var bullet: Node = BULLET.instantiate()
	bullet.position = global_position + Vector3(1, 0.9, 0)
	get_node("/root/Index3d/SpawnTo").add_child(bullet, true)
