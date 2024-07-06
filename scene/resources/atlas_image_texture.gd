@tool
class_name AtlasImageTexture extends ImageTexture

@export var src_textures: Array[Texture2D]:
	set(_src_textures):
		src_textures = _src_textures
		changed()
@export var format: Image.Format:
	set(_format):
		format = _format
		changed()
var atlas_textures: Array[AtlasTexture]

func changed():
	var _src_textures := IS.array(&"Texture2D", src_textures.filter(func(texture): return texture != null)) as Array[Texture2D]
	var sizes := PackedVector2Array(_src_textures.map(func(texture): return texture.get_size()))
	var atlas := Geometry2D.make_atlas(sizes)
	var image := Image.create(atlas.size.x, atlas.size.y, false, format)
	atlas_textures.resize(_src_textures.size())
	for i in _src_textures.size():
		var src_image := _src_textures[i].get_image()
		src_image.convert(format)
		image.blit_rect(src_image, Rect2i(Vector2i.ZERO, sizes[i]), atlas.points[i])
		var atlas_texture := AtlasTexture.new()
		atlas_texture.atlas = self
		atlas_texture.region = Rect2(atlas.points[i], sizes[i])
		atlas_textures[i] = atlas_texture
	set_image(image)
