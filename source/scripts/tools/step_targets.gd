@tool
extends Node3D

@export var offset := 5.0

@export var body : CharacterBody3D
@onready var previous_position = body.global_position

func _process(delta):
	var velocity = body.global_position - previous_position
	global_position = body.global_position + (velocity * offset) 
	previous_position = body.global_position
