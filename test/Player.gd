extends Node2D

func _physics_process(_delta):
	if Input.is_key_pressed(KEY_A):
		position.x -= 10
	elif Input.is_key_pressed(KEY_D):
		position.x += 10
	if Input.is_key_pressed(KEY_W):
		position.y -= 10
	elif Input.is_key_pressed(KEY_S):
		position.y += 10
