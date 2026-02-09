extends player_state
class_name idle

func Physics_Update(_delta: float):
	handle_crouch(false, _delta)
	player.apply_floor_snap()
	player.perform_gravity(_delta)
	friction(_delta)

func Update(_delta: float):
	if player.can_move == true:
		fall_trans()
		walk_trans()
		jump_trans()
		crouch_trans()
	
