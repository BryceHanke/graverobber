extends ColorRect

@export var camera_path : NodePath
var camera : Camera3D

func _ready():
	if camera_path:
		camera = get_node(camera_path)

func _process(_delta):
	if material is ShaderMaterial:
		var sm = material as ShaderMaterial
		if sm.get_shader_parameter("dither_mode") == 1: # World Space
			var cam = camera
			if not cam:
				cam = get_viewport().get_camera_3d()

			if cam:
				var inv_view = cam.global_transform
				var inv_proj = cam.get_camera_projection().inverse()
				sm.set_shader_parameter("inv_view_matrix", inv_view)
				sm.set_shader_parameter("inv_proj_matrix", inv_proj)
