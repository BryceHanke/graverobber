extends player_state
class_name jump

func Enter():
	player.emit_signal("is_loud")
	player.velocity.y = player.jump_height
	player.step.steps()
	await get_tree().create_timer(0.15).timeout
	Transitioned.emit(self, "fall")

func Physics_Update(_delta: float):
	handle_crouch(false, _delta)
	air_move(_delta)
