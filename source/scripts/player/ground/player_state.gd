extends state
class_name player_state

@export var player : player_controller

func idle_trans():
	if player.ig.input_direction.length() == 0.0 && player.is_on_floor() && !Input.is_action_pressed("crouch"):
		Transitioned.emit(self, "idle")

func walk_trans():
	if player.ig.input_direction.length() != 0.0 && player.is_on_floor() && player.can_move == true && !Input.is_action_pressed("crouch"):
		Transitioned.emit(self, "walk")

func fall_trans():
	if !player.is_on_floor():
		Transitioned.emit(self, "fall")

func jump_trans():
	if player.is_on_floor():
		if Input.is_action_pressed("jump"):
			Transitioned.emit(self, "jump")

func crouch_trans():
	if Input.is_action_pressed("crouch"):
		Transitioned.emit(self, "crouch")

func move(_delta):
	accelerate(player.move_dir, player.move_speed, player.acceleration, _delta)

func strafe(_delta):
	accelerate(player.move_dir, player.strafe_speed, player.air_acceleration, _delta)

func friction(_delta:float):
	apply_friction(1.0, _delta)

func accelerate(wish_dir: Vector3, wish_speed: float, accel: float, delta: float):
	var current_speed = player.velocity.dot(wish_dir)
	var add_speed = wish_speed - current_speed
	if add_speed <= 0:
		return

	var accel_speed = accel * wish_speed * delta
	if accel_speed > add_speed:
		accel_speed = add_speed

	player.velocity += wish_dir * accel_speed

func apply_friction(t: float, delta: float):
	var vec = player.velocity
	vec.y = 0
	var speed = vec.length()
	var drop = 0.0

	if player.is_on_floor():
		var control = max(speed, player.stop_speed)
		drop = control * player.deceleration * delta * t

	var new_speed = max(speed - drop, 0.0)
	if speed > 0.0:
		new_speed /= speed

	player.velocity.x *= new_speed
	player.velocity.z *= new_speed

func handle_crouch(_crouched:bool,_delta:float):
	if _crouched:
		player.mesh.mesh.height = lerp(player.mesh.mesh.height, player.min_height, player.crouching_speed*_delta)
		player.collision.shape.height = lerp(player.collision.shape.height, player.min_height, player.crouching_speed*_delta)
	else:
		player.mesh.mesh.height = lerp(player.mesh.mesh.height, player.max_height, player.crouching_speed*_delta)
		player.collision.shape.height = lerp(player.collision.shape.height, player.max_height, player.crouching_speed*_delta)
