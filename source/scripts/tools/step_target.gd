@tool
extends Node3D

@export var ray : RayCast3D

func _process(delta):
	if ray.is_colliding():
		var hit_point = ray.get_collision_point()
		global_position = lerp(global_position, hit_point, 2*delta) 

func setup(body: Node3D):
	if ray:
		ray.add_exception(body)
		ray.collision_mask |= 1
