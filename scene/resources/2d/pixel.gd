class_name Pixel extends Resource

enum States {
	SOLID,
	LIQUID,
	GAS
}

@export var name: StringName
@export var textures: Array[Texture2D]
@export var state: States
var id: int
