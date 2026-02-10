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

# Quake Physics Implementations

func accelerate(wishdir: Vector3, wishspeed: float, accel: float, delta: float):
	var current_speed = player.velocity.dot(wishdir)
	var add_speed = wishspeed - current_speed
	if add_speed <= 0:
		return

	var accel_speed = accel * wishspeed * delta
	if accel_speed > add_speed:
		accel_speed = add_speed

	player.velocity += accel_speed * wishdir

func apply_friction(t: float, delta: float):
	var vec = player.velocity
	vec.y = 0
	var speed = vec.length()

	if speed < 0.1:
		player.velocity.x = 0
		player.velocity.z = 0
		return

	var drop = 0.0
	var control = player.stop_speed if speed < player.stop_speed else speed
	drop += control * player.ground_friction * delta * t

	var new_speed = speed - drop
	if new_speed < 0:
		new_speed = 0
	if speed > 0:
		new_speed /= speed

	player.velocity.x *= new_speed
	player.velocity.z *= new_speed

func ground_move(delta: float):
	apply_friction(1.0, delta)

	var wishdir = player.move_dir
	wishdir.y = 0
	wishdir = wishdir.normalized()

	var wishspeed = player.move_speed

	accelerate(wishdir, wishspeed, player.ground_acceleration, delta)

func air_move(delta: float):
	var wishdir = player.move_dir
	wishdir.y = 0
	wishdir = wishdir.normalized()

	var wishspeed = player.move_speed

	# Cap wishspeed for air strafing
	var dynamic_wishspeed = wishspeed
	if dynamic_wishspeed > player.air_cap:
		dynamic_wishspeed = player.air_cap

	accelerate(wishdir, dynamic_wishspeed, player.air_acceleration, delta)

func handle_crouch(_crouched:bool,_delta:float):
	if _crouched:
		player.mesh.mesh.height = lerp(player.mesh.mesh.height, player.min_height, player.crouching_speed*_delta)
		player.collision.shape.height = lerp(player.collision.shape.height, player.min_height, player.crouching_speed*_delta)
	else:
		player.mesh.mesh.height = lerp(player.mesh.mesh.height, player.max_height, player.crouching_speed*_delta)
		player.collision.shape.height = lerp(player.collision.shape.height, player.max_height, player.crouching_speed*_delta)
