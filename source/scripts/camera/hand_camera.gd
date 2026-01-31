extends Node3D

@export var node_to_match : Node3D

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	global_position = node_to_match.global_position
	global_rotation = node_to_match.global_rotation
