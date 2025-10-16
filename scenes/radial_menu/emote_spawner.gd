extends Node3D

@export var max_y:float = 3
@export var poop:PackedScene
@export var poop_existance_time:float = 60

func spawn_emote(text:String)->void:
	var start := (get_parent() as Node3D).position+position
	var end :=start+Vector3(randf()*2-1,max_y,randf()*2-1)
	var emote := preload("res://scenes/radial_menu/emote.tscn").instantiate() as Label3D
	get_parent().get_parent().add_child(emote,true)
	emote.position = start
	emote.text = text
	var tw :=emote.create_tween()
	tw.tween_property(emote,"position",end,1)
	tw.tween_interval(0.5)
	await tw.finished
	emote.queue_free()

@rpc("any_peer","reliable")
func spawn_clown()->void:
	if get_parent().name.to_int() != multiplayer.get_remote_sender_id():return
	spawn_emote("🤡")

@rpc("any_peer","reliable")
func spawn_like()->void:
	if get_parent().name.to_int() != multiplayer.get_remote_sender_id():return
	spawn_emote("👍")

@rpc("any_peer","reliable")
func spawn_poop()->void:
	if get_parent().name.to_int() != multiplayer.get_remote_sender_id():return
	var m:=poop.instantiate() as Node3D
	get_parent().get_parent().add_child(m,true)
	m.position = (get_parent() as Node3D).position
	m.rotate(Vector3.UP,randf()*PI*2)
	m.scale = Vector3(randf()*0.5+0.5,randf()*0.5+0.5,randf()*0.5+0.5)
	spawn_emote("💩")
	await m.create_tween().tween_interval(poop_existance_time).finished
	m.queue_free()

	
@rpc("any_peer","reliable")
func spawn_dislike()->void:
	if get_parent().name.to_int() != multiplayer.get_remote_sender_id():return
	spawn_emote("👎")

func _on_clown_button_press() -> void:
	spawn_clown.rpc_id(1)

func _on_like_button_press() -> void:
	spawn_like.rpc_id(1)

func _on_poop_button_press() -> void:
	spawn_poop.rpc_id(1)

func _on_dislike_button_press() -> void:
	spawn_dislike.rpc_id(1)
