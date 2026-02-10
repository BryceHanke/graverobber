extends player_state
class_name fall

func Physics_Update(_delta: float):
	handle_crouch(false, _delta)
	player.perform_gravity(2*_delta)
	strafe(_delta)

func Update(_delta: float):
	walk_trans()
	idle_trans()
	crouch_trans()
	run_trans()

func Exit():
	player.step.steps()
