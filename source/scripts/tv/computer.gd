@tool
extends MeshInstance3D

@export var current_view : SubViewport
@export var update_time : float = 5.0

func _ready():
	var img = current_view.get_texture().get_image()
	var tex = ImageTexture.create_from_image(img)
	get_surface_override_material(0).set_shader_parameter("texture_albedo", tex)
	monitor_loop()

func monitor_loop():
	var img = current_view.get_texture().get_image()
	var tex = ImageTexture.create_from_image(img)
	get_surface_override_material(0).set_shader_parameter("texture_albedo", tex)
	await get_tree().create_timer(update_time).timeout.connect(monitor_loop)
