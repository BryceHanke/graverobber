extends player_state
class_name run

func Enter():
	player.move_speed = player.run_speed

func Physics_Update(_delta: float):
	handle_crouch(false, _delta)
	player.apply_floor_snap()
	if player.can_move == true:
		ground_move(_delta)
	else:
		Transitioned.emit(self, "idle")

func Update(_delta: float):
	idle_trans()
	fall_trans()
	jump_trans()
	crouch_trans()
	walk_trans()

func Exit():
	pass
