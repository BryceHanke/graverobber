extends monster_state

func Enter():
	monster.screech_player.play()
	SPEED = 3.0
	monster.step_timer.wait_time = 1.0
	monster.groan_player.play()
	if not monster.step_timer.timeout.is_connected(play_steps):
		monster.step_timer.timeout.connect(play_steps)

func Update(_delta: float):
	wander_trans()
	search_trans()
	randomly_play_sounds()

func Physics_Update(_delta: float):
	move()
	update_target_pos(monster.player.global_position)

func Exit():
	if monster.step_timer.timeout.is_connected(play_steps):
		monster.step_timer.timeout.disconnect(play_steps)
