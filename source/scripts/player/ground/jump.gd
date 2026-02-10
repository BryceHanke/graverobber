extends player_state
class_name jump

func Enter():
	player.velocity.y = player.jump_height
	player.step.steps()
	await get_tree().create_timer(0.1).timeout
	Transitioned.emit(self, "fall")

func Physics_Update(_delta: float):
	handle_crouch(false, _delta)
	air_move(_delta)

func Update(_delta: float):
	pass

func Exit():
	pass
