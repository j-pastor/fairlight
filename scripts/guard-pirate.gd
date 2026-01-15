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
var obj_scene = null
var self_id = null
var push_direction = ""
var move_direction = ""
var step_status = 0
var frame_counter = 0
var frame_counter_rebirth = 0
var on_steps = false
var just_started = true
var gold_target = null
var player_last_damage = 0
var speed_push = 0
var blocked_direction = ""
var passive_move : Vector3 = Vector3.ZERO
var z_jump = 0

func _ready() :
	self_id = self.get_instance_id()
	frame_counter_rebirth = 0
	just_started = true

func _physics_process(_delta: float) -> void:
	
	var prev_direction = move_direction
	
	obj = Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]
	obj_scene = Mainglobal.scene_objects[self_id]
	Mainglobal.update_object_z_index(self_id)

	type = obj["type"]
	subtype = obj["subtype"]
	var prev_pos_iso = obj_scene["pos"]
	var new_pos_iso = prev_pos_iso
	if not Mainglobal.time_stoped : new_pos_iso += Mainglobal.get_vector_direction(move_direction) * 1
	#var new_pos_iso_center = new_pos_iso + obj_scene["size"]/2
	var new_pos_iso_center = new_pos_iso +  Vector3(obj["size"].x/2,obj["size"].y/2,0)
	var distance_to_player = 9999.9999

	if Mainglobal.time_stoped : 
		sprite.pause()
		$Walk.stop()
	else :
		sprite.play()

	if obj["pos"].z < -20 :
		Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]["room"] = "none"	
		self.queue_free()

	if just_started and type == "pirate":
		just_started = false
		move_direction = obj["direction"]
		move_direction = Mainglobal.set_best_move_direction(obj_scene,move_direction,blocked_direction,type)
		var detected_intersect = false
		Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]["life"] = Mainglobal.life_enemies
		Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]["status"]= "none"
		for check_obj_scene in Mainglobal.scene_objects :
			if check_obj_scene != self_id :
				var has_intersect=Mainglobal.check_intersection(check_obj_scene,Mainglobal.scene_objects[check_obj_scene]["pos"])
				if has_intersect[0] and has_intersect[1] == self_id :
					Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]["life"] = 0
					Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]["status"] = "dead"
					if has_intersect[3] in ["movable","portable"] :
						var object_to_push = get_node("/root/Main/Room/RoomElements/NonFixedObjects/"+has_intersect[2])
						object_to_push.push(obj,0.8,999,"upper",true)
					detected_intersect = true
		if detected_intersect :
			self.queue_free()

	#if not on_steps and step_status == 0 and frame_counter == 1:
		#Mainglobal.gravity(self_id)
		#var pos_iso_center = Mainglobal.iso_object_center(Mainglobal.scene_objects[self_id]["pos"],Mainglobal.scene_objects[self_id]["size"])
		#var pos_screen = Mainglobal.iso_to_screen(pos_iso_center, Mainglobal.origin, Mainglobal.SCALE)
		#global_position = pos_screen

	if inertia>0 :
		inertia = await Mainglobal.push_object(self,speed_push,obj,inertia,push_direction,"characters")
		step_status = 0

	if obj["life"] < 1 :
		$Walk.stop()
		if type == "pirate" : 
			var tween := get_tree().create_tween()
			tween.tween_property(self, "modulate:a", 0.0, 0.5)
			await tween.finished
			Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]["status"] = "dead"
			Mainglobal.scene_objects.erase(self_id)
			self.queue_free()
		if type == "guard" :
			var tween := get_tree().create_tween()
			tween.tween_property(self, "modulate:a", 0.0, 0.5)
			await tween.finished
			Mainglobal.replace_guard_by_helmet(self_id, Mainglobal.scene_objects[self_id]["name"],18)
		return

	frame_counter += 1
	if frame_counter > 2 :
		frame_counter = 0
		return

	if type == "guard" :

		if obj["subtype"] == "guard-rebirth" and frame_counter_rebirth < 200 and not Mainglobal.time_stoped:
			frame_counter_rebirth += 1
			sprite.play("await")
			return
		
		if obj_scene["status"] == "rebirth" and self.animation != "rebirth" :
			sprite.play("rebirth")
		
		if obj_scene["status"] == "rebirth" and self.frame != 4 and not Mainglobal.time_stoped :
			return
		else :
			if obj_scene["status"] == "rebirth" :
				move_direction = "down"
				move_direction = Mainglobal.set_best_move_direction(obj_scene,move_direction,blocked_direction,type)
				sprite.play("walk-"+move_direction)
			Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]["status"] = "none"
			obj_scene["status"] = "none"
			Mainglobal.scene_objects[self_id]["status"] = "none"

		if subtype == "guard-rebirth" :
			if (gold_target != null and not gold_target in Mainglobal.scene_objects) or gold_target == null :
				gold_target = null
				for o in Mainglobal.scene_objects :
					if "subtype" in Mainglobal.scene_objects[o] and Mainglobal.scene_objects[o]["subtype"] == "gold" :
						gold_target = o

	if Mainglobal.player.obj != null and "pos" in Mainglobal.player.obj and Mainglobal.player:
		distance_to_player = Vector2(prev_pos_iso.x,prev_pos_iso.y).distance_to(Vector2(Mainglobal.player.obj["pos"].x, Mainglobal.player.obj["pos"].y))

	if distance_to_player > 30 and subtype != "guard-rebirth" and subtype != "pirate-follow":
		if subtype in ["pirate-y","guard-y"] and obj["direction"] in ["","up","down"]: move_direction = "left"
		elif subtype in ["pirate-x","guard-x"]  and obj["direction"] in ["","left","right"] : move_direction="up"
		else : move_direction = obj["direction"]
	
	if (distance_to_player <= 30 and subtype != "guard-rebirth" and subtype!= "pirate-follow") or (subtype == "guard-rebirth" and gold_target == null) or (subtype == "pirate-follow") and Mainglobal.player.obj:
		var player_pos = Mainglobal.scene_objects[Mainglobal.player.self_id]["pos"]
		var d_x = abs(prev_pos_iso.x - player_pos.x )
		var d_y = abs(prev_pos_iso.y - player_pos.y )
		if (d_x <= 5 ) or  (d_y <= 5 )  or (prev_pos_iso.x < player_pos.x and move_direction == "down") or (prev_pos_iso.x > player_pos.x and move_direction == "up") or (prev_pos_iso.y < player_pos.y and move_direction == "left") or (prev_pos_iso.y > player_pos.y and move_direction == "right") or blocked_direction == move_direction:
			if (d_x>5 or d_y>5) :
				move_direction = Mainglobal.set_best_move_direction(obj_scene,move_direction,blocked_direction,type)
			blocked_direction = ""
	
	if subtype == "guard-rebirth" and gold_target != null and gold_target in Mainglobal.scene_objects:
		if prev_pos_iso.x + 1 < Mainglobal.scene_objects[gold_target]["pos"].x  : move_direction = "down"
		elif prev_pos_iso.x - 1 > Mainglobal.scene_objects[gold_target]["pos"].x  : move_direction = "up"
		elif prev_pos_iso.y + 1 < Mainglobal.scene_objects[gold_target]["pos"].y  : move_direction = "left"
		elif prev_pos_iso.y - 1 > Mainglobal.scene_objects[gold_target]["pos"].y  : move_direction = "right"	
	
	if not Mainglobal.time_stoped : 
		sprite.play("walk-"+move_direction)
		if Mainglobal.setup_sound_fx and not $Walk.playing : $Walk.play()
	else :
		$Walk.stop()
		
	if not on_steps and step_status == 0 :
		Mainglobal.gravity(self_id)
		var pos_iso_center = Mainglobal.iso_object_center(Mainglobal.scene_objects[self_id]["pos"],Mainglobal.scene_objects[self_id]["size"])
		var pos_screen = Mainglobal.iso_to_screen(pos_iso_center, Mainglobal.origin, Mainglobal.SCALE)
		global_position = pos_screen

	Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]["pos"]=Mainglobal.scene_objects[self_id]["pos"]

	if inertia<1 and not obj_scene["is_falling"] :
		var current_tilelevel = int(obj["pos"].z/20)+1
		var has_collision_wall  = Mainglobal.check_exists_tile_from_iso(new_pos_iso + 3*Mainglobal.get_vector_direction(move_direction),Mainglobal.origin,Mainglobal.SCALE,current_tilelevel,"wall")
		var has_intersect : Array = Mainglobal.check_intersection(self_id, new_pos_iso)
		var reached_limit : bool = Mainglobal.check_reached_limit(new_pos_iso,obj_scene["size"], has_collision_wall,false)
		var has_void : bool = Mainglobal.check_exists_void_from_iso(obj_scene["pos"] + 5*Mainglobal.get_vector_direction(move_direction),Mainglobal.origin,Mainglobal.SCALE)
		var has_overlap : Array = Mainglobal.check_intersection(self_id,new_pos_iso_center-Vector3(0,0,1))
		var has_overlap_bottom : Array = Mainglobal.check_intersection(self_id,Vector3(new_pos_iso_center.x, new_pos_iso_center.y, 0) - Vector3(0,0,1))

		var prev_pos_screen = Mainglobal.iso_to_screen(prev_pos_iso + Vector3(0,0,-1),Mainglobal.origin,Mainglobal.SCALE)
		var new_pos_screen = Mainglobal.iso_to_screen(new_pos_iso + Vector3(0,0,-1) + 3*Mainglobal.get_vector_direction(move_direction),Mainglobal.origin,Mainglobal.SCALE)
		var prev_has_polygon_floor = Mainglobal.in_floor_polygon(prev_pos_iso  + Vector3(0,0,-1),prev_pos_screen)
		var new_has_polygon_floor = Mainglobal.in_floor_polygon(new_pos_iso + Vector3(0,0,-1),new_pos_screen)
		if prev_has_polygon_floor and not new_has_polygon_floor : reached_limit = true

		if not has_collision_wall and not reached_limit and not has_void and not has_intersect[0] and has_overlap[3]!="gate" and has_overlap_bottom[3]!="gate":
			step_status = 0
			on_steps = false
			Mainglobal.scene_objects[self_id]["pos"] = new_pos_iso
			Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]["pos"] = new_pos_iso
		else :
			on_steps = false
			if subtype == "guard-rebirth" and has_intersect[0] and "subtype" in Mainglobal.scene_objects[has_intersect[1]] and Mainglobal.scene_objects[has_intersect[1]]["subtype"] == "gold" :
				Mainglobal.scene_objects.erase(has_intersect[1])
				Mainglobal.non_fixed_objects_repository[has_intersect[2]]["room"] = "none"
				get_node("/root/Main/Room/RoomElements/NonFixedObjects/"+has_intersect[2]).free()
				gold_target = null

			elif has_intersect[3] in ["movable","portable"] :
				var object = get_node("/root/Main/Room/RoomElements/NonFixedObjects/"+has_intersect[2])
				object.push(obj,0.8,6,move_direction,false)

			# DETECTA Y SUBE ESCALERAS
			if has_intersect[3].begins_with("step-") and push_direction == "":
				var step_result = await Mainglobal.climb_stairs(self_id, obj_scene, has_intersect, move_direction, step_status, false)
				on_steps = step_result["on_steps"]
				step_status = step_result["step_status"]
				z_jump = step_result["z_jump"]
			else:
				step_status = 0

			if has_intersect[2] in ["Player"] :
				var object = get_node("/root/Main/Characters/"+has_intersect[2])
				if Mainglobal.player.sprite.animation.contains("attack") and Mainglobal.player.sprite.frame in [2]: 
					pass
				else :
					object.push(obj,1,1 ,move_direction,false)
					if player_last_damage == 0 : player_last_damage = Time.get_ticks_msec()
					if Time.get_ticks_msec() - player_last_damage > 150 :
						Mainglobal.update_life_player(-1)
						player_last_damage = 0
			
			if distance_to_player > 30 and subtype != "guard-rebirth" and subtype != "pirate-follow":
				if move_direction == "left" : move_direction = "right"
				elif move_direction == "right" : move_direction = "left"
				elif move_direction == "down" : move_direction = "up"
				elif move_direction == "up" : move_direction = "down"
				obj["direction"] = move_direction

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

		if blocked_direction != "" and move_direction != blocked_direction:
			blocked_direction = ""
		
	else :
		var has_intersect : Array = Mainglobal.check_intersection(self_id, new_pos_iso)
		if not has_intersect[2] in ["Player"] : blocked_direction = move_direction
		#move_direction = Mainglobal.set_best_move_direction(obj_scene, move_direction, blocked_direction, type)

	if inertia <= 0 : push_direction=""

	if prev_direction != move_direction :
		get_node("occluder-left").visible = false
		get_node("occluder-right").visible = false
		get_node("occluder-up").visible = false
		get_node("occluder-down").visible = false
		get_node("occluder-"+move_direction).visible = true

func load_data(uid_object) :
	obj = Mainglobal.characters_repository[uid_object]
	Mainglobal.load_data(uid_object,obj,sprite)

func _exit_tree() :
	$Walk.stop()
	Mainglobal.scene_objects.erase(self_id)

func push(obj_from,speed,source_weight,direction,above) :
	speed_push = speed
	if obj_from["type"]=="portable" and obj_from["subtype"] == "crystal" :
		Mainglobal.lightning(self, obj_from)
	inertia = Mainglobal.get_inertia(source_weight,weight,above)
	push_direction = direction
	
