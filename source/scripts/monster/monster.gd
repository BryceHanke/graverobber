extends CharacterBody3D
class_name monster

var target_pos := Vector3.ZERO
var hearing_sounds := false

@export var player : player_controller

@export var monster_steps : AudioStreamPlayer3D
@export var purr_player : AudioStreamPlayer3D
@export var groan_player : AudioStreamPlayer3D
@export var screech_player : AudioStreamPlayer3D

@export var step_timer : Timer
@export var search_timer : Timer
@export var screech_timer : Timer
@export var wander_timer : Timer

@export var nav_agent : NavigationAgent3D

@onready var loud_hearing_radius :Area3D= $large_hearing_radius
@onready var hearing_radius :Area3D= $hearing_radius
@onready var search = $logic/statemachine/search

@export var sight_rays : Array[RayCast3D]


func _ready():
	player.connect("is_loud", hear_loud_sounds)
	player.connect("made_sound", hear_sounds)
	search_timer.connect("timeout", dont_hear_sounds)

func hear_sounds():
	if hearing_radius.has_overlapping_areas():
		hearing_sounds = true
		search_timer.start()
	else:
		hearing_sounds = false

func see_player() -> bool:
	for r in sight_rays:
		if r.is_colliding():
			if r.get_collider().is_in_group("player"):
				return true
	return false

func hear_loud_sounds():
	if loud_hearing_radius.has_overlapping_areas():
		hearing_sounds = true
		search_timer.start()
	else:
		hearing_sounds = false

func dont_hear_sounds():
	hearing_sounds = false
	search_timer.stop()
