@tool
extends Node3D

@onready var ray_cast_3d = $RayCast3D

func _process(delta):
	if ray_cast_3d.is_colliding():
		var hit_point = ray_cast_3d.get_collision_point()
		global_position = hit_point
