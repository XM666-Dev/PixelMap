class_name Atlas extends Resource

@export var src_textures: Array[Texture2D]
@export var format: Image.Format
var sizes: Array[Vector2i]
var points: Array[Vector2i]
var texture: ImageTexture


func init():
	for src_texture in src_textures:
		sizes.append(Vector2i(src_texture.get_size()))
	var atlas := Geometry2D.make_atlas(sizes)
	for point in atlas.points:
		points.append(Vector2i(point))
	var image := Image.create(atlas.size.x, atlas.size.y, false, format)
	for i in src_textures.size():
		var src_image := src_textures[i].get_image()
		src_image.convert(format)
		image.blit_rect(src_image, Rect2i(Vector2i.ZERO, sizes[i]), points[i])
	texture = ImageTexture.create_from_image(image)
