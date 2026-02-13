@tool
extends Node3D

@export var step_target : Node3D
@export var step_distance := 0.5
@export var step_height := 0.5
@export var step_duration := 0.4

enum State { PLANTED, MOVING }
var state := State.PLANTED

var start_pos := Vector3.ZERO
var start_rot := Quaternion.IDENTITY
var move_time := 0.0

@export var adjacent_leg : Node3D
@export var opposite_leg : Node3D

func _ready():
	set_as_top_level(true)
	# Initialize position to step_target
	if step_target:
		global_position = step_target.global_position
		global_rotation = step_target.global_rotation

func _physics_process(delta):
	if !step_target:
		return

	match state:
		State.PLANTED:
			var dist = global_position.distance_to(step_target.global_position)

			# If too far, try to step
			if dist > step_distance:
				if can_step():
					start_step()

			# Robustness: if extremely far (e.g. teleport), snap immediately
			if dist > step_distance * 3.0:
				global_position = step_target.global_position
				global_rotation = step_target.global_rotation
				state = State.PLANTED # Cancel any movement if we snapped

		State.MOVING:
			move_time += delta
			var t = clamp(move_time / step_duration, 0.0, 1.0)

			# Interpolate position (Linear + Arc)
			var current_target = step_target.global_position
			var mid_pos = start_pos.lerp(current_target, t)

			# Add arc height
			var height = sin(t * PI) * step_height
			mid_pos.y += height # Assumes Y is up. Since we are in global space, this is usually true.

			global_position = mid_pos

			# Interpolate rotation (Slerp)
			var current_rot = step_target.global_transform.basis.get_rotation_quaternion()
			quaternion = start_rot.slerp(current_rot, t)

			if t >= 1.0:
				state = State.PLANTED
				global_position = current_target # Snap to finish
				quaternion = current_rot

func can_step() -> bool:
	# Don't step if adjacent leg is moving
	if adjacent_leg and adjacent_leg.has_method("is_moving") and adjacent_leg.is_moving():
		return false
	return true

func start_step():
	state = State.MOVING
	start_pos = global_position
	start_rot = quaternion
	move_time = 0.0

func is_moving() -> bool:
	return state == State.MOVING
