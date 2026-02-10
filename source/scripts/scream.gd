extends Area3D


func _on_body_entered(body):
	$"../scream 1".play()
	queue_free()
