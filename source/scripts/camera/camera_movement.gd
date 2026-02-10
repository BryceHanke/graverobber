extends Node3D

@onready var player = $"../../.."

@export var cam : Camera3D
@export var head : Node3D
@export var lean : Node3D

@export var canlook : bool = true

# Player Variables
@export var SENS : float = 2.5
@export var DZ : float = 0.1
var sensMult = 0.001
var FOV = 90

# Head Bob
@export var bob_interval : float = 2.0
var bobamp = 0.1
var tbob = 0.0
var rotamount = .005

# Lock Mouse Cursor
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	cam.fov = FOV

# Handle Mouse Movement
func _unhandled_input(event):
	if event is InputEventMouseMotion:
		mouse_movement(event)

func _physics_process(delta):
	if !player.ig.input_direction.length() == 0:
		tbob += delta * player.velocity.length()
	else:
		tbob = 0.0
	if !player.is_on_floor():
		tbob = 0.0
	cam.transform.origin = lerp(cam.transform.origin, headbob(tbob), 5*delta)
	cam_tilt(delta, player.ig.input_direction.x)

func cam_tilt(delta, input_x):
	cam.rotation.z = lerp(cam.rotation.z, -input_x * (rotamount * player.velocity.length()), 4 * delta)

func _process(delta):
	if Input.is_action_pressed("lean"):
		player.can_move = false
		if Input.is_action_pressed("left"):
			lean.rotation_degrees.z = lerp(lean.rotation_degrees.z, 45.0, 3*delta)
		if Input.is_action_pressed("right"):
			lean.rotation_degrees.z = lerp(lean.rotation_degrees.z, -45.0, 3*delta)
	else:
		lean.rotation_degrees.z = lerp(lean.rotation_degrees.z, 0.0, 3*delta)
		player.can_move = true

func mouse_movement(event):
	if canlook == true:
		head.rotation.y -= event.relative.x * SENS * sensMult
		cam.rotation.x -= event.relative.y * SENS * sensMult
		cam.rotation.x = clamp(cam.rotation.x, deg_to_rad(-80), deg_to_rad(80))

func headbob(time):
	var pos = Vector3.ZERO

	if bob_interval > 0:
		var theta = (time / bob_interval) * 2 * PI
		pos.y = sin(theta) * bobamp
		pos.x = sin(theta / 16.0) * bobamp
	
	if player.ig.input_direction.length() == 0:
		pos = lerp(pos, Vector3.ZERO, 0.1)
	return pos
