extends player_state
class_name fall

func Physics_Update(_delta: float):
	handle_crouch(false, _delta)
	player.perform_gravity(_delta)
	air_move(_delta)

func Update(_delta: float):
	walk_trans()
	idle_trans()
	crouch_trans()
	run_trans()

func Exit():
	player.step.steps()
