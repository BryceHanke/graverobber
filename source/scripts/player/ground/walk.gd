extends player_state
class_name walk

func Enter():
	player.maximum_speed = player.walk_speed
	player.move_speed = player.walk_speed
	player.step.timer.timeout.connect(player.step.steps)
	player.step.timer.wait_time = 1.0

func Physics_Update(_delta: float):
	handle_crouch(false, _delta)
	player.apply_floor_snap()
	friction(.1,_delta)
	if player.can_move == true:
		move(_delta)
	else:
		Transitioned.emit(self, "idle")

func Update(_delta: float):
	idle_trans()
	fall_trans()
	jump_trans()
	crouch_trans()
	run_trans()

func Exit():
	player.step.timer.timeout.disconnect(player.step.steps)
