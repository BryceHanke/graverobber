@tool
extends Node

## A tool to automatically generate a GPUParticlesCollisionSDF3D for a target mesh.

@export var target_mesh_path: NodePath
@export_enum("Inside", "Outside") var generate_mode: int = 0
## Vector to offset the collision box center relative to the mesh center.
@export var bake_side_vector: Vector3 = Vector3.ZERO
## Margin to expand the collision box when using Outside mode.
@export var margin: float = 0.5
@export var thickness: float = 1.0
@export var bake_mask: int = 4294967295
@export var resolution: GPUParticlesCollisionSDF3D.Resolution = GPUParticlesCollisionSDF3D.RESOLUTION_64

@export var generate: bool = false : set = _set_generate

func _set_generate(value):
	if value:
		generate_collision()
		generate = false

func generate_collision():
	var target_mesh_node = get_node_or_null(target_mesh_path)
	if not target_mesh_node:
		print("Target mesh not found!")
		return

	if not target_mesh_node is MeshInstance3D:
		print("Target node is not a MeshInstance3D!")
		return

	if target_mesh_node.mesh == null:
		print("Target node has no mesh resource!")
		return

	var aabb = target_mesh_node.mesh.get_aabb()

	# Create the collision node
	var collision_node = GPUParticlesCollisionSDF3D.new()
	collision_node.name = "GPUParticlesCollisionSDF3D"

	target_mesh_node.add_child(collision_node)

	# Set owner to the edited scene root so the new node is saved with the scene
	var root = get_tree().edited_scene_root
	if root:
		collision_node.owner = root

	var size = aabb.size
	var center = aabb.get_center()

	if generate_mode == 1: # Outside
		size += Vector3(margin, margin, margin) * 2.0

	collision_node.size = size
	collision_node.position = center + bake_side_vector
	collision_node.thickness = thickness
	collision_node.bake_mask = bake_mask
	collision_node.resolution = resolution

	print("Generated GPUParticlesCollisionSDF3D. Please select it and click 'Bake SDF' in the toolbar.")
