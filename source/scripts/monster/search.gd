extends monster_state

func Enter():
	var players = [monster.purr_player, monster.growl_player, monster.groan_player, monster.breathing_player]
	var valid_players = []
	for p in players:
		if p: valid_players.append(p)

	if not valid_players.is_empty():
		valid_players.pick_random().play()

	if not monster.step_timer.timeout.is_connected(play_steps):
		monster.step_timer.timeout.connect(play_steps)

func Physics_Update(_delta: float):
	randomly_play_sound()
	move()
	update_target_pos(monster.target_pos)

func Exit():
	if monster.step_timer.timeout.is_connected(play_steps):
		monster.step_timer.timeout.disconnect(play_steps)
