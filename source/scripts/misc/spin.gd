@tool
extends Node3D

@export var rot_vector := Vector3.ZERO

func _process(delta):
	rotation_degrees = lerp(rotation_degrees, rotation_degrees+rot_vector, delta)
