extends DE
class_name DialogueText

enum RevealType {
	NONE,
	HOP,
	FADE,
	SLIDE
}

@export var character_name: String
@export var character_icon: Texture
@export var character_h_frames :int= 1
@export var character_rest_frame :int= 0

@export_multiline var text: String
@export_range(0.1, 30.0, 0.1) var text_speed:float=1.0

@export var text_sound: AudioStream
@export var sound_volume:int
@export var min_pitch:float=0.85
@export var max_pitch:float=1.15

@export var camera_position:Vector2
@export_range(0.05, 10.0, 0.05) var camera_transition_time:float=1.0

@export var reveal_type: RevealType = RevealType.NONE
