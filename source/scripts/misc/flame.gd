@tool
extends Sprite3D

@export var animation_player : AnimationPlayer
@export var is_flipped := false
@export var do_rotate := false

@export var randomize_noise := false

# Called when the node enters the scene tree for the first time.
func _ready():
	animation_player.play("flame",-1, 4)

func _process(delta):
	if randomize_noise:
		material_override.get_shader_parameter("blue_noise_texture").noise.seed = randi()
	if do_rotate:
		if is_flipped:
			rotation_degrees.y -= 500*delta
		else:
			rotation_degrees.y += 500*delta
