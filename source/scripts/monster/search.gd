extends monster_state

func Enter():
	monster.purr_player.play()
	monster.growl_player.play()
	monster.groan_player.play()
	monster.breathing_player.play()
	monster.step_timer.timeout.connect(play_steps)

func Physics_Update(_delta: float):
	randomly_play_sound()
	move()
	update_target_pos(monster.target_pos)

func Exit():
	monster.step_timer.timeout.disconnect(play_steps)
