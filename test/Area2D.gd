extends Area2D


var c := 0
func _on_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	c += 1

func _on_body_shape_exited(body_rid, body, body_shape_index, local_shape_index):
	c -= 1
