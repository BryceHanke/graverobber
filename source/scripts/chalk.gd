extends Node3D

@export var mesh : Mesh
@export var material : Material

@onready var raycast : RayCast3D = $RayCast3D
@onready var multimesh_instance : MultiMeshInstance3D = $MultiMeshInstance3D

func _ready():
	if not multimesh_instance.multimesh:
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		if mesh:
			mm.mesh = mesh
		else:
			var quad = QuadMesh.new()
			quad.size = Vector2(0.1, 0.1)
			mm.mesh = quad
		multimesh_instance.multimesh = mm

	if material:
		multimesh_instance.material_override = material

	# Set a large custom AABB to prevent culling when the camera looks away from the origin
	# Since the MultiMeshInstance3D is top_level at (0,0,0), its default AABB is small.
	multimesh_instance.custom_aabb = AABB(Vector3(-10000, -10000, -10000), Vector3(20000, 20000, 20000))

func _process(delta):
	if Input.is_action_just_pressed("interact"):
		place_chalk()

func place_chalk():
	if raycast.is_colliding():
		var point = raycast.get_collision_point()
		var normal = raycast.get_collision_normal()

		var mm = multimesh_instance.multimesh
		# Resize multimesh
		var count = mm.instance_count
		mm.instance_count = count + 1

		var origin = point + normal * 0.01 # Slightly offset to avoid z-fighting

		# Align +Z with normal so front face points away from surface.
		# looking_at sets -Z to point at target.
		# We want +Z to point at normal (away from surface). So -Z points at -normal (into surface).
		# We construct a basis looking at -normal from (0,0,0).
		var look_target = -normal

		var up_vector = Vector3.UP
		if abs(normal.dot(Vector3.UP)) > 0.99:
			up_vector = Vector3.RIGHT

		var transform = Transform3D().looking_at(look_target, up_vector)
		transform.origin = origin

		mm.set_instance_transform(count, transform)
