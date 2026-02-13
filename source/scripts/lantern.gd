extends Node3D

var on := true

@onready var omni_light_3d = $Armature/Skeleton3D/Bone_001/top/base/Cylinder_001/OmniLight3D

func _process(delta):
	if Input.is_action_just_pressed("light"):
		on = !on
		if on == true:
			omni_light_3d.visible = true
		else:
			omni_light_3d.visible = false
