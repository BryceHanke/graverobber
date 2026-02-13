extends monster_state

var last_heard_position := Vector3.ZERO

var stop := false

func Enter():
	monster_body.screech_player.play()
	stop = false
	SPEED = 2
	monster_body.step_timer.wait_time = 2.0
	var players = [monster_body.purr_player, monster_body.groan_player, monster_body.screech_player]
	var valid_players = []
	for p in players:
		if p: valid_players.append(p)

	if not valid_players.is_empty():
		valid_players.pick_random().play()

	if not monster_body.step_timer.timeout.is_connected(play_steps):
		monster_body.step_timer.timeout.connect(play_steps)
	monster_body.search_timer.start()

func Update(_delta: float):
	attack_trans()
	if stop == true:
		wander_trans()
	randomly_play_sound()

func Physics_Update(_delta: float):
	update_target_pos(monster_body.player.global_position)
	move(_delta)

func stop_search():
	stop = true

func Exit():
	if monster_body.step_timer.timeout.is_connected(play_steps):
		monster_body.step_timer.timeout.disconnect(play_steps)
