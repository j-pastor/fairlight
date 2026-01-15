extends AnimatedSprite2D

var uid : String = ""
var type : String = ""
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
var blocked_direction = ""
var step_status = 0
var frame_counter = 0
var on_steps = false
var just_started = true
var player_last_damage = 0
var is_fading := false

var subtype : String = ""
var new_pos_iso : Vector3 = Vector3.ZERO
var new_pos_iso_advance_wolf : Vector3 = Vector3.ZERO
var speed_push = 0
var passive_move : Vector3 = Vector3.ZERO

var z_jump = 0

func _ready() :
	self_id = self.get_instance_id()
	just_started = true
	is_fading = false
	
	
func _physics_process(_delta: float) :
	
	var prev_direction = move_direction
	
	if is_fading : return
	
	if Mainglobal.time_stoped : 
		sprite.pause()
		return
	
	obj = Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]
	obj_scene = Mainglobal.scene_objects[self_id]
	Mainglobal.update_object_z_index(self_id)

	
	type = obj["type"]
	subtype = obj["subtype"]

	if obj["pos"].z < -20 :
		Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]["room"] = "none"	
		self.queue_free()

	if just_started :
		just_started = false
		move_direction = Mainglobal.set_best_move_direction(obj_scene,move_direction,blocked_direction,type)
		if type in ["ogre","wolf","skel","demon"] :
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
							object_to_push.push(obj,0.9,999,"upper",true)
						detected_intersect = true
			if detected_intersect :
				self.queue_free()
		

	if Mainglobal.setup_sound_fx and subtype in ["monk-walk","monk-static"] and not $Ghost.playing : $Ghost.play()

	if obj["life"] < 1 :
		if type in ["ogre","wolf","skel","demon"] : $Walk.stop()
		is_fading = true
		if Mainglobal.setup_sound_fx : $/root/Main/Sounds/Exhale.play()
		var tween := get_tree().create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.5)
		await tween.finished
		Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]["status"] = "dead"
		Mainglobal.scene_objects.erase(self_id)
		self.queue_free()
		return
	
	frame_counter += 1
	if frame_counter > 3 :
		frame_counter = 0
		return
	
	var prev_pos_iso = obj_scene["pos"]
	new_pos_iso = prev_pos_iso
	new_pos_iso_advance_wolf = prev_pos_iso
	var player_pos = Mainglobal.scene_objects[Mainglobal.player.self_id]["pos"]

	var d_x = abs(prev_pos_iso.x - player_pos.x )
	var d_y = abs(prev_pos_iso.y - player_pos.y )

	if (d_x <= 5 ) or  (d_y <= 5 )  or (prev_pos_iso.x < player_pos.x and move_direction == "down") or (prev_pos_iso.x > player_pos.x and move_direction == "up") or (prev_pos_iso.y < player_pos.y and move_direction == "left") or (prev_pos_iso.y > player_pos.y and move_direction == "right") or blocked_direction == move_direction:
		if (d_x>5 or d_y>5) :
			move_direction = Mainglobal.set_best_move_direction(obj_scene,move_direction,blocked_direction,type)
		blocked_direction = ""
		
	if not Mainglobal.time_stoped and (subtype=="monk-walk" or type in ["ogre","wolf","skel","demon"]) : 
		new_pos_iso += Mainglobal.get_vector_direction(move_direction) * 1
		new_pos_iso_advance_wolf += Mainglobal.get_vector_direction(move_direction) * 16
		
	

	if not Mainglobal.time_stoped :
		sprite.play("walk-"+move_direction)
		if type in ["ogre","wolf","skel","demon"] and Mainglobal.setup_sound_fx and not $Walk.playing : $Walk.play()
	elif type in ["ogre","wolf","skel","demon"] : $Walk.stop()
		
	if subtype in ["wizard"] :
		sprite.play("wizard")
	
	
	if not on_steps and step_status == 0 :
		Mainglobal.gravity(self_id)

	Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]["pos"]=Mainglobal.scene_objects[self_id]["pos"]
	
	
	if inertia<1 and not obj_scene["is_falling"] :

		var has_intersect : Array = Mainglobal.check_intersection(self_id, new_pos_iso)
		var can_move = Mainglobal.can_move_to_iso(self_id, new_pos_iso, false)

		if type == "wolf" and Mainglobal.r_name in ["z-chasm-3","z-chasm-2"]:
			var new_pos_screen_advance_wolf = Mainglobal.iso_to_screen(new_pos_iso_advance_wolf + Vector3(0,0,-1), Mainglobal.origin, Mainglobal.SCALE)
			var new_has_polygon_floor_advance_wolf = Mainglobal.in_floor_polygon(new_pos_iso_advance_wolf + Vector3(0,0,-1), new_pos_screen_advance_wolf)
			if not new_has_polygon_floor_advance_wolf : can_move = false

		if can_move :
			Mainglobal.scene_objects[self_id]["pos"] = new_pos_iso
			Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]["pos"] = new_pos_iso
			step_status = 0
			on_steps = false

		else :
			on_steps = false

			if has_intersect[3] in ["movable","portable"] :
				var object = get_node("/root/Main/Room/RoomElements/NonFixedObjects/"+has_intersect[2])
				if subtype in ["monk-walk","monk-static"] and (has_intersect[2] == "crux-throne" or has_intersect[2].begins_with("potion")) :
					is_fading = true
					if Mainglobal.setup_sound_fx : $/root/Main/Sounds/Monkshout.play()
					get_node("/root/Main/Room/RoomElements/NonFixedObjects/"+has_intersect[2]).queue_free()
					Mainglobal.non_fixed_objects_repository[has_intersect[2]]["room"] = "none"
					var tween := get_tree().create_tween()
					tween.tween_property(self, "modulate:a", 0.0, 1.0)
					await tween.finished

					self.queue_free()
					Mainglobal.characters_repository[Mainglobal.scene_objects[self.get_instance_id()]["name"]]["room"] = "none"
					if "disabled_door" in Mainglobal.characters_repository[Mainglobal.scene_objects[self.get_instance_id()]["name"]] :
						for s_object in Mainglobal.scene_objects :
							if Mainglobal.scene_objects[s_object]["name"] == Mainglobal.characters_repository[Mainglobal.scene_objects[self.get_instance_id()]["name"]]["disabled_door"] :
								Mainglobal.scene_objects[s_object]["status"] = "none"

				else:
					if subtype == "monk-walk" : object.push(obj,0.9,1,move_direction,false)
					if type in ["ogre","wolf","skel","demon"] : object.push(obj,0.9,6,move_direction,false)

			# DETECTA Y SUBE ESCALERAS
			if has_intersect[3].begins_with("step-") and push_direction == "":
				var step_result = await Mainglobal.climb_stairs(self_id, obj_scene, has_intersect, move_direction, step_status, false)
				on_steps = step_result["on_steps"]
				step_status = step_result["step_status"]
				z_jump = step_result["z_jump"]
			else:
				step_status = 0



			if has_intersect[2] in ["Player"]:
				var object = get_node("/root/Main/Characters/"+has_intersect[2])
				if not Mainglobal.player.sprite.animation.contains("attack") or not Mainglobal.player.sprite.frame in [2] or subtype in ["monk-walk","monk-static"]:
					object.push(obj,1,1,move_direction,false)
					if player_last_damage == 0 : player_last_damage = Time.get_ticks_msec()
					if Time.get_ticks_msec() - player_last_damage > 150 :
						Mainglobal.update_life_player(-1)
						player_last_damage = 0

			
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



	else :
		var has_intersect : Array = Mainglobal.check_intersection(self_id, new_pos_iso)
		if not has_intersect[2] in ["Player"] : blocked_direction = move_direction
		#move_direction = Mainglobal.set_best_move_direction(obj_scene,move_direction,blocked_direction,type)

	if inertia <= 0 : push_direction=""

	
	if prev_direction != move_direction :
		get_node("occluder-left").visible = false
		get_node("occluder-right").visible = false
		get_node("occluder-up").visible = false
		get_node("occluder-down").visible = false
		get_node("occluder-"+move_direction).visible = true


func _exit_tree() :
	if subtype in ["monk-walk","monk-static"] : $Ghost.stop()
	if type in ["ogre","wolf","skel","demon"] : $Walk.stop()
	Mainglobal.scene_objects.erase(self_id)
	

func load_data(uid_object) :
	obj = Mainglobal.characters_repository[uid_object]
	Mainglobal.load_data(uid_object,obj,sprite)


func push(obj_from,speed,source_weight,direction,above) :
	speed_push = speed
	if obj_from["type"]=="portable" and obj_from["subtype"] == "crystal" :
		Mainglobal.lightning(self, obj_from)

	else :
		if subtype in ["monk-walk","monk-static"] and obj_from["type"] == "portable" and obj_from["subtype"] in ["potion","crux"] :
			is_fading = true
			if Mainglobal.setup_sound_fx : $/root/Main/Sounds/Monkshout.play()
			get_node("/root/Main/Room/RoomElements/NonFixedObjects/"+obj_from["uid"]).queue_free()
			Mainglobal.non_fixed_objects_repository[obj_from["uid"]]["room"] = "none"
			var tween := get_tree().create_tween()
			tween.tween_property(self, "modulate:a", 0.0, 1.0)
			await tween.finished

			
			
			self.queue_free()
			Mainglobal.characters_repository[Mainglobal.scene_objects[self.get_instance_id()]["name"]]["room"] = "none"

			if "disabled_door" in Mainglobal.characters_repository[Mainglobal.scene_objects[self.get_instance_id()]["name"]] :
				for s_object in Mainglobal.scene_objects :
					if Mainglobal.scene_objects[s_object]["name"] == Mainglobal.characters_repository[Mainglobal.scene_objects[self.get_instance_id()]["name"]]["disabled_door"] :
						Mainglobal.scene_objects[s_object]["status"] = "none"			

		if type in ["ogre","wolf","skel","demon"] :
			inertia = Mainglobal.get_inertia(source_weight,weight,above)
			push_direction = direction
		
