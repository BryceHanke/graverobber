@tool
extends Node3D

var interval := 0.5
var offset := 0.5
var pos := Vector3.ZERO

func _ready():
	get_tree().create_timer(interval).timeout.connect(new_position)

func new_position():
	pos = -position + Vector3(randf_range(-offset,offset),randf_range(-offset,offset),randf_range(-offset,offset))
	get_tree().create_timer(interval).timeout.connect(new_position)

func move_to_new_position(delta):
	if pos != null:
		position = lerp(position, pos, 0.5*delta)

func reset_position(delta):
	position = lerp(position, Vector3.ZERO, 2.0*delta)

func _physics_process(delta):
	move_to_new_position(delta)
	reset_position(delta)
