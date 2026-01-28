@tool
extends Light3D

@export var probability := 5
@export var min_range := 0.45
@export var max_range := 0.5
@export var rotate := false

var flicker := false

func _process(delta):
	if rotate:
		rotation.y += delta
	if randi_range(0,255) <= probability:
		flicker = true
	if flicker == true:
		light_energy = lerp(light_energy, min_range, 5 * delta)
		await get_tree().create_timer(0.5).timeout.connect(reset_brightness)
	if flicker == false:
		light_energy = lerp(light_energy, max_range, 15 * delta)

func reset_brightness():
	flicker = false
