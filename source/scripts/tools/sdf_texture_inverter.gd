@tool
extends EditorScript

func _run():
	var selection = get_editor_interface().get_selection().get_selected_nodes()

	if selection.is_empty():
		print("No nodes selected. Please select a GPUParticlesCollisionSDF3D node.")
		return

	var modified_count = 0

	for node in selection:
		if node is GPUParticlesCollisionSDF3D:
			process_sdf_node(node)
			modified_count += 1

	if modified_count > 0:
		print("Successfully processed " + str(modified_count) + " GPUParticlesCollisionSDF3D node(s).")
	else:
		print("No GPUParticlesCollisionSDF3D nodes found in selection.")

func process_sdf_node(node: GPUParticlesCollisionSDF3D):
	var texture = node.texture

	if not texture:
		print("Node " + node.name + " has no texture. Bake SDF first.")
		return

	if not texture is Texture3D:
		print("Node " + node.name + " has a texture that is not a Texture3D.")
		return

	var images = texture.get_data()
	if images.is_empty():
		print("Node " + node.name + " texture has no data.")
		return

	print("Processing texture for " + node.name + ": " + str(texture.width) + "x" + str(texture.height) + "x" + str(texture.depth))

	var new_images: Array[Image] = []
	for img in images:
		var new_img = img.duplicate()
		new_img.invert()
		new_images.append(new_img)

	var use_mipmaps = new_images.size() > texture.depth

	var new_texture = ImageTexture3D.new()
	var err = new_texture.create(texture.format, texture.width, texture.height, texture.depth, use_mipmaps, new_images)

	if err != OK:
		print("Failed to create new ImageTexture3D: " + str(err))
		return

	node.texture = new_texture
	print("Inverted SDF texture for " + node.name)
