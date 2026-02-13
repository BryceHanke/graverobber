@tool
extends Node3D

@export var ray : RayCast3D

func _ready():
	# Break feedback loop by reparenting ray to the container (step_targets)
	# This ensures the ray follows the lookahead position, not the snapped foot position
	if !Engine.is_editor_hint():
		if ray and ray.get_parent() == self:
			ray.reparent(get_parent(), true)

func _physics_process(delta):
	if ray:
		if ray.is_colliding():
			global_position = ray.get_collision_point()

			var normal = ray.get_collision_normal()
			var z_forward = ray.global_transform.basis.z

			# Prevent parallel vectors causing zero cross product
			if abs(z_forward.dot(normal)) > 0.99:
				z_forward = ray.global_transform.basis.x

			var new_x = normal.cross(z_forward).normalized()
			var new_z = new_x.cross(normal).normalized()

			if new_x.is_normalized() and new_z.is_normalized():
				global_transform.basis = Basis(new_x, normal, new_z)
		else:
			# Fallback: Hanging below the ray origin (fully extended)
			global_position = ray.to_global(ray.target_position)
			global_rotation = ray.global_rotation

func setup(body: Node3D):
	if ray:
		ray.add_exception(body)
		ray.collision_mask |= 1
