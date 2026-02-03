extends Node3D

const DIALOGUE = preload("uid://bstqqu5pguvy0")

@export var dialogue: Array[DE]

func spawn_dialogue():
	var new_dialogue = DIALOGUE.instantiate()
	new_dialogue.dialogue = dialogue
	get_parent().add_child.call_deferred(new_dialogue)
