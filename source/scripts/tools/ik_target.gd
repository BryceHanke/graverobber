@tool
extends Node3D

@export var step_target : Node3D
@export var step_distance := 1.0

var stepping := false

@export var adjacent_leg : Node3D
@export var opposite_leg : Node3D

func _process(delta):
	if abs(global_position.distance_to(step_target.global_position)) >= step_distance:
		if !stepping && !adjacent_leg.stepping:
			step()
			opposite_leg.step()

func step():
	stepping = true
	var target_pos = step_target.global_position
	var half = (global_position + step_target.global_position) / 2
	var t = get_tree().create_tween()
	t.tween_property(self, "global_position", half + owner.global_transform.basis.y, 0.05)
	t.tween_property(self, "global_position", target_pos, 0.05)
	t.tween_callback(func(): stepping = false)
