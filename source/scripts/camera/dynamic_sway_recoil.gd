extends Node3D

@export var player : player_controller
@export var camera : Camera3D
@export var holder : Node3D
@export var speed := 7.0
@export var sway_amount : float = .075
var mouse_input : Vector2
var og_pos : Vector3

func _ready():
	og_pos = holder.position

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		mouse_input = event.relative

func _process(delta):
	weapon_tilt(player.ig.input_direction.x, delta)
	weapon_sway(delta)

func _physics_process(delta):
	global_position.x = move_toward(global_position.x, camera.global_position.x, speed*delta)
	global_position.y = move_toward(global_position.y, camera.global_position.y, speed*delta)
	global_position.z = move_toward(global_position.z, camera.global_position.z, speed*delta)
	global_rotation.x = rotate_toward(global_rotation.x, camera.global_rotation.x, speed*delta)
	global_rotation.y = rotate_toward(global_rotation.y, camera.global_rotation.y, speed*delta)
	global_rotation.z = rotate_toward(global_rotation.z, camera.global_rotation.z, speed*delta)
	rotation.x = clampf(rotation.x, deg_to_rad(-75), deg_to_rad(75))
	holder.rotation.x = clampf(holder.rotation.x, deg_to_rad(-75), deg_to_rad(75))

func weapon_tilt(input_X, delta):
	holder.rotation.z = lerp(holder.rotation.z, -input_X * sway_amount, 10 * delta)

func weapon_sway(delta):
	mouse_input = lerp(mouse_input, Vector2.ZERO, 10 * delta)
	holder.rotation.x = lerp(holder.rotation.x, (mouse_input.y * (sway_amount / 10)), 10 * delta)
	holder.rotation.y = lerp(holder.rotation.y, (mouse_input.x * (sway_amount / 10)), 10 * delta)
