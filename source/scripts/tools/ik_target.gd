@tool
extends Node3D

@export var step_target : Node3D
@export var step_distance := .5

var stepping := false

@export var adjacent_leg : Node3D
@export var opposite_leg : Node3D

func _ready():
	set_as_top_level(true)

func _physics_process(delta):
	if is_far_enough():
		if !stepping && !adjacent_leg.stepping:
			step()
			opposite_leg.step()

func is_far_enough()->bool:
	var pos = global_position
	var step_pos = step_target.global_position
	if abs(pos.distance_to(step_pos)) > step_distance:
		return true
	return false

func step():
	stepping = true
	var target_pos = step_target.global_position
	var target_quat = step_target.quaternion
	var half = (global_position + step_target.global_position) / 2

	var up_dir = Vector3.UP
	if owner:
		up_dir = owner.global_transform.basis.y

	var t = get_tree().create_tween()
	t.tween_property(self, "global_position", half + up_dir, 0.1)
	t.tween_property(self, "global_position", target_pos, 0.1)
	t.tween_callback(func(): stepping = false)

	var t_rot = get_tree().create_tween()
	t_rot.tween_property(self, "quaternion", target_quat, 0.2)
