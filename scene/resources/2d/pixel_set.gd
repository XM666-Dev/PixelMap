@tool
class_name PixelSet extends Resource

@export var pixels: Array[Pixel]:
	set(_pixels):
		pixels = _pixels
		emit_changed()

var data: PackedByteArray
var texture: ImageTexture

func _init():
	connect(&"changed", changed)

func changed():
	var textures := [] as Array[Texture2D]
	for pixel in pixels:
		for texture in pixel.textures:
			textures.append(texture)
	var atlas := IS.make_atlas(textures, Image.FORMAT_RGBA8)
	var ints := PackedInt32Array()
	var i := 0
	for pixel in pixels:
		pixel.id = i
		for j in pixel.textures.size():
			ints.append(int(atlas.atlas_textures[i].region.position.x))
			ints.append(int(atlas.atlas_textures[i].region.position.y))
			ints.append(int(atlas.atlas_textures[i].region.size.x))
			ints.append(int(atlas.atlas_textures[i].region.size.y))
			ints.append(pixel.textures.size())
			ints.append(0)
			i += 1
	data = ints.to_byte_array()
	texture = atlas.texture
