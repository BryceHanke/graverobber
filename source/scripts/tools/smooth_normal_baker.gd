@tool
extends EditorScript

func _run():
	var selection = get_editor_interface().get_selection().get_selected_nodes()

	if selection.is_empty():
		print("No nodes selected. Please select a MeshInstance3D.")
		return

	var modified_count = 0

	for node in selection:
		if node is MeshInstance3D:
			process_mesh_instance(node)
			modified_count += 1

	if modified_count > 0:
		print("Successfully processed " + str(modified_count) + " MeshInstance3D(s). Smooth normals baked into Vertex Colors.")
	else:
		print("No MeshInstance3D found in selection.")

func process_mesh_instance(node: MeshInstance3D):
	var mesh = node.mesh
	if not mesh:
		print("Node " + node.name + " has no mesh.")
		return

	# Handle PrimitiveMeshes by converting to ArrayMesh
	if not mesh is ArrayMesh:
		print("Node " + node.name + " uses a " + mesh.get_class() + ". Converting to ArrayMesh...")
		var surface_tool = SurfaceTool.new()
		surface_tool.create_from(mesh, 0)
		var new_mesh = surface_tool.commit()
		# If there were multiple surfaces, this simple conversion might miss them.
		# But for primitives, there's usually 1.
		# For full support, we'd iterate. But let's assume simple case or existing ArrayMesh.
		mesh = new_mesh
		node.mesh = mesh

	var mdt = MeshDataTool.new()

	for s in range(mesh.get_surface_count()):
		# MeshDataTool setup
		mdt.create_from_surface(mesh, s)

		# 1. Group vertices by position to find shared edges
		# We snap the position to avoid floating point errors
		var pos_map = {} # Vector3 -> Array[int]

		for i in range(mdt.get_vertex_count()):
			var v = mdt.get_vertex(i).snapped(Vector3(0.0001, 0.0001, 0.0001))
			if not pos_map.has(v):
				pos_map[v] = []
			pos_map[v].append(i)

		# 2. Calculate average normal for each group
		for v_pos in pos_map:
			var indices = pos_map[v_pos]
			var avg_normal = Vector3.ZERO

			for idx in indices:
				avg_normal += mdt.get_vertex_normal(idx)

			# Normalize the sum to get the average direction
			if avg_normal.length_squared() > 0:
				avg_normal = avg_normal.normalized()
			else:
				# Fallback if normals cancel out (rare)
				avg_normal = Vector3.UP

			# 3. Encode into Color (0..1 range)
			# Normal components are -1..1
			var r = avg_normal.x * 0.5 + 0.5
			var g = avg_normal.y * 0.5 + 0.5
			var b = avg_normal.z * 0.5 + 0.5
			var color = Color(r, g, b, 1.0)

			# 4. Write to vertex colors
			for idx in indices:
				mdt.set_vertex_color(idx, color)

		# Commit changes back to the mesh surface
		# Note: This completely replaces the surface data
		mdt.commit_to_surface(mesh, s)
