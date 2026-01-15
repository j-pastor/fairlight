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
var frame_counter_bis = 0
var on_steps = false
var just_started = true
var speed_push = 0
var passive_move : Vector3 = Vector3.ZERO

func _ready() :
	self_id = self.get_instance_id()
	self.play("none")
	just_started = true
	randomize()

func _physics_process(_delta: float) -> void:
	
	obj = Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]
	var obj_scene = Mainglobal.scene_objects[self_id]
	Mainglobal.update_object_z_index(self_id)

	type = obj["type"]
	var prev_pos_iso = obj_scene["pos"]
	var new_pos_iso = prev_pos_iso
	var new_pos_iso_x = prev_pos_iso
	var new_pos_iso_y = prev_pos_iso

	if obj["pos"].z < -20 :
		Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]["room"] = "none"	
		self.queue_free()

	if just_started :
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
						object_to_push.push(obj,0.5,1,"upper",true)
					detected_intersect = true
		if detected_intersect :
			self.queue_free()
		else :
			sprite.play("bubble")

	frame_counter += 1
	if frame_counter > 2 :
		frame_counter = 0
		return

	if type == "blob" :
		frame_counter_bis += 1
		if frame_counter_bis > 20 :
			var r_x = randi_range(0,2)
			var r_y = randi_range(0,2)
			var r_values_x = ["none","up","down"]
			var r_values_y = ["none","left","right"]
			move_direction_x = r_values_x[r_x]
			move_direction_y = r_values_y[r_y]
			Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]["direction_y"] = move_direction_y
			Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]["direction_x"] = move_direction_x
			frame_counter_bis = 0	

	
	if not Mainglobal.time_stoped :
		new_pos_iso += Mainglobal.get_vector_direction(move_direction_x) * 0.5 + Mainglobal.get_vector_direction(move_direction_y) * 0.5
		new_pos_iso_x += Mainglobal.get_vector_direction(move_direction_x) * 0.5
		new_pos_iso_y += Mainglobal.get_vector_direction(move_direction_y) * 0.5

	var new_pos_iso_center = new_pos_iso + obj_scene["size"]/2

	obj_scene["pos"] -= Vector3(0,0,step_status)
	
	if not on_steps and step_status == 0 :
		Mainglobal.gravity(self_id)
		
	Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]["pos"]=Mainglobal.scene_objects[self_id]["pos"]
	
	if inertia<1 and not obj_scene["is_falling"] :
		var current_tilelevel = int(obj["pos"].z/20)+1

		var has_collision_wall  = Mainglobal.check_exists_tile_from_iso(new_pos_iso + 3 * Mainglobal.get_vector_direction(move_direction_x) + 3 * Mainglobal.get_vector_direction(move_direction_y),Mainglobal.origin,Mainglobal.SCALE,current_tilelevel,"wall")
		var has_collision_wall_x  = Mainglobal.check_exists_tile_from_iso(new_pos_iso + 3 * Mainglobal.get_vector_direction(move_direction_x) ,Mainglobal.origin,Mainglobal.SCALE,current_tilelevel,"wall")
		var has_collision_wall_y  = Mainglobal.check_exists_tile_from_iso(new_pos_iso + 3 * Mainglobal.get_vector_direction(move_direction_y) ,Mainglobal.origin,Mainglobal.SCALE,current_tilelevel,"wall")

		var has_intersect : Array = Mainglobal.check_intersection(self_id, new_pos_iso)
		var has_intersect_x : Array = Mainglobal.check_intersection(self_id, new_pos_iso_x)
		var has_intersect_y : Array = Mainglobal.check_intersection(self_id, new_pos_iso_y)
		
		var has_below : Array = Mainglobal.check_intersection(self_id, new_pos_iso-Vector3(0,0,1))
		
		var reached_limit : bool = Mainglobal.check_reached_limit(new_pos_iso,obj_scene["size"], has_collision_wall,false)
		var reached_limit_x : bool = Mainglobal.check_reached_limit(new_pos_iso_x,obj_scene["size"], has_collision_wall_x,false)
		var reached_limit_y : bool = Mainglobal.check_reached_limit(new_pos_iso_y,obj_scene["size"], has_collision_wall_y,false)
		
		var has_void : bool = Mainglobal.check_exists_void_from_iso(obj_scene["pos"] + 5*Mainglobal.get_vector_direction(move_direction_x) + 5*Mainglobal.get_vector_direction(move_direction_y),Mainglobal.origin,Mainglobal.SCALE)
		var has_void_x : bool = Mainglobal.check_exists_void_from_iso(obj_scene["pos"] + 5*Mainglobal.get_vector_direction(move_direction_x),Mainglobal.origin,Mainglobal.SCALE)		
		var has_void_y : bool = Mainglobal.check_exists_void_from_iso(obj_scene["pos"] + 5*Mainglobal.get_vector_direction(move_direction_y),Mainglobal.origin,Mainglobal.SCALE)		

		var has_overlap : Array = Mainglobal.check_intersection(self_id,new_pos_iso_center-Vector3(0,0,1))
		
		if not has_collision_wall and not reached_limit and not has_void and not has_intersect[0] and has_overlap[3]!="gate" and has_below[2]!="Player":
			step_status = 0
			on_steps = false
			Mainglobal.scene_objects[self_id]["pos"] = new_pos_iso
			Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]["pos"] = new_pos_iso
		else :
			on_steps = false
			# DESPLAZA OBJETOS MOVILES AL GOLPEARLOS
			if has_intersect[3] in ["movable","portable"] :
				var object = get_node("/root/Main/Room/RoomElements/NonFixedObjects/"+has_intersect[2])
				object.push(obj,0.5,1,move_direction_x+move_direction_y,false)

			if has_intersect[3] in ["guard"] :
				var object = get_node("/root/Main/Room/RoomElements/Characters/"+has_intersect[2])
				object.push(obj,0.5,1,move_direction_x+move_direction_y,false)

			## DETECTA Y SUBE ESCALERAS SI ES BUBBLE
			var detected_correct_collision_step = false
			if type == "bubble" :
				if has_intersect[3].begins_with("step-"):
					var n_steps = int(has_intersect[3].replace("step-",""))
					var dif_height : float = Mainglobal.scene_objects[has_intersect[1]]["size"].z+Mainglobal.scene_objects[has_intersect[1]]["pos"].z - obj["pos"].z
					
					if obj_scene["pos"].z + n_steps == Mainglobal.scene_objects[has_intersect[1]]["size"].z : 
						on_steps = true
						if dif_height<=n_steps and ((move_direction_x=="up" and has_intersect_x[4]=="northsouth") or (move_direction_y=="right" and has_intersect_y[4]=="westeast")):
							detected_correct_collision_step = true
							var object_to_move = null
							for object_over in Mainglobal.scene_objects :
								var has_intersect_over : Array = Mainglobal.check_over_intersection(self_id, obj_scene["pos"] + Vector3(0,0,1+step_status), object_over)
								if has_intersect_over[0] and has_intersect_over[3] in ["movable","portable"] : 
									object_to_move = Mainglobal.scene_objects[has_intersect_over[1]]["node"]
									Mainglobal.scene_objects[has_intersect_over[1]]["pos"].z += 1 + step_status
									object_to_move.push(obj,0.5,1,"upper",true)

							step_status += 1
							
							Mainglobal.scene_objects[self_id]["pos"] += Vector3(0,0,step_status)
							if step_status == n_steps :
								Mainglobal.scene_objects[self_id]["pos"] += Mainglobal.get_vector_direction(move_direction_x) + Mainglobal.get_vector_direction(move_direction_y)
								new_pos_iso = Mainglobal.scene_objects[self_id]["pos"]
								step_status = 0
							Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]["pos"] = Mainglobal.scene_objects[self_id]["pos"]
						else:
							on_steps = false

			if type == "bubble" : 
				for object_over in Mainglobal.scene_objects :
					var has_intersect_over : Array = Mainglobal.check_over_intersection(self_id, obj["pos"] + Vector3(0,0,1), object_over)
					if has_intersect_over[0] and has_intersect_over[2] in ["Player"] : 
						Mainglobal.update_life_player(-10)
						Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]["life"] -= Mainglobal.life_enemies

			if has_intersect[2] in ["Player"] or has_below[2] in ["Player"]:
				var object = get_node("/root/Main/Characters/Player")
				object.push(obj,0.5,1 ,"upper",true)
				if has_intersect[2] in ["Player"] and type == "blob": Mainglobal.update_life_player(-1)
				if has_intersect[2] in ["Player"] and type == "bubble": Mainglobal.update_life_player(-10)
				if type == "bubble" : Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]["life"] -= Mainglobal.life_enemies

			if obj["life"] < 1 :
				if Mainglobal.setup_sound_fx : $/root/Main/Sounds/Pop.play()
				Mainglobal.characters_repository.erase(Mainglobal.scene_objects[self_id]["name"])
				Mainglobal.scene_objects.erase(self_id)
				self.queue_free()
				return

			if has_collision_wall_x or has_collision_wall_y or has_void_x or has_void_y or reached_limit_x or reached_limit_y or has_intersect_x[0] or has_intersect_y[0] :
				if has_collision_wall_x or has_intersect_x[0] or has_void_x or reached_limit_x:
					if not detected_correct_collision_step : move_direction_x = Mainglobal.get_inverse_direction(move_direction_x)
				if has_collision_wall_y or has_intersect_y[0] or has_void_y or reached_limit_y:
					if not detected_correct_collision_step : move_direction_y = Mainglobal.get_inverse_direction(move_direction_y)
			elif has_intersect :
				var random = randi() % 2
				if random == 0 and not detected_correct_collision_step : move_direction_x = Mainglobal.get_inverse_direction(move_direction_x)
				if random == 1 and not detected_correct_collision_step : move_direction_y = Mainglobal.get_inverse_direction(move_direction_y)

			Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]["direction_y"] = move_direction_y
			Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]["direction_x"] = move_direction_x

	if inertia>0 :
		inertia = await Mainglobal.push_object(self,speed_push,obj,inertia,push_direction,"characters")
		step_status = 0

	# APLICAR DESPLAZAMIENTO PASIVO (ARRASTRE)
	if passive_move != Vector3.ZERO :
		Mainglobal.scene_objects[self_id]["pos"] += passive_move
		passive_move = Vector3.ZERO

	if prev_pos_iso != Mainglobal.scene_objects[self_id]["pos"] : 

		var variation = Mainglobal.scene_objects[self_id]["pos"] - prev_pos_iso
		Mainglobal.check_over_movement(self_id, variation)

		var pos_iso_center = Mainglobal.iso_object_center(Mainglobal.scene_objects[self_id]["pos"],obj_scene["size"])
		var pos_screen = Mainglobal.iso_to_screen(pos_iso_center, Mainglobal.origin, Mainglobal.SCALE)
		global_position = pos_screen

func load_data(uid_object) :
	obj = Mainglobal.characters_repository[uid_object]
	Mainglobal.load_data(uid_object,obj,sprite)

func _exit_tree() :
	Mainglobal.scene_objects.erase(self_id)

func push(obj_from,speed,source_weight,direction,above) :
	speed_push = speed
	if obj_from["type"]=="portable" and obj_from["subtype"] == "crystal" :
		Mainglobal.lightning(self, obj_from)
	inertia = Mainglobal.get_inertia(source_weight,weight,above)
	push_direction = direction

	
