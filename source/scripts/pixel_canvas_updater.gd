extends ColorRect

@export var camera: Camera3D

func _process(_delta: float) -> void:
	if not camera:
		return

	var mat = self.material as ShaderMaterial
	if not mat:
		return

	# INV_PROJECTION_MATRIX
	mat.set_shader_parameter("inv_proj_mat", camera.get_camera_projection().inverse())
	# INV_VIEW_MATRIX (Camera -> World transform)
	mat.set_shader_parameter("inv_view_mat", camera.global_transform)
