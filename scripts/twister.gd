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
var move_direction_x = ""
var move_direction_y = ""
var step_status = 0
var frame_counter = 0
var on_steps = false
var just_started = true
var speed_push = 0
var passive_move : Vector3 = Vector3.ZERO


func _ready() :
	self_id = self.get_instance_id()
	self.play("none")
	just_started = true
	
	
func _physics_process(_delta: float) -> void:
	
	if Mainglobal.time_stoped : 
		sprite.pause()
	
	obj = Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]
	var obj_scene = Mainglobal.scene_objects[self_id]
	Mainglobal.update_object_z_index(self_id)

	if just_started :
		if Mainglobal.setup_sound_fx : $Wind.play()
		var detected_intersect = false
		just_started = false
		
		if Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]["direction_x"] == "" :
			Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]["direction_x"] = "up"
		if Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]["direction_y"] == "" :
			Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]["direction_y"] = "left"

		move_direction_x = Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]["direction_x"]
		move_direction_y = Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]["direction_y"]

		Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]["life"] = 99
		Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]["status"]= "none"
		for check_obj_scene in Mainglobal.scene_objects :
			if check_obj_scene != self_id :
				var has_intersect=Mainglobal.check_intersection(check_obj_scene,Mainglobal.scene_objects[check_obj_scene]["pos"])
				if has_intersect[0] and has_intersect[1] == self_id :
					Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]["life"] = 0
					Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]["status"] = "dead"
					if has_intersect[3] in ["movable","portable"] :
						var object_to_push = get_node("/root/Main/Room/RoomElements/NonFixedObjects/"+has_intersect[2])
						object_to_push.push(obj,0.5,999,"upper",true)
					detected_intersect = true
		if detected_intersect :
			self.queue_free()
		else :
			sprite.play("twister")

	if obj["life"] < 1 :
		$Wind.stop()
		Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]["status"] = "dead"
		Mainglobal.scene_objects.erase(self_id)
		self.queue_free()
		return
	
	frame_counter += 1
	if frame_counter > 2 :
		frame_counter = 0
		return
	

	var prev_pos_iso = obj_scene["pos"]
	var new_pos_iso = prev_pos_iso 
	var new_pos_iso_x = prev_pos_iso 
	var new_pos_iso_y = prev_pos_iso
	
	if not Mainglobal.time_stoped : 
		new_pos_iso += Mainglobal.get_vector_direction(move_direction_x) * 0.5 + Mainglobal.get_vector_direction(move_direction_y) * 0.5
		new_pos_iso_x += Mainglobal.get_vector_direction(move_direction_x) * 0.5
		new_pos_iso_y += Mainglobal.get_vector_direction(move_direction_y) * 0.5
		
	var new_pos_iso_center = new_pos_iso + obj_scene["size"]/2

	Mainglobal.gravity(self_id)
		
	Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]["pos"]=Mainglobal.scene_objects[self_id]["pos"]
	
	if inertia<1 and not obj_scene["is_falling"] :
		var current_tilelevel = int(obj["pos"].z/20)+1

		var has_collision_wall  = Mainglobal.check_exists_tile_from_iso(new_pos_iso + 3*Mainglobal.get_vector_direction(move_direction_x) + 3*Mainglobal.get_vector_direction(move_direction_y),Mainglobal.origin,Mainglobal.SCALE,current_tilelevel,"wall")
		var has_collision_wall_x  = Mainglobal.check_exists_tile_from_iso(new_pos_iso + 3*Mainglobal.get_vector_direction(move_direction_x),Mainglobal.origin,Mainglobal.SCALE,current_tilelevel,"wall")
		var has_collision_wall_y  = Mainglobal.check_exists_tile_from_iso(new_pos_iso + 3*Mainglobal.get_vector_direction(move_direction_y),Mainglobal.origin,Mainglobal.SCALE,current_tilelevel,"wall")

		var has_intersect : Array = Mainglobal.check_intersection(self_id, new_pos_iso)
		var has_intersect_x : Array = Mainglobal.check_intersection(self_id, new_pos_iso_x)
		var has_intersect_y : Array = Mainglobal.check_intersection(self_id, new_pos_iso_y)
		
		var reached_limit : bool = Mainglobal.check_reached_limit(new_pos_iso,obj_scene["size"], has_collision_wall,false)
		var reached_limit_x : bool = Mainglobal.check_reached_limit(new_pos_iso_x,obj_scene["size"], has_collision_wall_x,false)
		var reached_limit_y : bool = Mainglobal.check_reached_limit(new_pos_iso_y,obj_scene["size"], has_collision_wall_y,false)
		
		var has_void : bool = Mainglobal.check_exists_void_from_iso(obj_scene["pos"] + 5*Mainglobal.get_vector_direction(move_direction_x) + 5*Mainglobal.get_vector_direction(move_direction_y),Mainglobal.origin,Mainglobal.SCALE)
		var has_void_x : bool = Mainglobal.check_exists_void_from_iso(obj_scene["pos"] + 5*Mainglobal.get_vector_direction(move_direction_x),Mainglobal.origin,Mainglobal.SCALE)		
		var has_void_y : bool = Mainglobal.check_exists_void_from_iso(obj_scene["pos"] + 5*Mainglobal.get_vector_direction(move_direction_y),Mainglobal.origin,Mainglobal.SCALE)		

		var has_overlap : Array = Mainglobal.check_intersection(self_id,new_pos_iso_center-Vector3(0,0,1))


		if not has_collision_wall and not reached_limit and not has_void and not has_intersect[0] and has_overlap[3]!="gate":
			Mainglobal.scene_objects[self_id]["pos"] = new_pos_iso
			Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]["pos"] = new_pos_iso
		else :
			if has_intersect[3] in ["movable","portable"] :
				#var tween := get_tree().create_tween()
				#tween.tween_property(get_node("/root/Main/Room/RoomElements/NonFixedObjects/"+has_intersect[2]), "modulate:a", 0.0, 0.1)
				#await tween.finished
				#if is_instance_valid(get_node("/root/Main/Room/RoomElements/NonFixedObjects/"+has_intersect[2])) :
					#get_node("/root/Main/Room/RoomElements/NonFixedObjects/"+has_intersect[2]).queue_free()
				get_node("/root/Main/Room/RoomElements/NonFixedObjects/"+has_intersect[2]).vanish()
				Mainglobal.non_fixed_objects_repository[has_intersect[2]]["room"]="none"
				#Mainglobal.scene_objects.erase(has_intersect[1])



			if has_intersect[2] in ["Player"] :
				var object = get_node("/root/Main/Characters/Player")
				if not Mainglobal.player.sprite.animation.contains("attack") or not Mainglobal.player.sprite.frame == 2: 
					if has_intersect_x[0] or has_intersect_y[0] or has_intersect[0]:						object.push(obj,0.5,1 ,move_direction_x+move_direction_y,false)
					Mainglobal.update_life_player(-1)

			if has_collision_wall_x or has_collision_wall_y or has_void_x or has_void_y or reached_limit_x or reached_limit_y or has_intersect_x[0] or has_intersect_y[0] :
				if has_collision_wall_x or has_intersect_x[0] or has_void_x or reached_limit_x:
					move_direction_x = Mainglobal.get_inverse_direction(move_direction_x)
				if has_collision_wall_y or has_intersect_y[0] or has_void_y or reached_limit_y:
					move_direction_y = Mainglobal.get_inverse_direction(move_direction_y)
			elif has_intersect :
				var random = randi() % 2
				if random == 0 : move_direction_x = Mainglobal.get_inverse_direction(move_direction_x)
				if random == 1 : move_direction_y = Mainglobal.get_inverse_direction(move_direction_y)

			Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]["direction_y"] = move_direction_y
			Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]["direction_x"] = move_direction_x
			




	if inertia>0 :
		inertia = await Mainglobal.push_object(self,0.5,obj,inertia,push_direction,"characters")
		step_status = 0

	# APLICAR DESPLAZAMIENTO PASIVO (ARRASTRE)
	if passive_move != Vector3.ZERO :
		Mainglobal.scene_objects[self_id]["pos"] += passive_move
		passive_move = Vector3.ZERO

	if prev_pos_iso != Mainglobal.scene_objects[self_id]["pos"] : 
		var pos_iso_center = Mainglobal.iso_object_center(Mainglobal.scene_objects[self_id]["pos"],obj_scene["size"])
		var pos_screen = Mainglobal.iso_to_screen(pos_iso_center, Mainglobal.origin, Mainglobal.SCALE)
		global_position = pos_screen

		for object_over in Mainglobal.scene_objects :
			var has_intersect_over : Array = Mainglobal.check_over_intersection(self_id, obj["pos"] + Vector3(0,0,1), object_over)

			if has_intersect_over[0] and has_intersect_over[3] in ["movable","portable"] :
				get_node("/root/Main/Room/RoomElements/NonFixedObjects/"+has_intersect_over[2]).free()
				Mainglobal.non_fixed_objects_repository[has_intersect_over[2]]["room"]="none"
				Mainglobal.scene_objects.erase(has_intersect_over[1])

		var variation = Mainglobal.scene_objects[self_id]["pos"] - prev_pos_iso
		Mainglobal.check_over_movement(self_id, variation)


func load_data(uid_object) :
	obj = Mainglobal.characters_repository[uid_object]
	Mainglobal.load_data(uid_object,obj,sprite)


func push(_obj_from,speed,source_weight,direction,above) :
	speed_push = speed
	inertia = Mainglobal.get_inertia(source_weight,weight,above)
	push_direction = direction
	
