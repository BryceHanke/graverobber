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

# Lock Mouse Cursor
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	cam.fov = FOV

# Handle Mouse Movement
func _unhandled_input(event):
	if event is InputEventMouseMotion:
		mouse_movement(event)

func _physics_process(delta):
	if canlook == true:
		cam.rotation.x = clampf(cam.rotation.x, deg_to_rad(-90), deg_to_rad(90))

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
		head.rotate((head.transform.basis.y).normalized(),(-event.relative.x) * (SENS * sensMult))
		rotate(transform.basis.x,(-event.relative.y) * (SENS * sensMult))
