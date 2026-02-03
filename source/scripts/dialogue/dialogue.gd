extends CanvasLayer

const dialogue_button_preload = preload("res://scenes/dialogue/dialogue_button.tscn")

@onready var rich_text_label :RichTextLabel = $dialogue_box/dialogue_container/RichTextLabel
@onready var sprite_2d :Sprite2D= $dialogue_box/character_icon/Sprite2D
@onready var buttons = $dialogue_box/dialogue_container/buttons

var dialogue:Array[DE]
var current_dialogue_item:int=0
var next_item:bool=true

var player : CharacterBody3D

func _ready():
	visible = false
	buttons.visible = false
	
	for i in get_tree().get_nodes_in_group("player"):
		player = i

func _process(_delta:float)->void:
	if current_dialogue_item == dialogue.size():
		if !player:
			for i in get_tree().get_nodes_in_group("player"):
				player = i
			return
		player.ig.gather_input = false
		player.camera.canlook = false
		queue_free()
		return
	if next_item:
		next_item = false
		var i = dialogue[current_dialogue_item]
		
		if i is DialogueFunction:
			if i.hide:
				visible = false
			else:
				visible = true
			_function_resource(i)
		elif i is DialogueChoice:
			visible = true
			_choice_resource(i)
		elif i is DialogueText:
			visible = true
			_text_resource(i)

func _function_resource(i:DialogueFunction) -> void:
	var target_node = get_node(i.target_path)
	if target_node.has_method(i.function_name):
		if i.function_args.size() == 0:
			target_node.call(i.function_name)
		else:
			target_node.callv(i.function_name, i.function_args)
	
	if i.wait_for_signal:
		var signal_name = i.wait_for_signal
		if target_node.has_signal(signal_name):
			var signal_state = {"done":false}
			var callable = func(_args): signal_state.done = true
			target_node.connect(signal_name, callable, CONNECT_ONE_SHOT)
			while not signal_state.done:
				await get_tree().process_frame
	if Input.is_action_just_pressed("ui_accept"):
		current_dialogue_item += 1
		next_item = true

func _choice_resource(i:DialogueChoice) -> void:
	rich_text_label.text = i.text
	rich_text_label.visible_characters = -1
	if i.character_icon:
		$dialogue_box/character_icon.visible = true
		sprite_2d.texture = i.character_icon
		sprite_2d.hframes = i.character_h_frames
		sprite_2d.frame = min(i.character_rest_frame, i.character_h_frames-1)
	else:
		$dialogue_box/character_icon.visible = false
		$dialogue_box/dialogue_container/buttons.visible = true
	
	for item in i.choice_text.size():
		var dialoguebuttonvar = dialogue_button_preload.instantiate()
		dialoguebuttonvar.text = i.choice_text[item]
		
		var function_resource: DialogueFunction = i.choice_function[item]
		if function_resource:
			dialoguebuttonvar.connect("pressed",
			Callable(get_node(function_resource.target_path), function_resource.function_name).bindv(function_resource.function_args), CONNECT_ONE_SHOT)
			if function_resource.hide:
				dialoguebuttonvar.connect("pressed", hide, CONNECT_ONE_SHOT)
			
			dialoguebuttonvar.connect("pressed",
			_choice_button_pressed.bind(get_node(function_resource.target_path), function_resource.wait_for_signal), CONNECT_ONE_SHOT)
		else:
			dialoguebuttonvar.connect("pressed", _choice_button_pressed.bind(null, ""), CONNECT_ONE_SHOT)
		$dialogue_box/dialogue_container/buttons.add_child(dialoguebuttonvar)
	$dialogue_box/dialogue_container/buttons.get_child(0).grab_focus()
	$dialogue_box/dialogue_container/buttons.visible = true

func _choice_button_pressed(target_node:Node, wait_for_signal:String):
	$dialogue_box/dialogue_container/buttons.visible = false
	for i in $dialogue_box/dialogue_container/buttons.get_children():
		i.queue_free()
	
	if wait_for_signal:
		var signal_name = wait_for_signal
		if target_node.has_signal(signal_name):
			var signal_state = {"done":false}
			var callable = func(_args): signal_state.done = true
			target_node.connect(signal_name, callable, CONNECT_ONE_SHOT)
			while not signal_state.done:
				await get_tree().process_frame
	if Input.is_action_just_pressed("ui_accept"):
		current_dialogue_item += 1
		next_item = true

func _text_resource(i:DialogueText) -> void:
	$AudioStreamPlayer.stream = i.text_sound
	$AudioStreamPlayer.volume_db = i.sound_volume
	
	if !i.character_name:
		$dialogue_box/character_icon/Sprite2D/RichTextLabel.visible = false
	else:
		$dialogue_box/character_icon/Sprite2D/RichTextLabel.text = i.character_name
	
	if !i.character_icon:
		$dialogue_box/character_icon.visible = false
	else:
		$dialogue_box/character_icon.visible = true
		sprite_2d.texture = i.character_icon
		sprite_2d.hframes = i.character_h_frames
		sprite_2d.frame = 0
	
	rich_text_label.visible_characters = 0
	rich_text_label.text = i.text
	
	var text_without_square_brackets:String = _text_without_square_brackets(i.text)
	var total_characters:int = text_without_square_brackets.length()
	var character_timer:float=0.0
	while rich_text_label.visible_characters < total_characters:
		if Input.is_action_just_pressed("ui_cancel"):
			rich_text_label.visible_characters = total_characters
			break
		
		character_timer += get_process_delta_time()
		if character_timer >= (1.0/i.text_speed) or text_without_square_brackets[rich_text_label.visible_characters] == " ":
			var character: String = text_without_square_brackets[rich_text_label.visible_characters]
			rich_text_label.visible_characters += 1
			if character != " ":
				$AudioStreamPlayer.pitch_scale = randf_range(i.min_pitch, i.max_pitch)
				$AudioStreamPlayer.play()
				if i.character_h_frames != 1:
					if sprite_2d.frame < i.character_h_frames -1:
						sprite_2d.frame += 1
					else:
						sprite_2d.frame = 0
			character_timer = 0.0
		await get_tree().process_frame
	sprite_2d.frame = min(i.character_rest_frame, i.character_h_frames-1)
	while true:
		await get_tree().process_frame
		if rich_text_label.visible_characters == total_characters:
			if Input.is_action_just_pressed("ui_accept"):
				current_dialogue_item += 1
				next_item = true
				break
				

func _text_without_square_brackets(text:String)->String:
	var result:String=""
	var inside_bracket:bool=false
	for i in text:
		if i == "[":
			inside_bracket = true
			continue
		if i == "]":
			inside_bracket = false
			continue
		if !inside_bracket:
			result += i
	return result
