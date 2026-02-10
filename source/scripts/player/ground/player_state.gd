extends state
class_name player_state

@export var player : player_controller

func idle_trans():
	if player.ig.input_direction.length() == 0.0 && player.is_on_floor() && !Input.is_action_pressed("crouch"):
		Transitioned.emit(self, "idle")

func walk_trans():
	if player.ig.input_direction.length() != 0.0 && player.is_on_floor() && player.can_move == true && !Input.is_action_pressed("crouch") && !Input.is_action_pressed("run"):
		Transitioned.emit(self, "walk")

func fall_trans():
	if !player.is_on_floor():
		Transitioned.emit(self, "fall")

func jump_trans():
	if player.is_on_floor():
		if Input.is_action_pressed("jump"):
			Transitioned.emit(self, "jump")

func crouch_trans():
	if Input.is_action_pressed("crouch") && player.is_on_floor():
		Transitioned.emit(self, "crouch")

func run_trans():
	if player.ig.input_direction.length() != 0.0 && player.is_on_floor() && player.can_move == true && !Input.is_action_pressed("crouch") && Input.is_action_pressed("run"):
		Transitioned.emit(self, "run")

func move(_delta):
	var current_speed = player.velocity.dot(player.move_dir)
	var add_speed = (player.maximum_speed - current_speed)
	player.velocity = lerp(player.velocity, player.move_dir * (add_speed), player.acceleration * _delta)

func strafe(_delta):
	var current_speed = player.velocity.dot(player.move_dir)
	var add_speed = (player.strafe_speed - current_speed)
	player.velocity = lerp(player.velocity, player.move_dir * (add_speed), player.acceleration * _delta)

func friction(_strength:float,_delta:float):
	player.velocity = lerp(player.velocity, Vector3.ZERO, player.deceleration * _strength * _delta)

func handle_crouch(_crouched:bool,_delta:float):
	if _crouched:
		player.mesh.mesh.height = lerp(player.mesh.mesh.height, player.min_height, player.crouching_speed*_delta)
		player.collision.shape.height = lerp(player.collision.shape.height, player.min_height, player.crouching_speed*_delta)
	else:
		player.mesh.mesh.height = lerp(player.mesh.mesh.height, player.max_height, player.crouching_speed*_delta)
		player.collision.shape.height = lerp(player.collision.shape.height, player.max_height, player.crouching_speed*_delta)
