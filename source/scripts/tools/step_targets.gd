@tool
extends Node3D

@export var look_ahead_seconds := 0.3
@export var h_off := 0.5

@export var body : CharacterBody3D
var previous_position := Vector3.ZERO

func _ready():
	if body:
		previous_position = body.global_position
		for child in get_children():
			if child.has_method("setup"):
				child.setup(body)

func _physics_process(delta):
	if body:
		var velocity = Vector3.ZERO
		if delta > 0.0001:
			velocity = (body.global_position - previous_position) / delta

		# Clamp velocity to avoid explosions on teleport
		if velocity.length_squared() > 10000.0: # 100 m/s
			velocity = Vector3.ZERO

		var new_pos = body.global_position + (velocity * look_ahead_seconds) - Vector3(0, h_off, 0)

		# Use a faster lerp for responsiveness, but smooth enough to avoid jitter
		global_position = global_position.lerp(new_pos, 10.0 * delta)

		previous_position = body.global_position
