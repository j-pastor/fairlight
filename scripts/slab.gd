extends AnimatedSprite2D

var uid : String = ""
var type : String = ""
var subtype : String = ""
var weight : int = 6
var pos : Vector3 = Vector3.ZERO
var size : Vector3 = Vector3.ZERO
var sprite : AnimatedSprite2D = self
var inertia := 0
var obj = null
var self_id = null
var push_direction = ""
var move_direction = ""
var step_status = 0
var frame_counter = 0
var frame_counter_rebirth = 0
var on_steps = false
var gold_target = null

var player_last_damage = 0
var speed_push = 0

var passive_move := Vector3.ZERO

func _ready() :
	self_id = self.get_instance_id()
	frame_counter_rebirth = 0

func _physics_process(delta: float) -> void:

	if Mainglobal.time_stoped : 
		sprite.pause()
	else :
		sprite.play()

	
	var obj_scene = Mainglobal.scene_objects[self_id]
	Mainglobal.update_object_z_index(self_id)

	if inertia>0 :
		inertia = await Mainglobal.push_object(self,speed_push,obj,inertia,push_direction,"characters")
		step_status = 0

	if obj["life"] < 1 :
		Mainglobal.replace_guard_by_helmet(self_id, Mainglobal.scene_objects[self_id]["name"],18)
		return
	
	
	

	Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]["status"] = "none"
	obj_scene["status"] = "none"
	Mainglobal.scene_objects[self_id]["status"] = "none"
	
	
	frame_counter += 1
	
	if frame_counter > 1 :
		frame_counter = 0
		return
		
	var subtype = obj["subtype"]
	var prev_pos_iso = obj_scene["pos"]
	var new_pos_iso = prev_pos_iso
	if not Mainglobal.time_stoped : new_pos_iso += Mainglobal.get_vector_direction(move_direction) * 1
	#var new_pos_iso_center = new_pos_iso + obj_scene["size"]/2
	var new_pos_iso_center = new_pos_iso +  Vector3(obj["size"].x/2,obj["size"].y/2,0)

	move_direction = obj["direction"]
	
	if not Mainglobal.time_stoped : 
		sprite.play("walk-"+move_direction)
		
	Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]["pos"]=Mainglobal.scene_objects[self_id]["pos"]
	
	if inertia<1 and not obj_scene["is_falling"] :
		var current_tilelevel = int(obj["pos"].z/20)+1
		var has_collision_wall  = Mainglobal.check_exists_tile_from_iso(new_pos_iso + 1*Mainglobal.get_vector_direction(move_direction),Mainglobal.origin,Mainglobal.SCALE,current_tilelevel,"wall")
		var has_intersect : Array = Mainglobal.check_intersection(self_id, new_pos_iso)
		var reached_limit : bool = Mainglobal.check_reached_limit(new_pos_iso,obj_scene["size"], has_collision_wall,false)
		var has_void : bool = Mainglobal.check_exists_void_from_iso(obj_scene["pos"] + 5*Mainglobal.get_vector_direction(move_direction),Mainglobal.origin,Mainglobal.SCALE)
		var has_overlap : Array = Mainglobal.check_intersection(self_id,new_pos_iso_center-Vector3(0,0,1))
		var has_overlap_bottom : Array = Mainglobal.check_intersection(self_id,Vector3(new_pos_iso_center.x, new_pos_iso_center.y, 0) - Vector3(0,0,1))

		if not has_collision_wall and not reached_limit and not has_void and not has_intersect[0] and has_overlap[3]!="gate" and has_overlap_bottom[3]!="gate":
			step_status = 0
			on_steps = false
			Mainglobal.scene_objects[self_id]["pos"] = new_pos_iso
			Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]["pos"] = new_pos_iso
		else :
			if has_intersect[3] in ["movable","portable"] :
				var object = get_node("/root/Main/Room/RoomElements/NonFixedObjects/"+has_intersect[2])
				object.push(obj,1,6,move_direction,false)
				

			if has_intersect[2] in ["Player"] :
				var object = get_node("/root/Main/Characters/"+has_intersect[2])
				if Mainglobal.player.sprite.animation.contains("attack") and Mainglobal.player.sprite.frame in [2]: 
					pass
				else :
					object.push(obj,1,1 ,move_direction,false)

			
			if move_direction == "left" : move_direction = "right"
			elif move_direction == "right" : move_direction = "left"
			elif move_direction == "down" : move_direction = "up"
			elif move_direction == "up" : move_direction = "down"
			obj["direction"] = move_direction

	#if inertia>0 :
		#inertia = Mainglobal.push_object(self,obj,inertia,push_direction,"characters")
		#step_status = 0

	# APLICAR DESPLAZAMIENTO PASIVO (ARRASTRE)
	if passive_move != Vector3.ZERO :
		Mainglobal.scene_objects[self_id]["pos"] += passive_move
		passive_move = Vector3.ZERO


	if prev_pos_iso != Mainglobal.scene_objects[self_id]["pos"] : 
		
		var variation = Mainglobal.scene_objects[self_id]["pos"] - prev_pos_iso
		var pos_iso_center = Mainglobal.iso_object_center(Mainglobal.scene_objects[self_id]["pos"],obj_scene["size"])
		var pos_screen = Mainglobal.iso_to_screen(pos_iso_center, Mainglobal.origin, Mainglobal.SCALE)

		global_position = pos_screen

		Mainglobal.check_over_movement(self_id,variation)



func load_data(uid) :
	obj = Mainglobal.characters_repository[uid]
	Mainglobal.load_data(uid,obj,sprite)


func push(obj_from,speed,source_weight,direction,above) :
	speed_push = speed
	inertia = Mainglobal.get_inertia(source_weight,weight,above)
	push_direction = direction
	
