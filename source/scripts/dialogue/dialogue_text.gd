extends DE
class_name DialogueText

enum RevealType {
	NONE,
	HOP,
	FADE,
	SLIDE
}

@export var character: DialogueCharacter

@export var character_name: String
@export var character_icon: Texture2D
@export var character_h_frames :int= 0
@export var character_rest_frame :int= -1

@export_multiline var text: String
@export_range(-1.0, 30.0, 0.1) var text_speed:float=-1.0

@export var text_sound: AudioStream
@export var sound_volume:int = -999
@export var min_pitch:float=0.0
@export var max_pitch:float=0.0

@export var camera_position:Vector2
@export_range(0.05, 10.0, 0.05) var camera_transition_time:float=1.0

@export var reveal_type: RevealType = RevealType.NONE

func get_character_name() -> String:
	if character_name != "":
		return character_name
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

func get_text_speed() -> float:
	if text_speed > 0:
		return text_speed
	if character:
		return character.text_speed
	return 1.0

func get_text_sound() -> AudioStream:
	if text_sound:
		return text_sound
	if character:
		return character.text_sound
	return null

func get_sound_volume() -> int:
	if sound_volume > -990:
		return sound_volume
	if character:
		return character.sound_volume
	return 0

func get_min_pitch() -> float:
	if min_pitch > 0:
		return min_pitch
	if character:
		return character.min_pitch
	return 0.85

func get_max_pitch() -> float:
	if max_pitch > 0:
		return max_pitch
	if character:
		return character.max_pitch
	return 1.15
