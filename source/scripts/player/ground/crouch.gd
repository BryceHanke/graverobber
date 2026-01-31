extends player_state
class_name crouch

func Enter():
	player.maximum_speed = player.crouch_speed
	player.move_speed = player.crouch_speed

func Physics_Update(_delta: float):
	handle_crouch(true, _delta)
	player.apply_floor_snap()
	friction(.1,_delta)
	if player.can_move:
		move(_delta)

func Update(_delta: float):
	idle_trans()
	fall_trans()
	walk_trans()
	jump_trans()
