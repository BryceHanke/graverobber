extends CharacterBody3D
class_name player_controller

@export var maximum_speed : float = 15.0

@export var walk_speed : float = 4.0
@export var crouch_speed : float = 1.0
@export var run_speed : float = 7.0

@export var jump_height : float = 28.0

# Quake Movement Constants
@export var ground_acceleration : float = 8.0
@export var air_acceleration : float = 2.0
@export var ground_friction : float = 12.0
@export var stop_speed : float = 2.0
@export var air_cap : float = 0.85 # Max speed you can gain by strafing in air (wishspeed cap)

@export var crouching_speed := 5.0
@export var min_height := 1.0
@export var max_height := 2.0

@export var gravity_magnitude : float = 20.0

@export var can_move := true
var move_speed : float = 0.0
var move_dir : Vector3
var gravity = Vector3() # Kept for compatibility if used elsewhere, but perform_gravity won't use it the same way

@export var step : steps

@export var camera : Camera3D
@onready var ig : input_gather = $logic/input_gather
@onready var mesh = $mesh
@onready var collision = $collision


func _process(delta):
	mouse_change()
	align_movement_direction()

func _physics_process(delta):
	move_and_slide()

func align_movement_direction():
	move_dir = (((ig.input_direction.y * camera.get_parent().global_transform.basis.z) + (ig.input_direction.x * camera.global_transform.basis.x))).normalized()

func perform_gravity(_delta):
	if not is_on_floor():
		velocity.y -= gravity_magnitude * _delta
	# Reset gravity accumulator if on floor?
	# The old code used 'gravity' vector accumulator.
	# If we switch to direct velocity manipulation, we don't strictly need 'gravity' variable unless for display.

func mouse_change():
	if Input.is_action_just_pressed("pause"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			camera.canlook = false
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		elif Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			camera.canlook = true
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
