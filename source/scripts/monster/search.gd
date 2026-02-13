extends monster_state

var last_heard_position := Vector3.ZERO

var stop := false

func Enter():
	monster.screech_player.play()
	stop = false
	SPEED = 0.5
	monster.step_timer.wait_time = 2.0
	var players = [monster.purr_player, monster.groan_player, monster.screech_player]
	var valid_players = []
	for p in players:
		if p: valid_players.append(p)

	if not valid_players.is_empty():
		valid_players.pick_random().play()

	if not monster.step_timer.timeout.is_connected(play_steps):
		monster.step_timer.timeout.connect(play_steps)
	monster.search_timer.start()

func Update(_delta: float):
	attack_trans()
	if stop == true:
		wander_trans()
	randomly_play_sound()

func Physics_Update(_delta: float):
	update_target_pos(monster.player.global_position)
	move()

func stop_search():
	stop = true

func Exit():
	if monster.step_timer.timeout.is_connected(play_steps):
		monster.step_timer.timeout.disconnect(play_steps)
