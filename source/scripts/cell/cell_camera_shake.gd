@tool
extends Camera3D

@export var do_rotate := false
@export var x_range := 5
@export var y_range := 5
@export var z_range := 5
@export var rot_speed := 0.1
@export var interval := 5.0

var rot

func _ready():
	rotation = Vector3.ZERO
	calc_rotation()

func calc_rotation():
	rot = Vector3(deg_to_rad(randf_range(-x_range,x_range)),deg_to_rad(randf_range(-y_range,y_range)),deg_to_rad(randf_range(-z_range,z_range)))
	get_tree().create_timer(interval).timeout.connect(calc_rotation)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if do_rotate:
		rotation = lerp(rotation, rot, rot_speed * delta)
