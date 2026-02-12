extends state
class_name monster_state

const SPEED := 1.0

@export var sound_chance := 1

@export var monster : CharacterBody3D

func play_steps():
	monster.monster_steps.play()

func search_trans():
	if monster.hearing_sounds == true:
		Transitioned.emit(self, "search")

func wander_trans():
	if monster.hearing_sounds == false:
		Transitioned.emit(self, "wander")

func randomly_play_sound():
	if randi_range(0,2555) <= sound_chance:
		var rand_number = randi_range(1,4)
		if rand_number == 1:
			monster.growl_player.play()
		elif rand_number == 2:
			monster.purr_player.play()
		elif rand_number == 3:
			monster.breathing_player.play()
		elif rand_number == 4:
			monster.groan_player.play()

func stepping():
	if monster.velocity.length() != 0.0:
		if !monster.step_timer.timeout.is_connected(play_steps):
			monster.step_timer.timeout.connect(play_steps)
	else:
		if monster.step_timer.timeout.is_connected(play_steps):
			monster.step_timer.timeout.disconnect(play_steps)

func update_target_pos(target_pos):
	monster.nav_agent.set_target_position(target_pos)

func move():
	var current_location = monster.global_transform.origin
	var next_location = monster.nav_agent.get_next_path_position()
	var new_velocity = (next_location - current_location).normalized() * SPEED
	monster.look_at(monster.target_pos, Vector3.UP, true)
	monster.velocity = new_velocity
	monster.move_and_slide()
