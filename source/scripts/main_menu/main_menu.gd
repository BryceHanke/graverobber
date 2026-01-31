extends Control

@onready var animation_player = $"../AnimationPlayer"

func _on_new_game_pressed():
	animation_player.play("fade_out")
	await get_tree().create_timer(1).timeout
	get_tree().change_scene_to_file("res://scenes/basement/basement.tscn")
