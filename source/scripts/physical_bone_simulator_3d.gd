@tool
extends PhysicalBoneSimulator3D

func _ready():
	# Disable collision with player/world for all physical bones to prevent glitches
	# while allowing inertial swing.
	for child in get_children():
		if child is PhysicalBone3D:
			child.collision_mask = 0
			child.collision_layer = 0

	physical_bones_start_simulation()

func _physics_process(delta):
	# Pin the handle bone to the skeleton animation
	var skeleton = get_parent() as Skeleton3D
	if not skeleton:
		return

	var handle_bone_node = get_node_or_null("Physical Bone Bone")
	if handle_bone_node:
		var bone_idx = skeleton.find_bone("Bone")
		if bone_idx != -1:
			# Get the global transform of the bone from the skeleton
			# This pins the physical bone to the animated position, making it act as a kinematic anchor
			var target_transform = skeleton.global_transform * skeleton.get_bone_global_pose(bone_idx)

			# Force the physical bone to match the animation
			handle_bone_node.global_transform = target_transform
			handle_bone_node.linear_velocity = Vector3.ZERO
			handle_bone_node.angular_velocity = Vector3.ZERO
