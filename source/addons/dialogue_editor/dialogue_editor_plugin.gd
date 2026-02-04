@tool
extends EditorPlugin

var dock
var dock_button

func _enter_tree():
	dock = preload("res://addons/dialogue_editor/dialogue_editor.tscn").instantiate()
	dock.undo_redo = get_undo_redo()
	dock_button = add_control_to_bottom_panel(dock, "Dialogue")
	dock_button.hide()

func _exit_tree():
	remove_control_from_bottom_panel(dock)
	dock.free()

func _handles(object):
	if object is Node and object.get_script():
		var script = object.get_script()
		# Check if script is handle_dialogue.gd
		return script.resource_path.ends_with("handle_dialogue.gd")
	return false

func _edit(object):
	dock.set_node(object)

func _make_visible(visible):
	if visible:
		dock_button.show()
		make_bottom_panel_item_visible(dock)
	else:
		dock_button.hide()
		if dock.is_visible_in_tree():
			hide_bottom_panel()
