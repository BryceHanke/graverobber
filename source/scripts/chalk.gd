extends Node3D

const CHALK_MARK = preload("uid://l8swa4qt65y3")
@onready var ray_cast_3d : RayCast3D = $RayCast3D
@onready var timer = $Timer
@onready var chalk = $chalk
var og_pos := Vector3.ZERO
var draw := false
@export var chalk_instancer : MultiMeshInstance3D

func _ready():
	og_pos = chalk.position
	chalk_instancer.reparent.call_deferred(get_tree().root.get_child(0))

func _process(delta):
	if Input.is_action_pressed("r_click"):
		do_draw()
		chalk.position = lerp(chalk.position, to_local(ray_cast_3d.get_collision_point()), 10*delta)
	else:
		chalk.position = lerp(chalk.position, og_pos, 10*delta)
	if Input.is_action_pressed("r_click"):
		draw = true
	else:
		draw = false

func do_draw():
	if draw == true:
		place_mark()
		get_tree().create_timer(0.01).timeout.connect(do_draw)

func place_mark():
	if ray_cast_3d.is_colliding():
		chalk_instancer.multimesh.instance_count += 1
		var pos = ray_cast_3d.get_collision_point()+((ray_cast_3d.global_position - ray_cast_3d.get_collision_point())*0.05)
		var global_pos = to_global(pos)
		var mark = chalk_instancer.multimesh.instance_count-1
		chalk_instancer.multimesh.set_instance_transform(mark, ray_cast_3d.transform)
		var new_y = ray_cast_3d.get_collision_normal()
		var new_x = Vector3.UP.cross(new_y).normalized()
		var new_z = new_x.cross(new_y).normalized()
		chalk_instancer.multimesh.set_instance_transform(mark, Transform3D(Basis(new_x, new_y, new_z), global_pos))
