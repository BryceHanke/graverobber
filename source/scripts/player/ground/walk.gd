extends player_state
class_name walk

func Enter():
	player.maximum_speed = player.walk_speed
	player.move_speed = player.walk_speed

func Physics_Update(_delta: float):
	player.apply_floor_snap()
	friction(.1,_delta)
	if player.can_move:
		move(_delta)

func Update(_delta: float):
	idle_trans()
	fall_trans()
	jump_trans()
