extends player_state
class_name idle

func Physics_Update(_delta: float):
	player.apply_floor_snap()
	player.perform_gravity(_delta)
	friction(2,_delta)

func Update(_delta: float):
	walk_trans()
	fall_trans()
	jump_trans()
