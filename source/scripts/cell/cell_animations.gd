extends AnimationPlayer

func _ready():
	play("main_menu")

func play_intro_cutscene():
	play("intro_cutscene")

func king_intro():
	play("king_intro")

func sad_king():
	play("sad_king")

func transition_scene():
	play("fade_out")
	await get_tree().create_timer(current_animation_length*1.5).timeout
	get_tree().change_scene_to_file("res://scenes/catacombs/catacombs_level.tscn")
