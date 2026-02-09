extends player_state
class_name jump

func Enter():
	player.velocity += (Vector3.UP * player.jump_height)
	await get_tree().physics_frame
	Transitioned.emit(self, "fall")
