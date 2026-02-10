extends CanvasLayer

func _on_button_pressed():
	$"main menu".visible = false
	$"../AnimationPlayer".play("intro_cutscene", .1, .75)
	$"../AnimationPlayer2".play("fade_in", .1, .5)
