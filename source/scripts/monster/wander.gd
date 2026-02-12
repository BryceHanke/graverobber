extends monster_state


func Enter():
	monster.step_timer.timeout.connect(play_steps)
	monster.wander_timer.timeout.connect(update_target_pos.bind(Vector3(randf_range(-200,200), 0, randf_range(-200,200))))

func Update(_delta: float):
	randomly_play_sound()
	search_trans()
	move()

func Exit():
	monster.step_timer.timeout.disconnect(play_steps)
