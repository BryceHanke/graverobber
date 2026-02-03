extends DE
class_name DialogueChoice

@export var character_icon: Texture
@export var character_h_frames:int=1
@export var character_rest_frame:int=0

@export_multiline var text : String

@export var choice_text:Array[String]
@export var choice_function:Array[DialogueFunction]
