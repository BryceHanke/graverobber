@tool
extends Node3D

@export var target : Node3D
@onready var ray_cast_3d = $RayCast3D

func _physics_process(delta):
	if ray_cast_3d.is_colliding():
		var hit_point = ray_cast_3d.get_collision_point()
		if target:
			target.global_position = hit_point
