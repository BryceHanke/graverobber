@tool
extends Node3D

@export var offset := 20.0
@export var h_off := 0.5

@export var body : CharacterBody3D
var previous_position := Vector3.ZERO

func _ready():
	if body:
		previous_position = body.global_position
		for child in get_children():
			if child.has_method("setup"):
				child.setup(body)

func _process(delta):
	if body:
		var velocity = body.global_position - previous_position
		var new_pos = body.global_position + (velocity * offset) - Vector3(0,h_off,0)
		global_position = lerp(global_position, new_pos, 2*delta)
		previous_position = body.global_position
