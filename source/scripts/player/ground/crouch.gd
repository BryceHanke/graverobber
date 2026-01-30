extends player_state
class_name crouch

@onready var anim = $crouch

func Enter():
	player.maximum_speed = player.crouch_speed
	player.move_speed = player.crouch_speed
	anim.play("crouch")

func Physics_Update(_delta: float):
	player.apply_floor_snap()
	friction(.1,_delta)
	if player.can_move:
		move(_delta)

func Update(_delta: float):
	idle_trans()
	fall_trans()
	walk_trans()
	jump_trans()

func Exit():
	anim.play("uncrouch")
