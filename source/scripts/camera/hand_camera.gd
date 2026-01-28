extends Camera3D

@export var cam : Camera3D

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	transform = cam.transform
