extends Node
class_name state_machine

@export var initial_state : state
var current_state : state
var previous_state : state
var states : Dictionary = {}

func _ready():
	for child in get_children():
		if child is state or child.is_in_group("state_holder"):
			if child is state:
				states[child.name.to_lower()] = child
				child.Transitioned.connect(on_child_transition)
			else:
				for grand_child in child.get_children():
					if grand_child is state:
						states[grand_child.name.to_lower()] = grand_child
						grand_child.Transitioned.connect(on_child_transition)
	if current_state != null:
		print(current_state)
		current_state.Enter()
	else:
		if initial_state:
			initial_state.Enter()
			current_state = initial_state

func _process(delta):
	if current_state:
		current_state.Update(delta)

func _physics_process(delta):
	if current_state:
		current_state.Physics_Update(delta)

func on_child_transition(state, new_state_name):
	if state != current_state:
		return
	
	previous_state = current_state
	
	var new_state = states.get(new_state_name.to_lower())
	if !new_state:
		return
	
	if current_state:
		current_state.Exit()
	
	new_state.Enter()
	
	current_state = new_state
	
	print(current_state)
