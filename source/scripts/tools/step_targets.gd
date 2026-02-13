@tool
extends Node3D

@export var offset := 5.0

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
		global_position = body.global_position + (velocity * offset)
		previous_position = body.global_position
