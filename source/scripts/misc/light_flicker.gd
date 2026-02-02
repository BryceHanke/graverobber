@tool
extends Light3D

@export var probability := 5
@export var min_brightness := 0.45
@export var max_brightness := 0.5
@export var rot_speed := 0.1
@export var min_blur := 2.5
@export var max_blur := 5.0
@export var rotate := false

var flicker := false

func _process(delta):
	if rotate:
		rotation.y += rot_speed * delta
	if randi_range(0,255) <= probability:
		flicker = true
	if flicker == true:
		shadow_blur = lerp(shadow_blur, min_blur, delta)
		light_energy = lerp(light_energy, min_brightness, delta)
		await get_tree().create_timer(0.5).timeout.connect(reset_brightness)
	if flicker == false:
		shadow_blur = lerp(shadow_blur, max_blur, delta)
		light_energy = lerp(light_energy, max_brightness, delta)

func reset_brightness():
	flicker = false
