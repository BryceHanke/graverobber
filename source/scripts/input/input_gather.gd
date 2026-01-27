extends Node
class_name input_gather

var input_direction : Vector2

var gather_input : bool = true

func _process(delta):
	if gather_input:
		input_direction = Input.get_vector("left","right","up","down")
