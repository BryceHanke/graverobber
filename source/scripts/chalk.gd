extends Node3D

const CHALK_MARK = preload("uid://l8swa4qt65y3")
@onready var ray_cast_3d : RayCast3D = $RayCast3D
@onready var chalk = $chalk
var og_pos := Vector3.ZERO
@export var chalk_instancer : MultiMeshInstance3D

const MAX_MARKS = 25000
var current_mark_index = 0

const TIMER_INTERVAL : float = 0.01
var timer : float = 0.0

func _ready():
	og_pos = chalk.position
	if chalk_instancer:
		chalk_instancer.reparent.call_deferred(get_tree().root.get_child(0))
		chalk_instancer.custom_aabb = AABB(Vector3(-10000, -10000, -10000), Vector3(20000, 20000, 20000))
		if chalk_instancer.multimesh:
			chalk_instancer.multimesh.instance_count = MAX_MARKS
			chalk_instancer.multimesh.visible_instance_count = 0

func _process(delta):
	if timer > 0.0:
		timer -= delta

	if ray_cast_3d.is_colliding():
		var target_pos = to_local(ray_cast_3d.get_collision_point())
		chalk.position = chalk.position.lerp(target_pos, 10 * delta)

		if Input.is_action_pressed("r_click") and timer <= 0.0:
			place_mark()
			timer = TIMER_INTERVAL
	else:
		chalk.position = chalk.position.lerp(og_pos, 10 * delta)

func place_mark():
	if chalk_instancer and chalk_instancer.multimesh:
		var normal = ray_cast_3d.get_collision_normal()
		var point = ray_cast_3d.get_collision_point()

		var idx = current_mark_index

		var z_axis = normal
		var y_axis = Vector3.UP

		if abs(z_axis.dot(y_axis)) > 0.95:
			y_axis = Vector3.RIGHT

		var x_axis = y_axis.cross(z_axis).normalized()
		y_axis = z_axis.cross(x_axis).normalized()

		var basis = Basis(x_axis, y_axis, z_axis)

		var offset_pos = point + (normal * 0.01)
		var global_transform = Transform3D(basis, offset_pos)
		var local_transform = chalk_instancer.global_transform.affine_inverse() * global_transform

		chalk_instancer.multimesh.set_instance_transform(idx, local_transform)

		current_mark_index = (current_mark_index + 1) % MAX_MARKS
		if chalk_instancer.multimesh.visible_instance_count < MAX_MARKS:
			chalk_instancer.multimesh.visible_instance_count += 1
