@tool
extends Control

var current_node: Node
var undo_redo: EditorUndoRedoManager

var split_container: HSplitContainer
var list_container: VBoxContainer
var item_list: ItemList
var editor_container: VBoxContainer
var toolbar: HBoxContainer

func _ready():
	custom_minimum_size.y = 250

	split_container = HSplitContainer.new()
	split_container.layout_mode = 1
	split_container.anchors_preset = Control.PRESET_FULL_RECT
	add_child(split_container)

	# Left Side
	list_container = VBoxContainer.new()
	list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_container.size_flags_stretch_ratio = 0.3
	list_container.custom_minimum_size.x = 200
	split_container.add_child(list_container)

	toolbar = HBoxContainer.new()
	list_container.add_child(toolbar)

	create_button(toolbar, "+ T", _on_add_text, "Add Text")
	create_button(toolbar, "+ C", _on_add_choice, "Add Choice")
	create_button(toolbar, "+ F", _on_add_func, "Add Function")
	create_button(toolbar, "-", _on_remove, "Remove Selected")

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)

	create_button(toolbar, "Up", _on_move_up, "Move Up")
	create_button(toolbar, "Dn", _on_move_down, "Move Down")

	item_list = ItemList.new()
	item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_list.item_selected.connect(_on_item_selected)
	list_container.add_child(item_list)

	# Right Side
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 0.7
	split_container.add_child(scroll)

	editor_container = VBoxContainer.new()
	editor_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(editor_container)

func create_button(parent, text, callable, tooltip=""):
	var btn = Button.new()
	btn.text = text
	btn.tooltip_text = tooltip
	btn.pressed.connect(callable)
	parent.add_child(btn)

func set_node(node):
	if current_node == node:
		return
	current_node = node
	refresh_list()

func refresh_list():
	var old_idx = -1
	if item_list.get_selected_items().size() > 0:
		old_idx = item_list.get_selected_items()[0]

	item_list.clear()
	if not current_node or not "dialogue" in current_node:
		return

	var dialogue = current_node.dialogue
	for i in range(dialogue.size()):
		var item = dialogue[i]
		var label = str(i)
		if item == null:
			label += ": [NULL]"
			item_list.add_item(label)
			continue

		if item is DialogueText:
			label += " [Text] "
			if item.text:
				label += item.text.left(30).replace("\n", " ")
		elif item is DialogueChoice:
			label += " [Choice] "
			if item.text:
				label += item.text.left(30)
		elif item is DialogueFunction:
			label += " [Func] "
			if item.function_name:
				label += item.function_name
		else:
			label += " [Unknown]"

		item_list.add_item(label)

	if old_idx >= 0 and old_idx < item_list.item_count:
		item_list.select(old_idx)
		_on_item_selected(old_idx)
	else:
		# Clear editor if nothing selected
		for c in editor_container.get_children():
			c.queue_free()

func _on_add_text():
	_add_item(DialogueText.new())

func _on_add_choice():
	_add_item(DialogueChoice.new())

func _on_add_func():
	_add_item(DialogueFunction.new())

func _add_item(res):
	if not current_node: return

	if undo_redo:
		undo_redo.create_action("Add Dialogue Item")
		var new_dialogue = current_node.dialogue.duplicate()
		new_dialogue.append(res)

		undo_redo.add_do_property(current_node, "dialogue", new_dialogue)
		undo_redo.add_undo_property(current_node, "dialogue", current_node.dialogue.duplicate())
		undo_redo.add_do_method(self, "refresh_list")
		undo_redo.add_undo_method(self, "refresh_list")
		undo_redo.commit_action()
	else:
		current_node.dialogue.append(res)
		refresh_list()

func _on_remove():
	if not current_node: return
	var items = item_list.get_selected_items()
	if items.size() == 0: return
	var idx = items[0]

	if undo_redo:
		undo_redo.create_action("Remove Dialogue Item")
		var new_dialogue = current_node.dialogue.duplicate()
		new_dialogue.remove_at(idx)
		undo_redo.add_do_property(current_node, "dialogue", new_dialogue)
		undo_redo.add_undo_property(current_node, "dialogue", current_node.dialogue.duplicate())
		undo_redo.add_do_method(self, "refresh_list")
		undo_redo.add_undo_method(self, "refresh_list")
		undo_redo.commit_action()
	else:
		current_node.dialogue.remove_at(idx)
		refresh_list()

func _on_move_up():
	if not current_node: return
	var items = item_list.get_selected_items()
	if items.size() == 0: return
	var idx = items[0]
	if idx > 0:
		if undo_redo:
			undo_redo.create_action("Move Up")
			var new_dialogue = current_node.dialogue.duplicate()
			var item = new_dialogue[idx]
			new_dialogue.remove_at(idx)
			new_dialogue.insert(idx - 1, item)
			undo_redo.add_do_property(current_node, "dialogue", new_dialogue)
			undo_redo.add_undo_property(current_node, "dialogue", current_node.dialogue.duplicate())
			undo_redo.add_do_method(self, "refresh_list")
			undo_redo.add_undo_method(self, "refresh_list")
			undo_redo.commit_action()

			item_list.select(idx - 1)
			_on_item_selected(idx - 1)
		else:
			var item = current_node.dialogue[idx]
			current_node.dialogue.remove_at(idx)
			current_node.dialogue.insert(idx - 1, item)
			refresh_list()
			item_list.select(idx - 1)
			_on_item_selected(idx - 1)

func _on_move_down():
	if not current_node: return
	var items = item_list.get_selected_items()
	if items.size() == 0: return
	var idx = items[0]
	if idx < current_node.dialogue.size() - 1:
		if undo_redo:
			undo_redo.create_action("Move Down")
			var new_dialogue = current_node.dialogue.duplicate()
			var item = new_dialogue[idx]
			new_dialogue.remove_at(idx)
			new_dialogue.insert(idx + 1, item)
			undo_redo.add_do_property(current_node, "dialogue", new_dialogue)
			undo_redo.add_undo_property(current_node, "dialogue", current_node.dialogue.duplicate())
			undo_redo.add_do_method(self, "refresh_list")
			undo_redo.add_undo_method(self, "refresh_list")
			undo_redo.commit_action()

			item_list.select(idx + 1)
			_on_item_selected(idx + 1)
		else:
			var item = current_node.dialogue[idx]
			current_node.dialogue.remove_at(idx)
			current_node.dialogue.insert(idx + 1, item)
			refresh_list()
			item_list.select(idx + 1)
			_on_item_selected(idx + 1)

func _on_item_selected(index):
	for c in editor_container.get_children():
		c.queue_free()

	if not current_node: return
	if index < 0 or index >= current_node.dialogue.size(): return

	var item = current_node.dialogue[index]
	if not item: return

	var btn_inspect = Button.new()
	btn_inspect.text = "Open in Inspector"
	btn_inspect.pressed.connect(func(): EditorInterface.edit_resource(item))
	editor_container.add_child(btn_inspect)

	if item is DialogueText:
		_add_label("Dialogue Text", true)
		_add_resource_prop(item, "character", "Character", "Resource")
		_add_string_prop(item, "character_name", "Override Name")
		_add_multiline_string_prop(item, "text", "Text")
		_add_float_prop(item, "text_speed", "Speed (<=0 uses char)", -1.0, 30.0)
		_add_resource_prop(item, "character_icon", "Override Icon", "Texture2D")
		_add_resource_prop(item, "text_sound", "Sound", "AudioStream")
		_add_int_prop(item, "character_h_frames", "H Frames", 0, 100)
		_add_int_prop(item, "character_rest_frame", "Rest Frame", -1, 100)
		_add_int_prop(item, "sound_volume", "Volume", -999, 20)
		_add_float_prop(item, "min_pitch", "Min Pitch", 0.0, 4.0)
		_add_float_prop(item, "max_pitch", "Max Pitch", 0.0, 4.0)
		_add_enum_prop(item, "reveal_type", "Reveal Type", {"NONE": 0, "HOP": 1, "FADE": 2, "SLIDE": 3})

	elif item is DialogueChoice:
		_add_label("Dialogue Choice", true)
		_add_resource_prop(item, "character", "Character", "Resource")
		_add_multiline_string_prop(item, "text", "Prompt Text")
		_add_resource_prop(item, "character_icon", "Override Icon", "Texture2D")
		_add_int_prop(item, "character_h_frames", "H Frames", 0, 100)
		_add_int_prop(item, "character_rest_frame", "Rest Frame", -1, 100)

		_add_label("Choices:", true)
		_build_choices_editor(item)

	elif item is DialogueFunction:
		_add_label("Dialogue Function", true)
		_add_string_prop(item, "target_path", "Target Path")
		_add_string_prop(item, "function_name", "Function Name")
		_add_bool_prop(item, "hide", "Hide Dialogue Box")
		_add_string_prop(item, "wait_for_signal", "Wait Signal")

func _add_label(text, bold=false):
	var l = Label.new()
	l.text = text
	if bold:
		l.add_theme_font_override("font", get_theme_font("bold", "EditorFonts"))
	editor_container.add_child(l)

func _add_string_prop(obj, prop, label_text):
	var hbox = HBoxContainer.new()
	editor_container.add_child(hbox)
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 120
	hbox.add_child(label)

	var edit = LineEdit.new()
	edit.text = str(obj.get(prop)) if obj.get(prop) != null else ""
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_changed.connect(func(new_text):
		obj.set(prop, new_text)
		if prop == "function_name": refresh_list_labels_only()
	)
	hbox.add_child(edit)

func _add_multiline_string_prop(obj, prop, label_text):
	var vbox = VBoxContainer.new()
	editor_container.add_child(vbox)
	var label = Label.new()
	label.text = label_text
	vbox.add_child(label)

	var edit = TextEdit.new()
	edit.text = str(obj.get(prop)) if obj.get(prop) != null else ""
	edit.custom_minimum_size.y = 80
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_changed.connect(func():
		obj.set(prop, edit.text)
		if prop == "text": refresh_list_labels_only()
	)
	vbox.add_child(edit)

func _add_float_prop(obj, prop, label_text, min_val, max_val):
	var hbox = HBoxContainer.new()
	editor_container.add_child(hbox)
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 120
	hbox.add_child(label)

	var spin = SpinBox.new()
	spin.min_value = min_val
	spin.max_value = max_val
	spin.step = 0.1
	spin.value = obj.get(prop)
	spin.value_changed.connect(func(val): obj.set(prop, val))
	hbox.add_child(spin)

func _add_int_prop(obj, prop, label_text, min_val=-1, max_val=100):
	var hbox = HBoxContainer.new()
	editor_container.add_child(hbox)
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 120
	hbox.add_child(label)

	var spin = SpinBox.new()
	spin.min_value = min_val
	spin.max_value = max_val
	spin.value = obj.get(prop)
	spin.value_changed.connect(func(val): obj.set(prop, int(val)))
	hbox.add_child(spin)

func _add_bool_prop(obj, prop, label_text):
	var hbox = HBoxContainer.new()
	editor_container.add_child(hbox)
	var check = CheckBox.new()
	check.text = label_text
	check.button_pressed = obj.get(prop)
	check.toggled.connect(func(val): obj.set(prop, val))
	hbox.add_child(check)

func _add_enum_prop(obj, prop, label_text, options):
	var hbox = HBoxContainer.new()
	editor_container.add_child(hbox)
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 120
	hbox.add_child(label)

	var opt = OptionButton.new()
	for k in options.keys():
		opt.add_item(k, options[k])

	# Assuming index matches value for simple enums
	opt.selected = obj.get(prop)
	opt.item_selected.connect(func(idx):
		obj.set(prop, opt.get_item_id(idx))
	)
	hbox.add_child(opt)

func _add_resource_prop(obj, prop, label_text, type_hint="Resource"):
	# Simplified texture picker (just resource path text for now, maybe Drag and Drop later)
	# Or use EditorResourcePicker if available in ClassDB, but it is not easily instantiable via script in 3.x, maybe 4.x?
	# In 4.x, EditorResourcePicker exists.
	var hbox = HBoxContainer.new()
	editor_container.add_child(hbox)
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 120
	hbox.add_child(label)

	var picker = EditorResourcePicker.new()
	picker.base_type = type_hint
	picker.edited_resource = obj.get(prop)
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.resource_changed.connect(func(res): obj.set(prop, res))
	hbox.add_child(picker)

func _build_choices_editor(choice_item):
	# choice_item has .choice_text (Array[String]) and .choice_function (Array[DialogueFunction])

	var list_vbox = VBoxContainer.new()
	editor_container.add_child(list_vbox)

	var update_ui = func():
		for c in list_vbox.get_children(): list_vbox.remove_child(c); c.queue_free()

		for i in range(choice_item.choice_text.size()):
			var row = HBoxContainer.new()
			list_vbox.add_child(row)

			var txt_edit = LineEdit.new()
			txt_edit.text = choice_item.choice_text[i]
			txt_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			txt_edit.text_changed.connect(func(new_text): choice_item.choice_text[i] = new_text)
			row.add_child(txt_edit)

			var edit_func_btn = Button.new()
			edit_func_btn.text = "Func"
			# Opens a popup or sub-editor?
			# For now, let's just make it simple: We need to edit the DialogueFunction object.
			# Maybe expand it inline?
			edit_func_btn.pressed.connect(func(): _open_sub_editor(choice_item.choice_function[i]))
			row.add_child(edit_func_btn)

			var del_btn = Button.new()
			del_btn.text = "X"
			del_btn.pressed.connect(func():
				choice_item.choice_text.remove_at(i)
				choice_item.choice_function.remove_at(i)
				# Recursive call needs reference
				# We can trigger re-render
				_on_item_selected(item_list.get_selected_items()[0])
			)
			row.add_child(del_btn)

		var add_btn = Button.new()
		add_btn.text = "+ Add Option"
		add_btn.pressed.connect(func():
			choice_item.choice_text.append("New Choice")
			choice_item.choice_function.append(DialogueFunction.new())
			_on_item_selected(item_list.get_selected_items()[0])
		)
		list_vbox.add_child(add_btn)

	update_ui.call()

func _open_sub_editor(func_obj):
	# Creates a Window or just uses the editor area temporarily?
	# Window is better.
	var win = Window.new()
	win.title = "Edit Choice Function"
	win.size = Vector2(400, 300)
	# Center on screen
	win.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN

	var vbox = VBoxContainer.new()
	win.add_child(vbox)

	# Reuse prop helpers but redirected to vbox
	# We can't reuse _add_string_prop because it uses editor_container.
	# I'll manually add fields.

	var _add = func(label, prop):
		var hbox = HBoxContainer.new()
		vbox.add_child(hbox)
		var l = Label.new()
		l.text = label
		l.custom_minimum_size.x = 100
		hbox.add_child(l)
		var e = LineEdit.new()
		e.text = str(func_obj.get(prop)) if func_obj.get(prop) else ""
		e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		e.text_changed.connect(func(t): func_obj.set(prop, t))
		hbox.add_child(e)

	_add.call("Target Path", "target_path")
	_add.call("Function", "function_name")

	var close = Button.new()
	close.text = "Close"
	close.pressed.connect(func(): win.queue_free())
	vbox.add_child(close)

	win.close_requested.connect(func(): win.queue_free())
	add_child(win)
	win.popup_centered()

func refresh_list_labels_only():
	# Update text in item_list without clearing selection
	if not current_node: return
	for i in range(current_node.dialogue.size()):
		var item = current_node.dialogue[i]
		var label = str(i)
		if item == null:
			label += ": [NULL]"
		elif item is DialogueText:
			label += " [Text] " + (item.text.left(30).replace("\n", " ") if item.text else "")
		elif item is DialogueChoice:
			label += " [Choice] " + (item.text.left(30) if item.text else "")
		elif item is DialogueFunction:
			label += " [Func] " + (item.function_name if item.function_name else "")

		item_list.set_item_text(i, label)
