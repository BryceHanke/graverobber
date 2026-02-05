extends Resource
class_name DialogueCharacter

@export var character_name: String
@export var icon: Texture2D
@export var h_frames: int = 1
@export var rest_frame: int = 0
@export_range(0.1, 30.0, 0.1) var text_speed: float = 1.0
@export var text_sound: AudioStream
@export var sound_volume: int = 0
@export var min_pitch: float = 0.85
@export var max_pitch: float = 1.15
