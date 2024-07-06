class_name Substance extends Resource

enum States {
	SOLID,
	LIQUID,
	GAS
}

@export var name: StringName
@export var textures: Array[Texture2D]
@export var state: States
