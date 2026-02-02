extends player_state
class_name fall

func Physics_Update(_delta: float):
	player.perform_gravity(2*_delta)
	strafe(_delta)

func Update(_delta: float):
	walk_trans()
	idle_trans()
	crouch_trans()
