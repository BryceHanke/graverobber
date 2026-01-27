extends player_state
class_name jump

func Enter():
	await get_tree().create_timer(0.01).timeout
	player.velocity += (Vector3.UP * player.jump_height)
	await get_tree().create_timer(0.1).timeout.connect(trans_out)

func trans_out():
	idle_trans()
	walk_trans()
	fall_trans()
