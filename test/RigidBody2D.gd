extends RigidBody2D

var force := 2000

func _physics_process(_delta):
	if Input.is_key_pressed(KEY_LEFT):
		apply_force(Vector2(-force, 0))
	if Input.is_key_pressed(KEY_RIGHT):
		apply_force(Vector2(force, 0))
	if Input.is_key_pressed(KEY_UP):
		apply_force(Vector2(0, -force))
	if Input.is_key_pressed(KEY_DOWN):
		apply_force(Vector2(0, force))
