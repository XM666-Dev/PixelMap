class_name MathUtils


static func for_rect(rect: Rect2i, callable: Callable):
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			callable.call(Vector2i(x, y))
