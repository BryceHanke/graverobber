extends DE
class_name DialogueChoice

@export var character: DialogueCharacter

@export var character_icon: Texture2D
@export var character_h_frames:int=0
@export var character_rest_frame:int=-1

@export_multiline var text : String

@export var choice_text:Array[String]
@export var choice_function:Array[DialogueFunction]

func get_character_name() -> String:
	if character:
		return character.character_name
	return ""

func get_character_icon() -> Texture2D:
	if character_icon:
		return character_icon
	if character:
		return character.icon
	return null

func get_character_h_frames() -> int:
	if character_h_frames > 0:
		return character_h_frames
	if character:
		return character.h_frames
	return 1

func get_character_rest_frame() -> int:
	if character_rest_frame >= 0:
		return character_rest_frame
	if character:
		return character.rest_frame
	return 0
