extends player_state
class_name crouch

func Enter():
	player.maximum_speed = player.crouch_speed
	player.move_speed = player.crouch_speed
	player.step.timer.wait_time = 1.0

func Physics_Update(_delta: float):
	handle_crouch(true, _delta)
	player.apply_floor_snap()
	if player.can_move:
		ground_move(_delta)
	else:
		Transitioned.emit(self, "idle")
	if player.ig.input_direction.length() > 0:
		if !player.step.timer.timeout.is_connected(player.step.steps):
			player.step.timer.timeout.connect(player.step.steps)
	else:
		if player.step.timer.timeout.is_connected(player.step.steps):
			player.step.timer.timeout.disconnect(player.step.steps)
		

func Update(_delta: float):
	idle_trans()
	fall_trans()
	walk_trans()
	jump_trans()
	run_trans()

func Exit():
	pass
