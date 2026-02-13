extends state
class_name monster_state

var SPEED := 3.0

@export var sound_chance := 1

@export var monster_body : monster

func play_steps():
	if monster_body and monster_body.monster_steps:
		monster_body.monster_steps.play()

func search_trans():
	if monster_body.hearing_sounds && !monster_body.see_player():
		Transitioned.emit(self, "search")

func wander_trans():
	if not monster_body.hearing_sounds && !monster_body.see_player():
		Transitioned.emit(self, "wander")

func attack_trans():
	if monster_body.see_player() == true:
		Transitioned.emit(self, "attack")

func randomly_play_sound():
	if randi() % 4056 <= sound_chance:
		var players = [monster_body.purr_player, monster_body.groan_player, monster_body.screech_player]
		var valid_players = []
		for p in players:
			if p: valid_players.append(p)

		if not valid_players.is_empty():
			var player = valid_players.pick_random()
			player.play()

func stepping():
	if monster_body.velocity.length() != 0.0:
		if not monster_body.step_timer.timeout.is_connected(play_steps):
			monster_body.step_timer.timeout.connect(play_steps)
	else:
		if monster_body.step_timer.timeout.is_connected(play_steps):
			monster_body.step_timer.timeout.disconnect(play_steps)

func update_target_pos(target_pos):
	monster_body.target_pos = target_pos
	monster_body.nav_agent.set_target_position(target_pos)

func move(_delta:float):
	var current_location = monster_body.global_transform.origin
	var next_location = monster_body.nav_agent.get_next_path_position()
	var new_velocity = (next_location - current_location).normalized() * SPEED

	if monster_body.target_pos != Vector3.ZERO:
		monster_body.transform = lerp(monster_body.transform,monster_body.transform.looking_at(Vector3(monster_body.target_pos.x, monster_body.global_position.y,monster_body.target_pos.z), Vector3.UP, true), 2*_delta)
	monster_body.velocity = new_velocity
	monster_body.move_and_slide()
