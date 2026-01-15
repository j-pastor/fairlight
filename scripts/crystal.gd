extends AnimatedSprite2D

var uid : String = ""
var type : String = ""
var subtype : String = ""
var weight : int = 0
var pos : Vector3 = Vector3.ZERO
var size : Vector3 = Vector3.ZERO
var sprite : AnimatedSprite2D = self
var inertia := 0
var obj = null
var self_id = null
var push_direction = ""
var move_direction = ""
var speed_push = 0
var passive_move : Vector3 = Vector3.ZERO

signal push_finished


func _ready() :
	self_id = self.get_instance_id()


func _physics_process(delta: float) -> void:

	var obj_scene = Mainglobal.scene_objects[self_id]
	var prev_pos_iso = obj_scene["pos"]

	var status_crystal = Mainglobal.non_fixed_objects_repository[Mainglobal.scene_objects[self_id]["name"]]["status"]
	if (status_crystal == "none" or (not Mainglobal.player_on_carpet and Input.is_action_pressed("ui_pickup"))) and not push_direction.contains("upper"): 
		Mainglobal.gravity(self_id)

	sprite.play(status_crystal)
	
	if status_crystal == "active" :
		move_direction = Mainglobal.player.move_direction
		push_direction = Mainglobal.player.move_direction
		inertia = 1
		speed_push = 1

	
	Mainglobal.non_fixed_objects_repository[Mainglobal.scene_objects[self.get_instance_id()]["name"]]["pos"]=Mainglobal.scene_objects[self.get_instance_id()]["pos"]

	if inertia>0 :
		inertia = await Mainglobal.push_object(self,speed_push,obj,inertia,push_direction,"non_fixed_objects")
		emit_signal("push_finished")	
	else:
		push_direction = ""
	
	if not Mainglobal.player_on_carpet and Input.is_action_pressed("ui_jump") and status_crystal == "active":
		var new_pos_iso = Mainglobal.scene_objects[self_id]["pos"]
		new_pos_iso += Vector3(0,0,1)
		var has_intersect : Array = Mainglobal.check_intersection(self_id, new_pos_iso)

		if not has_intersect[0] :
			Mainglobal.non_fixed_objects_repository[Mainglobal.scene_objects[self_id]["name"]]["pos"] = new_pos_iso
			Mainglobal.scene_objects[self_id]["pos"] = new_pos_iso

	# APLICAR DESPLAZAMIENTO PASIVO (ARRASTRE)
	if passive_move != Vector3.ZERO :
		Mainglobal.scene_objects[self_id]["pos"] += passive_move
		passive_move = Vector3.ZERO

	if obj["pos"].z < -20 :
		Mainglobal.non_fixed_objects_repository[Mainglobal.scene_objects[self_id]["name"]]["room"]="none"
		self.queue_free()

	if prev_pos_iso != Mainglobal.scene_objects[self_id]["pos"] :
		var variation = Mainglobal.scene_objects[self_id]["pos"] - prev_pos_iso
		var pos_iso_center = Mainglobal.iso_object_center(Mainglobal.scene_objects[self.get_instance_id()]["pos"],Mainglobal.scene_objects[self.get_instance_id()]["size"])
		var pos_screen = Mainglobal.iso_to_screen(pos_iso_center, Mainglobal.origin, Mainglobal.SCALE)
		global_position = pos_screen
		Mainglobal.update_object_z_index(self_id)
		Mainglobal.check_over_movement(self_id,variation)

func _exit_tree() :
	Mainglobal.scene_objects.erase(self_id)

func load_data(uid) :
	obj = Mainglobal.non_fixed_objects_repository[uid]
	#sprite.texture = load(obj["sprite"])
	Mainglobal.load_data(uid,obj,sprite)
 
func push(obj_from,speed,source_weight,direction,above) :
	speed_push = speed
	inertia = Mainglobal.get_inertia(source_weight,obj["weight"],above)
	push_direction = direction
