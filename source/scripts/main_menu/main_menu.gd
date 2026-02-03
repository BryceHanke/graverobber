extends CanvasLayer

func _on_button_pressed():
	$"main menu".visible = false
	$"../AnimationPlayer".play("intro_cutscene", .1, .75)
