extends monster_state

func Enter():
	monster_body.screech_player.play()
	SPEED = 3.0
	monster_body.step_timer.wait_time = 1.0
	monster_body.groan_player.play()
	if not monster_body.step_timer.timeout.is_connected(play_steps):
		monster_body.step_timer.timeout.connect(play_steps)

func Update(_delta: float):
	wander_trans()
	search_trans()
	randomly_play_sound()

func Physics_Update(_delta: float):
	move(_delta)
	update_target_pos(monster_body.player.global_position)

func Exit():
	if monster_body.step_timer.timeout.is_connected(play_steps):
		monster_body.step_timer.timeout.disconnect(play_steps)
