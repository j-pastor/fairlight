# =========================================================================================
# PLAYER.GD
#
# PLAYER CHARACTER CONTROLLER FOR THE ISOMETRIC ENGINE.
#
# THIS SCRIPT MANAGES ALL RUNTIME BEHAVIOR OF THE PLAYER CHARACTER, INCLUDING:
# - MOVEMENT AND DIRECTION HANDLING IN ISOMETRIC SPACE
# - PHYSICS INTERACTIONS (GRAVITY, FALLING, JUMPING, STAIRS)
# - COMBAT AND DAMAGE PROCESSING
# - INTERACTION WITH OBJECTS, ENEMIES, AND ENVIRONMENT
# - INVENTORY USAGE, PICKUP, DROP, AND ITEM ACTIVATION
# - ROOM TRANSITIONS AND DEATH SEQUENCES
#
# THE PLAYER LOGIC IS TIGHTLY INTEGRATED WITH THE GLOBAL ENGINE STATE
# MANAGED BY MAINGLOBAL.GD.
#
# ENGINE: GODOT 4.4
# PROJECTION: CLASSIC 2:1 ISOMETRIC
# =========================================================================================
extends CharacterBody2D
var pos_iso : Vector3 = Vector3.ZERO
var pos_screen : Vector2 = Vector2.ZERO
var z_jump = 0
var jump_direction : String = ""
var move_direction : String = "down"
var sprite_direction : String = "down"
var previous_move_direction : String = "down"
var speed_character : int = 2
var sprite : AnimatedSprite2D = null
var current_tilelevel = 0
var frame_counter = 0
var is_burning = false
var is_death_falling = false
var is_drawing = false
var active_directions := []
var just_start_walking := false

var step_status = 0
var object_size : Vector3 = Vector3(5, 5, 32.0)
var obj = null
var cumulated_fall = 0
var total_fall = 0
var self_id = self.get_instance_id()
var time_no_look = 0
var time_looking = 0

var inertia := 0
var push_direction := ""
var weight := 6
var is_pushed = false
var is_changing = false

var frame_attack_checked = false
var frame_checked = false
var gravity = null
var on_steps = false
var player_last_damage = 0
var speed_push = 0
var pendant_move = null
var pendant_pos_iso = null

var is_blocked_below = false
var passive_move := Vector3.ZERO
var type_death_scene := 0

signal push_finished

# =========================================================================================
# NODE INITIALIZATION.
# RESETS RUNTIME STATE FLAGS RELATED TO BURNING, FALLING DEATH,
# AND SPECIAL ANIMATION MODES WHEN THE PLAYER ENTERS THE SCENE TREE.
# =========================================================================================
func _ready() : 
	is_burning = false
	is_death_falling = false
	is_drawing = false
	

# =========================================================================================
# MAIN PHYSICS UPDATE LOOP FOR THE PLAYER.
#
# THIS METHOD ACTS AS THE CENTRAL RUNTIME CONTROLLER AND EXECUTES EVERY PHYSICS FRAME.
# IT COORDINATES MOVEMENT, COLLISIONS, GRAVITY, COMBAT, ROOM TRANSITIONS, ANIMATIONS,
# SOUND EFFECTS, AND INTERACTION WITH THE GLOBAL ENGINE STATE.
#
# DUE TO THE COMPLEXITY OF THE ISOMETRIC ENGINE, THIS FUNCTION INTENTIONALLY CENTRALIZES
# GAMEPLAY LOGIC TO PRESERVE DETERMINISM AND AVOID DESYNCHRONIZATION BETWEEN SYSTEMS.
# =========================================================================================
func _physics_process(_delta: float) -> void :
	
	if not $Sound_Carpet.playing and Mainglobal.player_on_carpet: $Sound_Carpet.play()
	if $Sound_Carpet.playing and not Mainglobal.player_on_carpet: $Sound_Carpet.stop()

	if push_direction != "" and not obj["is_moving"] : move_direction = push_direction
	
	var next_room := ""
	var next_pos := Vector3.ZERO
	var cross_door := false
	var locked := false
	var not_allowed := false
	
	
	Mainglobal.cam.make_current()
	self_id = self.get_instance_id()
	obj = Mainglobal.scene_objects[self_id]
	var prev_pos_iso : Vector3 = obj["pos"]
	current_tilelevel = int(obj["pos"].z/20)+1
	sprite = self.get_node("Sprite")

	Mainglobal.update_object_z_index(self_id)

	frame_counter += 1
	if frame_counter > 5 :
		frame_counter = 0

	# =========================================================================================
	# ENVIRONMENTAL DEATH HANDLING.
	#
	# MANAGES SPECIAL DEATH BEHAVIORS WHEN FALLING BELOW THE WORLD,
	# TRIGGERING ENVIRONMENT-SPECIFIC ANIMATIONS, SOUNDS, AND EFFECTS.
	# =========================================================================================
	if obj["pos"].z < 0 :
		if Mainglobal.r_name.begins_with("x-tower") :
			if not sprite.animation == "burn" :
				Mainglobal.player_on_carpet = false
				Mainglobal.player_is_woman = false
				sprite.play("burn")
				if not $Screamfire.playing : $Screamfire.play()
				is_burning = true
			if sprite.frame <= 7 :
				obj["pos"].z += 1
			else :
				sprite.play("none")
				$Screamfire.stop()
				obj["pos"].z = -22

		if Mainglobal.begins_with_any(Mainglobal.r_name,["z-beach","z-ship-dock"]) :
			if not is_drawing :
				Mainglobal.player_on_carpet = false
				Mainglobal.player_is_woman = false
				sprite.play("chof-"+move_direction)
				obj["pos"] = obj["pos"] + 3 * Mainglobal.get_vector_direction(move_direction)
				if not $Splash.playing : $Splash.play()
				is_drawing = true
			if sprite.frame <= 11 :
				obj["pos"].z += 1
			else :
				sprite.play("none")
				$Screamfire.stop()
				obj["pos"].z = -22

	if obj["pos"].z < 0 :
		self.visible = false
		if Mainglobal.r_name.begins_with("z-") and not Mainglobal.r_name.begins_with("z-beach") and not Mainglobal.r_name == "z-ship-dock":
			type_death_scene = 2
			Mainglobal.load_room("death-sea",Vector3(10,10,180))
			if not $Screamfalling.playing : $Screamfalling.play()
			self.visible = true
			return
		elif Mainglobal.r_name.begins_with("z-beach") or Mainglobal.r_name == "z-ship-dock" :
			Mainglobal.life_player = 0
			type_death_scene = 2
			self.visible = false
		elif Mainglobal.r_name.begins_with("x-tower"):
			Mainglobal.life_player = 0
			type_death_scene = 3
		else :
			type_death_scene = 1
			Mainglobal.load_room("forest-entry-death",Vector3(10,10,180))
			if not $Screamfalling.playing : $Screamfalling.play()
			self.visible = true
			return

	if Mainglobal.r_name in ["forest-entry-death","death-sea"] and obj["pos"].z == 0:
		Mainglobal.life_player = 0
		if Mainglobal.r_name == "forest-entry-death"  and not sprite.animation in ["fall-left-up","fall-right-down"]:
			if move_direction in ["left","up"] : sprite.play("fall-left-up")
			if move_direction in ["right","down"] : sprite.play("fall-right-down")
	
		if Mainglobal.r_name == "death-sea"  and not sprite.animation.begins_with("chof-") : 
			is_drawing= true
			if not $Splash.playing : $Splash.play()
			sprite.play("chof-"+move_direction)

	if sprite.animation in ["fall-left-up","fall-right-down"] and sprite.frame == 8:
		sprite.stop()
		sprite.frame = 8

	if sprite.animation in ["chof"] and sprite.frame == 14:
		sprite.stop()
		sprite.frame = 15

	if obj["is_falling"] and not Mainglobal.player_on_carpet:
		cumulated_fall += 1
		#sprite.frame = 0
	
	if Mainglobal.life_player < 1 :
		$Sound_Walk.stop()
		Mainglobal.life_player = 0
		Mainglobal.update_life_player(0)
		#self.visible = false
		Mainglobal.scene_objects[self_id]["pos"] = Vector3(9999,9999,9999)
		var fade = get_node("/root/Main/FadeFull/FadeControl/FadeRect")
		var tween = create_tween()
		tween.tween_property(fade, "color:a", 1, 1)
		await get_tree().create_timer(3).timeout
		get_tree().paused = true
		await get_tree().create_timer(1.0, true).timeout
		get_tree().paused = false
		if Mainglobal.active_player == 1 : Mainglobal.music_a.stop()
		if Mainglobal.active_player == 2 : Mainglobal.music_b.stop()
		get_tree().change_scene_to_file("res://scenes/death_type_"+str(type_death_scene)+".tscn")
		return


	if (not obj["is_attacking"]) or (obj["is_attacking"] and sprite.frame == 2) :
		if Mainglobal.setup_sound_fx and obj["is_attacking"] and not $Sword.playing : $Sword.play()
		#if push_direction=="" :
			#obj["pos"] -= Vector3(0,0,step_status)

	var prev_is_falling = Mainglobal.scene_objects[self_id]["is_falling"]
	if step_status == 0  :
		gravity = Mainglobal.gravity(self_id)
		var has_intersect_step : Array = Mainglobal.check_intersection(self_id, obj["pos"]+Vector3(0,0,-5))
		
		if obj["is_falling"] : 
			#print(has_intersect_step)
			if (has_intersect_step[0] and not has_intersect_step[3].begins_with("step-")) or not has_intersect_step[0] and not obj["pos"].z < 6: sprite.stop()
		
	if Mainglobal.scene_objects[self_id]["is_falling"] and cumulated_fall > 5: 
		$Sound_Walk.stop()
	if prev_is_falling and not Mainglobal.scene_objects[self_id]["is_falling"] and not Mainglobal.player_on_carpet: 
		#if $Sound_Walk.playing : $Sound_Walk.stop()
		if Mainglobal.setup_sound_fx and cumulated_fall>5: $Sound_Hit_Floor.play()
		if cumulated_fall < 100 and cumulated_fall > 60 : Mainglobal.update_life_player(-10)
		if cumulated_fall < 180 and cumulated_fall >= 100 : Mainglobal.update_life_player(-30)
		cumulated_fall = 0
		


	var has_collision_wall : bool = false
	var has_push_collision : bool = false
	var new_pos_iso = obj["pos"]
	var new_pos_iso_center = new_pos_iso + Vector3(obj["size"].x/2,obj["size"].y/2,0)

	var has_overlap : Array = Mainglobal.check_intersection(self_id,new_pos_iso-Vector3(0,0,1))

	if Mainglobal.r_name == "warehouse":
		has_overlap = Mainglobal.check_intersection(self_id,new_pos_iso_center+Vector3(0,0,-1))

	
	
	var has_void : bool = Mainglobal.check_exists_void_from_iso(obj["pos"] + 5*Mainglobal.get_vector_direction(move_direction),Mainglobal.origin,Mainglobal.SCALE)

	# CHECK GATES
	if has_overlap[3] in ["gate","gate-down-loft"] :
		if "key" in Mainglobal.scene_objects[has_overlap[1]] :
			if Mainglobal.scene_objects[has_overlap[1]]["key"] != Mainglobal.set_inventory[Mainglobal.active_inv-1]:
				locked = true
				#Mainglobal.show_temporary_message("LOCKED", 0.5)
		if "notinv" in Mainglobal.scene_objects[has_overlap[1]] :
			if Mainglobal.scene_objects[has_overlap[1]]["notinv"] in Mainglobal.set_inventory :
				locked = true
		if not locked:
			next_room = has_overlap[4]
			next_pos = new_pos_iso + has_overlap[5]
			cross_door = true
			
			#var blocked_next = Mainglobal.check_blocked_next_room(next_room,next_pos + Mainglobal.get_vector_direction(move_direction))
			var blocked_next = Mainglobal.check_blocked_next_room(next_room,next_pos)

			if blocked_next[0]:
				cross_door = false
				next_room = ""
				next_pos = Vector3.ZERO


	# COLLISIONS
	if push_direction!="" or (obj["is_moving"] and not obj["is_falling"] and not obj["is_pickup"]) or (obj["is_moving"] and Mainglobal.player_on_carpet):

		if (not obj["is_attacking"]) or (obj["is_attacking"] and sprite.frame == 2): 
			new_pos_iso  += Mainglobal.get_vector_direction(move_direction)
			new_pos_iso_center = new_pos_iso + Mainglobal.get_vector_direction(move_direction)

		if push_direction != "" :
			has_push_collision = Mainglobal.check_exists_tile_from_iso(obj["pos"] + 3 * Mainglobal.get_vector_direction(push_direction),Mainglobal.origin,Mainglobal.SCALE,current_tilelevel,"wall")
		has_collision_wall = Mainglobal.check_exists_tile_from_iso(obj["pos"] + 2 * Mainglobal.get_vector_direction(move_direction),Mainglobal.origin,Mainglobal.SCALE,current_tilelevel,"wall")
		var has_intersect : Array = Mainglobal.check_intersection(self_id, new_pos_iso)
		var has_collision = false
		if has_push_collision or has_collision_wall : has_collision = true
		var reached_limit : bool = Mainglobal.check_reached_limit(new_pos_iso,obj["size"], has_collision,true)


		if not has_collision_wall and not reached_limit and not has_void and not has_push_collision:
			if not has_intersect[0] or (has_overlap[0] and has_overlap[3]=="gate" and cross_door): 
				obj["pos"] = round(new_pos_iso)
			if has_overlap[0] and has_overlap[3]=="gate" and not cross_door :
				Mainglobal.show_temporary_message("BLOCKED BELOW...", 0.5)
				#obj["pos"] = round(prev_pos_iso)




			if has_intersect[0]:
				if has_intersect[3] in ["movable","portable"] :
					var object = get_node("/root/Main/Room/RoomElements/NonFixedObjects/"+has_intersect[2])
					if sprite.frame != 0 : frame_checked = false
					if Mainglobal.non_fixed_objects_repository[has_intersect[2]]["subtype"] == "guard-helmet" :
						if sprite.frame == 0 and not frame_checked:
							frame_checked = true
							Mainglobal.update_life_player(-1)
					object.push(obj,1,6,move_direction,false)


				if has_intersect[3] in ["guard","ogre","wolf","twister","pirate","skel","demon"] :
					step_status = 0
					var object = get_node("/root/Main/Room/RoomElements/Characters/"+has_intersect[2])
					if obj["is_attacking"] and sprite.frame == 2 and randi_range(0,99)<85 and sprite.frame_progress > 0.85 and Mainglobal.characters_repository[has_intersect[2]]["status"] != "rebirth" and has_intersect[3] in ["guard","wolf","ogre","twister","pirate","skel","demon"]:
						Mainglobal.characters_repository[has_intersect[2]]["life"] -= 25
						if has_intersect[3] != "twister" :
							if Mainglobal.characters_repository[has_intersect[2]]["life"] > 0: 
								object.push(obj,1,6,move_direction,false)
							object.push(obj,1,12,Mainglobal.player.move_direction,false)
						# new_pos_iso = prev_pos_iso
					elif not obj["is_attacking"] :
						if player_last_damage == 0 : player_last_damage = Time.get_ticks_msec()
						if Time.get_ticks_msec() - player_last_damage > 250 :
							Mainglobal.update_life_player(-1)
							player_last_damage = 0
						if has_intersect[3] in ["guard"] : 
							object.push(obj,1,2,move_direction,false)
						if has_intersect[3] in ["pirate"] : 
							object.push(obj,1,2,move_direction,false)
						if has_intersect[3] in ["ogre","skel","demon"] : 
							object.push(obj,1,1,move_direction,false)
						if has_intersect[3] in ["wolf"] : 
							object.push(obj,1,1,move_direction,false)


				if has_intersect[3] in ["monk"] or Mainglobal.begins_with_any(has_intersect[2],["fire","torch","venon"]) :
					if player_last_damage == 0 : player_last_damage = Time.get_ticks_msec()
					if Time.get_ticks_msec() - player_last_damage > 150 :
						#var object = get_node("/root/Main/Room/RoomElements/Characters/"+has_intersect[2])
						if has_intersect[2]!="monk-wizard" :
							Mainglobal.update_life_player(-1)
							player_last_damage = 0

				if has_intersect[3] in ["bubble","blob"] :
					self.push(obj,1,1,"upper",true)
					if has_intersect[3] in ["bubble"] :
						Mainglobal.update_life_player(-10)
						
					else :
						if player_last_damage == 0 : player_last_damage = Time.get_ticks_msec()
						if Time.get_ticks_msec() - player_last_damage > 150 :
							Mainglobal.update_life_player(-1)
							player_last_damage = 0
							
					Mainglobal.show_temporary_message(str(Mainglobal.life_player),0.1)
					if has_intersect[3] in ["bubble"] : 
						Mainglobal.characters_repository[Mainglobal.scene_objects[has_intersect[1]]["name"]]["life"] -= 99


				# DETECT STAIRS AND UP
				if has_intersect[3].begins_with("step-") and push_direction == "" and not obj["is_jumping"]:
					var step_result = await Mainglobal.climb_stairs(self_id, obj, has_intersect, move_direction, step_status, true)
					on_steps = step_result["on_steps"]
					step_status = step_result["step_status"]
					z_jump = step_result["z_jump"]
				else:
					step_status = 0


				# DETECT DOORS
				if has_intersect[3] == "door":
					if Mainglobal.scene_objects[has_intersect[1]]["status"] == "disabled" or obj["pos"].z+3 < Mainglobal.scene_objects[has_intersect[1]]["pos"].z or obj["pos"].z + obj["size"].z > Mainglobal.scene_objects[has_intersect[1]]["pos"].z + Mainglobal.scene_objects[has_intersect[1]]["size"].z:
						not_allowed = true

					if "target_direction" in Mainglobal.scene_objects[has_intersect[1]] : 
						if Mainglobal.scene_objects[has_intersect[1]]["target_direction"] != move_direction :
							not_allowed = true
							
							
						if "has_frame" in Mainglobal.scene_objects[has_intersect[1]] :
							if obj["pos"].z > Mainglobal.scene_objects[has_intersect[1]]["pos"].z + 4 : not_allowed = true 
							if Mainglobal.scene_objects[has_intersect[1]]["target_direction"] in ["left","right"] :
								if obj["pos"].x < Mainglobal.scene_objects[has_intersect[1]]["pos"].x + 2 : not_allowed = true 
								if obj["pos"].x > Mainglobal.scene_objects[has_intersect[1]]["pos"].x + Mainglobal.scene_objects[has_intersect[1]]["size"].x - 5 : not_allowed = true 
							if Mainglobal.scene_objects[has_intersect[1]]["target_direction"] in ["up","down"] :
								if obj["pos"].y < Mainglobal.scene_objects[has_intersect[1]]["pos"].y + 1 : not_allowed = true 
								if obj["pos"].y > Mainglobal.scene_objects[has_intersect[1]]["pos"].y + Mainglobal.scene_objects[has_intersect[1]]["size"].y - 7 : not_allowed = true 
					else :
						not_allowed = false


					if "key" in Mainglobal.scene_objects[has_intersect[1]] and not not_allowed:
						if Mainglobal.scene_objects[has_intersect[1]]["key"] != Mainglobal.set_inventory[Mainglobal.active_inv-1] :
							locked = true
							Mainglobal.show_temporary_message("LOCKED", 0.5)
					if Mainglobal.active_dev_mode : locked = false # for development only
					if not locked and not not_allowed :
						next_room = has_intersect[4]
						next_pos = has_intersect[5]
						
						if not Mainglobal.scene_objects[has_intersect[1]]["exact"] : 
							var offset_x = obj["pos"].x - Mainglobal.scene_objects[has_intersect[1]]["pos"].x
							var offset_y = obj["pos"].y - Mainglobal.scene_objects[has_intersect[1]]["pos"].y

							if Mainglobal.scene_objects[has_intersect[1]]["target_direction"]=="left" : offset_y = offset_y + 9
							if Mainglobal.scene_objects[has_intersect[1]]["target_direction"]=="right" : offset_y = offset_y - 9
							if Mainglobal.scene_objects[has_intersect[1]]["target_direction"]=="up" : offset_x = offset_x - 9
							if Mainglobal.scene_objects[has_intersect[1]]["target_direction"]=="down" : offset_x = offset_x + 9

							next_pos +=  Vector3(offset_x, offset_y, 0)

						cross_door = true

			else:
				step_status = 0
		else:
			if has_push_collision : inertia = 0


		if obj["is_attacking"]:
			sprite.play("attack-"+sprite_direction)
		elif obj["is_pickup"]:
			sprite.play("pick-"+sprite_direction)
		#else:
			#sprite.play("walk-"+sprite_direction)
			#if sprite.frame == 0 : sprite.frame = 1
	else :
		if not obj["is_pickup"] : 
			if time_looking == 0 and not Mainglobal.player_is_woman and not Mainglobal.player_on_carpet and not is_burning and not Mainglobal.life_player < 1 : sprite.play("walk-"+sprite_direction)
			if time_looking == 0 and Mainglobal.player_is_woman and not is_burning: sprite.play("woman-"+sprite_direction)
			if time_looking == 0 and Mainglobal.player_on_carpet and not is_burning: sprite.play("carpet-"+sprite_direction)
		else :
			sprite.play("pick-"+sprite_direction)
		if (not obj["is_moving"] and not obj["is_pickup"] and not obj["is_jumping"] and not is_burning and not is_death_falling and not is_drawing):
			sprite.stop()


	# CHECK IF PLAYER IS JUMPING
	if obj["is_jumping"] and step_status==0:
		if $Sound_Walk.playing : $Sound_Walk.stop()
		if jump_direction != ""  :
			sprite_direction = jump_direction
			move_direction = jump_direction
		new_pos_iso = Vector3.ZERO
		new_pos_iso = obj["pos"] + Vector3(0,0,1)
		var has_intersect : Array = Mainglobal.check_intersection(self_id, new_pos_iso)
		if not has_intersect[0]:
			obj["pos"] = round(new_pos_iso)
		elif has_intersect[3] == "gate-loft" :
			if "key" in Mainglobal.scene_objects[has_intersect[1]] :
				if Mainglobal.scene_objects[has_intersect[1]]["key"] != Mainglobal.set_inventory[Mainglobal.active_inv-1] :
					locked = true
					Mainglobal.show_temporary_message("LOCKED", 0.5)
			if Mainglobal.active_dev_mode : locked = false # for development only
			if not locked :
				next_room = has_intersect[4]
				next_pos = obj["pos"] + Vector3(15,20,0)
				next_pos.z = 1
				z_jump = 1
				cross_door = true
		elif has_intersect[3] in ["fixed","slab"] or has_intersect[3].begins_with("step"):
			obj["is_jumping"] = false
			obj["is_falling"] = true
		elif has_intersect[3] in ["portable","movable"]:
			for object_over in Mainglobal.scene_objects :
				var has_intersect_over : Array = Mainglobal.check_over_intersection(self_id, new_pos_iso, object_over)
				if has_intersect_over[0] and has_intersect_over[3] in ["movable","portable"] :
					if obj["is_moving"] : 
						Mainglobal.scene_objects[has_intersect_over[1]]["node"].push(object_over,1,1,move_direction+"upper",true)
					else: 
						Mainglobal.scene_objects[has_intersect_over[1]]["node"].push(object_over,1,1,"upper",true)
					
					await Mainglobal.scene_objects[has_intersect_over[1]]["node"].push_finished
				
					has_intersect_over = Mainglobal.check_over_intersection(self_id, new_pos_iso, object_over)
					if not has_intersect_over[0] :
						obj["pos"] = round(new_pos_iso)
						obj["is_jumping"] = true

		if obj["is_jumping"] :
			z_jump += 1
			if z_jump >= 18 :
				z_jump = 0
				obj["is_jumping"] = false
				obj["is_falling"] = true
				jump_direction = ""
				obj["is_moving"] = false
	
	if inertia>0 :
		inertia = await Mainglobal.push_object(self,speed_push,obj,inertia,push_direction,"characters")

	emit_signal("push_finished")


	# PASSIVE MOVEMENT
	if passive_move != Vector3.ZERO :
		obj["pos"] += passive_move
		passive_move = Vector3.ZERO

	# UPDATE PLAYER POSITION
	if obj["pos"]!=prev_pos_iso or cross_door and not locked and not not_allowed: 
		#print(obj["pos"])
		time_no_look = 0
		time_looking = 0

		var variation = obj["pos"] - prev_pos_iso
		Mainglobal.check_over_movement(self_id, variation)

		var pos_iso_center := Vector3.ZERO
		pos_iso_center = Mainglobal.iso_object_center(obj["pos"],object_size)
		pos_screen = Mainglobal.iso_to_screen(pos_iso_center, Mainglobal.origin, Mainglobal.SCALE)
		
		global_position = pos_screen
		#print("")
		#print("------------>",obj["pos"]," ",step_status," ",push_direction)
		var pos = obj["pos"]
		
		if pos.x < 1 and Mainglobal.connection_north!="none" and not has_collision_wall and not has_void: 
			next_room = Mainglobal.connection_north
			next_pos = Vector3(Mainglobal.get_size_room(next_room).x-object_size.x,pos.y,pos.z)+Mainglobal.offset_north
		elif pos.x > Mainglobal.room_size.x-1 and Mainglobal.connection_south!="none" and not has_collision_wall and not has_void: 
			next_room = Mainglobal.connection_south
			next_pos = Vector3(1,pos.y,pos.z)+Mainglobal.offset_south
		elif pos.y < 1 and Mainglobal.connection_east!="none" and not has_collision_wall and not has_void:
			next_room = Mainglobal.connection_east
			next_pos = Vector3(pos.x,Mainglobal.get_size_room(next_room).y-object_size.y,pos.z)+Mainglobal.offset_east
		elif pos.y > Mainglobal.room_size.y-object_size.y and Mainglobal.connection_west!="none" and not has_collision_wall and not has_void:
			next_room = Mainglobal.connection_west
			next_pos = Vector3(pos.x,1,pos.z)+Mainglobal.offset_west

		if next_room!="" :
			if move_direction == "down" : next_pos = Vector3(ceil(next_pos.x), round(next_pos.y), next_pos.z)
			if move_direction == "left" : next_pos = Vector3(round(next_pos.x), ceil(next_pos.y), next_pos.z)
			if move_direction == "up" : next_pos = Vector3(floor(next_pos.x), round(next_pos.y), next_pos.z)
			if move_direction == "right" : next_pos = Vector3(round(next_pos.x), floor(next_pos.y), next_pos.z)

			var blocked = Mainglobal.check_blocked_next_room(next_room,next_pos+Mainglobal.get_vector_direction(move_direction))
			#if blocked[0] and blocked[2] in ["movable","portable"]:
				#Mainglobal.non_fixed_objects_repository[blocked[1]]["pos"]+=Mainglobal.get_vector_direction(move_direction) * 3
			#if blocked[0] and blocked[2] in ["monk"] :
				#Mainglobal.characters_repository[blocked[1]]["pos"]+=Mainglobal.get_vector_direction(move_direction) * 3
				#blocked = Mainglobal.check_blocked_next_room(next_room,next_pos+Mainglobal.get_vector_direction(move_direction))
			
			if not blocked[0] or blocked[2] in ["twister","ogre","wolf","pirate","skel","demon","bubble","blob"]:
				if blocked[2] in ["twister","ogre","wolf","pirate","skel","demon","bubble","blob"] : Mainglobal.characters_repository[blocked[1]]["room"] = "none"
				Mainglobal.load_room(next_room, next_pos)
				if blocked[2] in ["twister","ogre","wolf","pirate","skel","demon","bubble","blob"] : Mainglobal.characters_repository[blocked[1]]["room"] = next_room
				Mainglobal.update_object_z_index(self_id)

				push_direction=""
			else:
				#print(has_overlap)
				if has_overlap[0] and 5 in has_overlap and has_overlap[5].z > 0 : 
					Mainglobal.show_temporary_message("BLOCKED BELOW...", 0.5)
					cross_door = false
				else :
					obj["pos"] = round(prev_pos_iso)
					move_direction = ""
					Mainglobal.show_temporary_message("BLOCKED...", 0.5)
					obj["is_jumping"] = false
					obj["is_falling"] = true
				pos_iso_center = Mainglobal.iso_object_center(obj["pos"],object_size)
				pos_screen = Mainglobal.iso_to_screen(pos_iso_center, Mainglobal.origin, Mainglobal.SCALE)
				global_position = pos_screen
				
	else :
		if time_looking == 0 :
			time_no_look += 1
		else :
			time_looking += 1
			if time_looking > 50 :
				time_looking = 0
		if time_no_look > 500 and not Mainglobal.player_is_woman and not Mainglobal.player_on_carpet:
			time_no_look = 0
			time_looking = 1
			sprite.play("look-"+sprite_direction)

	if Mainglobal.r_name not in ["forest-entry-death","death-sea"] and not is_changing:
		control_character()

	if is_changing :
		sprite.stop()
		$Sound_Walk.stop()
		obj["is_moving"] = false

	
	if inertia <= 0 : push_direction=""
	
	for o in Mainglobal.scene_objects:
		if Mainglobal.scene_objects[o]["type"] in ["movable","portable","guard","ogre","wolf","twister","pirate","skel","demon","monk","bubble","blob","bat","slab"] :
			Mainglobal.update_object_z_index(o)
			# instance_from_id(o).z_index = Mainglobal.scene_objects[o]["depth"]

	if is_drawing : self.z_index = 0




# PLAYER CONTROLS
func control_character() :
	# ATTACK
	if Input.is_action_pressed("ui_attack") and not obj["is_jumping"] and not obj["is_falling"] and not Mainglobal.player_is_woman and not Mainglobal.player_on_carpet:
		frame_attack_checked = false
		obj["is_attacking"] = true
		obj["is_moving"] = true
		move_direction = sprite_direction
	else :
		obj["is_attacking"] = false
	
	# DIRECTION
	if (not Input.is_action_pressed("ui_pickup") and not obj["is_falling"] and not obj["is_jumping"]) \
	or (obj["is_falling"] and Mainglobal.player_on_carpet):

		var pressed_direction := false

		if active_directions.size() > 0:
			var action = active_directions[active_directions.size() - 1]

			if Input.is_action_pressed("ui_" + action):
				if Mainglobal.setup_sound_fx and not $Sound_Walk.playing and not Mainglobal.player_on_carpet:
					$Sound_Walk.play()

				move_direction = action
				sprite_direction = action
				obj["is_moving"] = true
				pressed_direction = true

				if not obj["is_attacking"] and not Mainglobal.player_is_woman and not is_burning and not is_death_falling:
					if not sprite.is_playing() :
						just_start_walking = true
					sprite.play("walk-" + sprite_direction)
					if just_start_walking : 
						sprite.frame = [1, 3].pick_random()
						just_start_walking = false

				if not obj["is_attacking"] and Mainglobal.player_is_woman and not is_burning:
					sprite.play("woman-" + sprite_direction)

				if not obj["is_attacking"] and Mainglobal.player_on_carpet and not is_burning:
					sprite.play("carpet-" + sprite_direction)

		if not pressed_direction:
			if not obj["is_attacking"] and not is_death_falling and not is_drawing:
				sprite.pause()
				step_status = 0

			if not obj["is_jumping"] and not obj["is_attacking"] and not is_death_falling and not is_drawing:
				obj["is_moving"] = false
				sprite.pause()
				$Sound_Walk.stop()


	# CARPET UP
	if Input.is_action_pressed("ui_jump") and Mainglobal.player_on_carpet :
		var has_intersect : Array = Mainglobal.check_intersection(self_id, obj["pos"] + Vector3(0,0,2))
		if not has_intersect[0] :
			obj["pos"] += Vector3(0,0,2)


	# ACTIVE CARPET (ONLY FOR TESTS)
	if Input.is_action_just_pressed("ui_enable_carpet") and Mainglobal.active_dev_mode:
		if Mainglobal.player_on_carpet :
			Mainglobal.player_on_carpet = false
			#object_size = Vector3(5, 5, 32.0)
			# obj["pos"] += Vector3(5,5,0)
		else :
			Mainglobal.player_on_carpet = true
			$Sound_Walk.stop()
			#object_size = Vector3(16, 16, 32.0)
			#obj["pos"] -= Vector3(5,5,0)
		

	# JUMP
	if not Mainglobal.player_on_carpet and Input.is_action_pressed("ui_jump") and not obj["is_jumping"] and not obj["is_falling"] and step_status == 0:
		obj["is_jumping"] = true
		jump_direction = sprite_direction
		z_jump = 0
		step_status = 0
		
		sprite.pause()
		if sprite.frame == 0 : sprite.frame = 1
		elif sprite.frame == 1 : sprite.frame = 3
		elif sprite.frame == 2 : sprite.frame = 3
		elif sprite.frame == 3 : sprite.frame = 1

	# SELECT INVENTORY SLOT
	for i in range(1,6) :
		if Input.is_action_pressed("ui_inv"+str(i)) :
			Mainglobal.active_inv = i
			Mainglobal.set_active_inv()

	# PICK-UP OBJECT
	if Input.is_action_pressed("ui_pickup") and not Input.is_action_pressed("ui_drop")  and not Mainglobal.player_is_woman and not Mainglobal.player_on_carpet :
		if Mainglobal.set_inventory[Mainglobal.active_inv-1] == "" :
			sprite.play("pick-"+sprite_direction)
			obj["is_pickup"] = true
			$Sound_Walk.stop()
			self_id = self.get_instance_id()
			var has_intersect : Array = Mainglobal.check_for_pick_portable_object(self_id, obj["pos"] + Mainglobal.get_vector_direction(sprite_direction)*5)
			if has_intersect[3] in ["portable"] and not Mainglobal.scene_objects[has_intersect[1]]["is_falling"]:
				var total_weight = 0
				for i in Mainglobal.set_inventory :
					if i!="" :
						total_weight += Mainglobal.non_fixed_objects_repository[i]["weight"]
				var picked_object = Mainglobal.non_fixed_objects_repository[has_intersect[2]]
				if total_weight + picked_object["weight"] <= 16 or Mainglobal.active_dev_mode:
					$Pickup.play()
					Mainglobal.set_inventory[Mainglobal.active_inv-1] = has_intersect[2]
					Mainglobal.set_inventory_sprite(Mainglobal.active_inv,picked_object)
					Mainglobal.non_fixed_objects_repository[has_intersect[2]]["room"] = "none"
					if get_node("/root/Main/Room/RoomElements/NonFixedObjects/"+has_intersect[2]) :
						get_node("/root/Main/Room/RoomElements/NonFixedObjects/"+has_intersect[2]).call_deferred("queue_free")

				else :
					Mainglobal.show_temporary_message("TOO HEAVY", 0.5)
			#obj["is_pickup"] = false
					
	else :
		obj["is_pickup"] = false


	# USE OBJECT
	if Input.is_action_just_pressed("ui_use") :
		var inv_sprite = get_node("/root/Main/UI/InventoryLayer/sprite_inv"+str(Mainglobal.active_inv))
		var object_to_use = Mainglobal.set_inventory[Mainglobal.active_inv-1]

		if Mainglobal.set_inventory[Mainglobal.active_inv-1] == "dagger" and Mainglobal.r_name == "z-ship-1" :
			Mainglobal.characters_repository["Player"]["room"]="teleport"
			move_direction="down"
			Mainglobal.load_room("final-chapter-2", Vector3(113,138,0))

		if Mainglobal.set_inventory[Mainglobal.active_inv-1] == "scroll1" :
			Mainglobal.characters_repository["Player"]["room"]="teleport"
			move_direction="left"
			Mainglobal.set_inventory[Mainglobal.active_inv-1] = "" 
			inv_sprite.texture = null
			Mainglobal.load_room("yard-big", Vector3(113,138,0))
			
		if Mainglobal.begins_with_any(object_to_use,["bread","chicken","jug"]) : 
			Mainglobal.update_life_player(10)
			Mainglobal.set_inventory[Mainglobal.active_inv-1] = "" 
			inv_sprite.texture = null

		if Mainglobal.begins_with_any(object_to_use,["carpet"]) :
			if Mainglobal.player_on_carpet :
				Mainglobal.player_on_carpet = false
			else :
				Mainglobal.player_on_carpet = true
				$Sound_Walk.stop()

		if Mainglobal.begins_with_any(object_to_use,["potion"]) :
			Mainglobal.update_life_player(99)
			Mainglobal.set_inventory[Mainglobal.active_inv-1] = "" 
			inv_sprite.texture = null

		if Mainglobal.begins_with_any(object_to_use,["hourg"]) :
			Mainglobal.time_stoped = true
			Mainglobal.set_inventory[Mainglobal.active_inv-1] = "" 
			inv_sprite.texture = null
		
		if Mainglobal.begins_with_any(object_to_use,["crystal"]) : 
			var status = Mainglobal.non_fixed_objects_repository[Mainglobal.set_inventory[Mainglobal.active_inv-1]]["status"]
			if status == "none" : 
				Mainglobal.non_fixed_objects_repository[Mainglobal.set_inventory[Mainglobal.active_inv-1]]["status"] = "active"
				inv_sprite.texture = load("res://assets/objects/crystal-003.png")
			if status == "active" : 
				Mainglobal.non_fixed_objects_repository[Mainglobal.set_inventory[Mainglobal.active_inv-1]]["status"] = "none"
				inv_sprite.texture = load("res://assets/objects/crystal-001.png")
		
		if Mainglobal.begins_with_any(object_to_use,["amulet"]) :
			is_changing = true
			if Mainglobal.player_is_woman : 
				var tween := self.create_tween()
				if Mainglobal.setup_sound_fx : $Amulet.play()
				tween.tween_property(self, "modulate", Color(1,1,1,0), 0.5)
				await tween.finished
				sprite.play("walk-"+sprite_direction)
				Mainglobal.player_is_woman = false
				sprite.stop()
				var tween2 := self.create_tween()
				tween2.tween_property(self, "modulate", Color(1,1,1,1), 0.5)
				is_changing = false
			else :	
				var tween := self.create_tween()
				if Mainglobal.setup_sound_fx : $Amulet.play()
				tween.tween_property(self, "modulate", Color(1,1,1,0), 0.5)
				await tween.finished
				sprite.play("woman-" + sprite_direction)
				Mainglobal.player_is_woman = true
				sprite.stop()
				var tween2 := self.create_tween()
				tween2.tween_property(self, "modulate", Color(1,1,1,1), 0.5)
				is_changing = false


				


	# DROP OBJECT
	if Input.is_action_pressed("ui_drop") and not Input.is_action_pressed("ui_pickup") and not Mainglobal.player_is_woman and not Mainglobal.player_on_carpet :
		
		if Mainglobal.set_inventory[Mainglobal.active_inv-1] != "" :

			var x_drop = 0.0
			var y_drop = 0.0
			var z_drop = obj["pos"].z + obj["size"].z/2
			var object_drop = Mainglobal.non_fixed_objects_repository[Mainglobal.set_inventory[Mainglobal.active_inv-1]]
			var status = object_drop["status"]
			if status == "active" : z_drop = obj["pos"].z + 20
			
			if sprite_direction in ["down"] :
				x_drop = obj["pos"].x + (obj["size"].x)
				y_drop = obj["pos"].y - (object_drop["size"].y)/2

			if sprite_direction in ["up"] :
				x_drop = obj["pos"].x - object_drop["size"].x
				y_drop = obj["pos"].y - object_drop["size"].y/2

			if sprite_direction in ["right"]:
				y_drop = obj["pos"].y - object_drop["size"].y
				x_drop = obj["pos"].x - (object_drop["size"].x)/2

			if sprite_direction in ["left"] :
				y_drop = obj["pos"].y + obj["size"].y
				x_drop = obj["pos"].x - (object_drop["size"].x)/2

			var has_intersection = Mainglobal.check_drop_intersection(Vector3(x_drop,y_drop,z_drop),object_drop["size"])
			var has_overlap_gate = Mainglobal.check_drop_gate(Vector3(x_drop,y_drop,-1),object_drop["size"])

			if not has_intersection and not has_overlap_gate and x_drop>0 and y_drop>=0 and x_drop+object_drop["size"].x - 2 <= Mainglobal.room_size.x and y_drop+object_drop["size"].y <= Mainglobal.room_size.y:
				$Drop.play()
				object_drop["pos"]=Vector3(x_drop,y_drop,z_drop)
				object_drop["room"] = Mainglobal.r_name
				var inv_sprite = get_node("/root/Main/UI/InventoryLayer/sprite_inv"+str(Mainglobal.active_inv))
				inv_sprite.texture = null
				var dropped_object = Mainglobal.set_inventory[Mainglobal.active_inv-1]
				Mainglobal.set_inventory[Mainglobal.active_inv-1] = "" 
				Mainglobal.instantiate_room_object(object_drop["uid"])
			
				if dropped_object == "book-light" and Mainglobal.r_name == "big-tower-loft" :
					for o in Mainglobal.scene_objects :
						if Mainglobal.scene_objects[o]["name"] == "monk-wizard" :
							Mainglobal.characters_repository["monk-wizard"]["subtype"]="monk-walk"
							Mainglobal.scene_objects[o]["subtype"]="monk-walk"
							Mainglobal.liberated_wizard = true
				
			else :
				Mainglobal.show_temporary_message("BLOCKED", 0.5)
				


	if Input.is_action_pressed("ui_exit") :
		get_tree().change_scene_to_file("res://scenes/instructions.tscn")

	if Input.is_action_pressed("ui_save") :
		Mainglobal.show_temporary_message("SAVING...", 0.5)
		var file = FileAccess.open("fairlight-savegame-"+str(Mainglobal.slot_game_active)+".dat", FileAccess.WRITE)
		var save_data = {
			"life_player": Mainglobal.life_player,
			"r_room" : Mainglobal.r_name,
			"pos" : Mainglobal.scene_objects[self_id]["pos"],
			"liberated_wizard" : Mainglobal.liberated_wizard,
			"set_inventory": Mainglobal.set_inventory,
			"visited_rooms" : Mainglobal.visited_rooms,
			"non_fixed_objects_repository" : Mainglobal.non_fixed_objects_repository,
			"characters_repository" : Mainglobal.characters_repository,
			"time_stoped" : Mainglobal.time_stoped,
			"active_inv" : Mainglobal.active_inv,
			"player_is_woman" : Mainglobal.player_is_woman,
			"player_on_carpet" : Mainglobal.player_on_carpet
		}
		file.store_var(save_data)
		#file.store_string(JSON.stringify(save_data))
		file.close()
		Mainglobal.show_temporary_message("SAVED...", 0.5)

	if Input.is_action_just_pressed("ui_enable_dev") :
		if Mainglobal.active_dev_mode :
			Mainglobal.active_dev_mode = false
			Mainglobal.show_temporary_message("DEV OFF...", 0.5)
		else :
			Mainglobal.active_dev_mode = true
			Mainglobal.show_temporary_message("DEV ON...", 0.5)
			

func _input(event):
	if event is InputEventKey:
		for dir in ["down", "up", "left", "right"]:
			if event.is_action_pressed("ui_" + dir) and not event.echo:
				if dir in active_directions:
					active_directions.erase(dir)
				active_directions.append(dir)

			elif event.is_action_released("ui_" + dir):
				active_directions.erase(dir)


func push(_obj_from,speed,source_weight,direction,above) :
	speed_push = speed
	inertia = Mainglobal.get_inertia(source_weight,weight,above)
	push_direction = direction
