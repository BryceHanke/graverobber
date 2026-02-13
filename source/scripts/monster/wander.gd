extends monster_state

func Enter():
	SPEED = 1
	monster_body.step_timer.wait_time = 3.0
	if not monster_body.step_timer.timeout.is_connected(play_steps):
		monster_body.step_timer.timeout.connect(play_steps)
	if not monster_body.wander_timer.timeout.is_connected(_on_wander_timeout):
		monster_body.wander_timer.timeout.connect(_on_wander_timeout)

	# Initial wander target
	_on_wander_timeout()

func Update(_delta: float):
	randomly_play_sound()
	attack_trans()
	search_trans()

func Physics_Update(_delta: float):
	move(_delta)

func _on_wander_timeout():
	var random_pos = Vector3(randf_range(-200, 200), 0, randf_range(-200, 200))
	update_target_pos(random_pos)

func Exit():
	if monster_body.step_timer.timeout.is_connected(play_steps):
		monster_body.step_timer.timeout.disconnect(play_steps)
	if monster_body.wander_timer.timeout.is_connected(_on_wander_timeout):
		monster_body.wander_timer.timeout.disconnect(_on_wander_timeout)
