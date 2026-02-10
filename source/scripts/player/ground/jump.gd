extends player_state
class_name jump

func Enter():
	await get_tree().create_timer(0.01).timeout
	player.velocity += (Vector3.UP * player.jump_height)
	player.step.steps()
	await get_tree().create_timer(0.05).timeout.connect(trans_out)

func Physics_Update(_delta: float):
	handle_crouch(false, _delta)

func trans_out():
	idle_trans()
	walk_trans()
	fall_trans()
	crouch_trans()
	run_trans()
