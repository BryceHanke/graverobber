extends state
class_name monster_state

const SPEED := 1.0

@export var sound_chance := 1

@export var monster : CharacterBody3D

func play_steps():
	if monster and monster.monster_steps:
		monster.monster_steps.play()

func search_trans():
	if monster.hearing_sounds:
		Transitioned.emit(self, "search")

func wander_trans():
	if not monster.hearing_sounds:
		Transitioned.emit(self, "wander")

func randomly_play_sound():
	if randi() % 2556 <= sound_chance:
		var players = [monster.growl_player, monster.purr_player, monster.breathing_player, monster.groan_player]
		var valid_players = []
		for p in players:
			if p: valid_players.append(p)

		if not valid_players.is_empty():
			var player = valid_players.pick_random()
			player.play()

func stepping():
	if monster.velocity.length() != 0.0:
		if not monster.step_timer.timeout.is_connected(play_steps):
			monster.step_timer.timeout.connect(play_steps)
	else:
		if monster.step_timer.timeout.is_connected(play_steps):
			monster.step_timer.timeout.disconnect(play_steps)

func update_target_pos(target_pos):
	monster.target_pos = target_pos
	monster.nav_agent.set_target_position(target_pos)

func move():
	var current_location = monster.global_transform.origin
	var next_location = monster.nav_agent.get_next_path_position()
	var new_velocity = (next_location - current_location).normalized() * SPEED

	if monster.target_pos != Vector3.ZERO:
		monster.look_at(monster.target_pos, Vector3.UP, true)

	monster.velocity = new_velocity
	monster.move_and_slide()
