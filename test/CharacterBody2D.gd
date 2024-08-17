extends CharacterBody2D

func _physics_process(delta):
	position = $"..".get_local_mouse_position()
