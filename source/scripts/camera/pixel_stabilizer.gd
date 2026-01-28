extends ColorRect

@export var camera: Camera3D

func _process(delta):
	if camera and material:
		material.set_shader_parameter("inv_view_matrix", camera.global_transform)
