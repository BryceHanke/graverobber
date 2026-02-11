extends player_state
class_name walk

func Enter():
	player.move_speed = player.walk_speed

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
	run_trans()

func Exit():
	pass
