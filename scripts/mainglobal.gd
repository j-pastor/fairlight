# =====================================================
# MAINGLOBAL.GD
# =====================================================
# CORE SCRIPT OF THE ISOMETRIC GAME ENGINE.
#
# THIS NODE ACTS AS THE GLOBAL LOGICAL CORE OF THE GAME AND CONCENTRATES
# MOST OF THE ENGINE-LEVEL FUNCTIONALITY. IT MANAGES THE OVERALL GAME
# STATE, ROOM LOADING AND TRANSITIONS, AND MAINTAINS THE GLOBAL
# REPOSITORIES FOR OBJECTS, CHARACTERS, AND PERSISTENT STATES.
#
# MAIN RESPONSIBILITIES:
# - ROOM MANAGEMENT (LOADING, UNLOADING, CONNECTIONS, AND TRANSITIONS)
# - REGISTRATION AND PERSISTENCE OF FIXED OBJECTS, MOVABLE OBJECTS, AND CHARACTERS
# - CONVERSION BETWEEN ISOMETRIC COORDINATES (X, Y, Z) AND SCREEN SPACE (2D)
# - VOLUMETRIC 3D COLLISION SYSTEM IN ISOMETRIC SPACE
# - VISUAL ORDERING AND DEPTH CONTROL (Z_INDEX MANAGEMENT)
# - ADVANCED MOVEMENT SYSTEMS: PUSHING, INERTIA, GRAVITY, AND STAIRS
# - PLAYER STATE MANAGEMENT AND INVENTORY HANDLING
# - AREA-BASED MUSIC AND AMBIENT SOUND CONTROL
# - GAMEPLAY-RELATED SPECIAL EFFECTS (LIGHTNING, DAMAGE, ETC.)
#
# DESIGN DECISIONS:
# - LOGIC IS DELIBERATELY CENTRALIZED TO SIMPLIFY GLOBAL STATE CONTROL
#   AND PERSISTENCE ACROSS ROOM TRANSITIONS.
# - VISUAL NODES ARE RECREATED DYNAMICALLY FROM LOGICAL REPOSITORIES
#   TO AVOID INCONSISTENCIES WHEN CHANGING SCENES.
# - THE ISOMETRIC SYSTEM IS FULLY INDEPENDENT FROM SPRITE RENDERING.
#
# THIS SCRIPT DOES NOT HANDLE:
# - CHARACTER-SPECIFIC ANIMATIONS
# - DIRECT SPRITE RENDERING OR COMPLEX UI LOGIC
# - HIGH-LEVEL NARRATIVE LOGIC (DIALOGUES, CUTSCENES)
#
# ENGINE: GODOT 4.5
# PROJECTION: CLASSIC 2:1 ISOMETRIC
# AUTHOR : JUAN-ANTONIO PASTOR-SANCHEZ (PASTOR@UM.ES)
# =====================================================

extends Node

var current_chapter = 1
var cam : Camera2D = null
var r_name : String = ""
var p_r_name : String = ""
var current_room : Node = null
var SCALE : Vector2 = Vector2(3,3)
var LEVEL_HEIGHT_DIFFERENCE : float = 0.0
var player : Node = null
var origin : Vector2 = Vector2.ZERO
var tile_rr : Vector2i = Vector2.ZERO
var scene_objects := {}
var non_fixed_objects_repository := {}
var characters_repository := {}
var active_inv := 1
var set_inventory := ["","","","",""]
var visited_rooms := []
var action_from_instructions = ""
var global_tmp_depth = 0
var sea_direction = Vector2(-0.2, 0.2)

var room_size : Vector2 = Vector2.ZERO
var connection_north := ""
var connection_south := ""
var connection_west := ""
var connection_east := ""
var offset_north = null
var offset_south = null
var offset_west = null
var offset_east = null

var PLAYER_SCENE_PATH := "res://scenes/characters/player.tscn"

var life_enemies = 99
var life_player := 99
var player_last_damage_below := 0

var time_stoped = false
var liberated_wizard = false

var setup_sound_fx = true
var setup_sound_music = true
var player_is_woman = false
var player_on_carpet = false

var instantiating_object = false


var music_a = null
var music_b = null

var active_player := 1
var current_stream: AudioStream = null
var slot_game_active = 0

# ===================================
# ROOM PATTERNS FOR MUSIC SOUNDTRACKS
# ===================================
var area_music := {
	"yard": preload("res://assets/music/fantasy-medieval-mystery-ambient-292418.mp3"),
	"castle": preload("res://assets/music/castle-medieval-ambient-236809.mp3"),
	"second": preload("res://assets/music/castle-medieval-ambient-236809.mp3"),
	"well": preload("res://assets/music/the-haunted-queen-363199.mp3"),
	"warehouse": preload("res://assets/music/castle-medieval-ambient-236809.mp3"),
	"forest": preload("res://assets/music/midnight-forest-184304.mp3"),
	"cell" : preload("res://assets/music/dance-in-the-crypt-386961.mp3"),
	"basement" : preload("res://assets/music/dance-in-the-crypt-386961.mp3"),
	"underneath" : preload("res://assets/music/dance-in-the-crypt-386961.mp3"),
	"well-underneath" : preload("res://assets/music/dance-in-the-crypt-386961.mp3"),
	"crypt" : preload("res://assets/music/dramatic-choir-143130.mp3"),
	"tower" : preload("res://assets/music/hidden-339065.mp3"),
	"garden" : preload("res://assets/music/the-haunted-queen-363199.mp3"),
	"big-tower" : preload("res://assets/music/the-haunted-queen-363199.mp3"),
	"z-forest" : preload("res://assets/music/game-aventure-main-theme-251947.mp3"),
	"z-bridge" : preload("res://assets/music/game-aventure-main-theme-251947.mp3"),
	"z-avars" : preload("res://assets/music/game-aventure-main-theme-251947.mp3"),
	"z-chasm" : preload("res://assets/music/game-aventure-main-theme-251947.mp3"),
	"z-ship" : preload("res://assets/music/pirate-bay-357746.mp3"),
	"z-beach" : preload("res://assets/music/pirate-bay-357746.mp3"),
	"z-cave" : preload("res://assets/music/deep-forest-335081.mp3"),
	"z-fc-" : preload("res://assets/music/mysterious-esoteric-magical-shadowy-dark-fairytale-music-369257.mp3"),
	"x-tower-" : preload("res://assets/music/x-tower.mp3"),
	"forest-entry-death" : preload("res://assets/music/silence.mp3"),
	"death-sea" : preload("res://assets/music/silence.mp3")
}

var generic_theme := preload("res://assets/music/the-ballad-of-my-sweet-fair-maiden-medieval-style-music-358306.mp3")

var active_dev_mode = false

# ============================================================================
# CHECKS WHETHER ACCESS TO A TARGET ROOM IS BLOCKED BY AN OBJECT OR CHARACTER.
# SCANS MOVABLE OBJECTS AND CHARACTERS REPOSITORIES TO DETECT COLLISIONS
# AT THE GIVEN POSITION. RETURNS BLOCKING OBJECT DATA IF ANY.
# ============================================================================
func check_blocked_next_room(room,pos) :
	var repository = non_fixed_objects_repository.duplicate()
	repository.merge(characters_repository,false)
	for uid in repository :
		if repository[uid]["room"] == room :
			var obj_b = repository[uid]
			var has_intersect = intersects(pos,player.object_size+Vector3(0,0,0),obj_b["pos"],obj_b["size"]+Vector3(0,0,0))
			if has_intersect :
				return [true,obj_b["uid"],obj_b["type"]]
	return [false,"",""]

# Returns the logical size of a room using its metadata.
# Loads and instantiates the room scene temporarily without adding it to the scene tree.
func get_size_room(room_name: String) -> Vector2:
	var room_scene = load("res://scenes/rooms/" + room_name + ".tscn")
	var room = room_scene.instantiate()
	return room.get_meta("size")

# ===============================================================
# Loads a complete room and manages the transition between rooms.
# Handles visual fading, music, ambient sounds, object loading,
# character loading, player placement, and depth recalculation.
# ===============================================================
func load_room(room_name: String, player_position : Vector3) -> void:
	var fade = null
	var tween = null
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"),0)
	music_a = $/root/Main/music_player_a
	music_b = $/root/Main/music_player_b
	time_stoped = false
	if room_name == "final-chapter-1" : 
		music_a.stop()
		music_b.stop()
		$/root/Main/Characters/Player/Sprite.visible = false
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"),-80)
		fade = get_node("/root/Main/FadeFull/FadeControl/FadeRect")
		tween = create_tween()
		tween.tween_property(fade, "color:a", 1, 0.5)
		await get_tree().create_timer(1).timeout
		get_tree().paused = true
		await get_tree().create_timer(1.0, true).timeout
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/chapter-2-intro.tscn")
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"),0)
		return

	if room_name == "final-chapter-2" : 
		music_a.stop()
		music_b.stop()
		$/root/Main/Characters/Player/Sprite.visible = false
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"),-80)
		fade = get_node("/root/Main/FadeFull/FadeControl/FadeRect")
		tween = create_tween()
		tween.tween_property(fade, "color:a", 1, 0.5)
		await get_tree().create_timer(1).timeout
		get_tree().paused = true
		await get_tree().create_timer(1.0, true).timeout
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/chapter-3.tscn")
		return
		
	if room_name == "final-chapter-3" : 
		music_a.stop()
		music_b.stop()
		$/root/Main/Characters/Player/Sprite.visible = false
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"),-80)
		fade = get_node("/root/Main/FadeFull/FadeControl/FadeRect")
		tween = create_tween()
		tween.tween_property(fade, "color:a", 1, 0.5)
		await get_tree().create_timer(1).timeout
		get_tree().paused = true
		await get_tree().create_timer(1.0, true).timeout
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/chapter-final.tscn")
		return

	fade = get_node("/root/Main/FadeLayer/FadeControl/FadeRect")
	tween = create_tween()
	tween.tween_property(fade, "color:a", 1, 0.0)
	
	scene_objects.clear()
	p_r_name = r_name
	r_name = room_name
	if not room_name in ["chapter-1","chapter-2-intro","chapter-2","chapter-3","chapter-final","forest-entry-death","death-sea"] and room_name not in visited_rooms : visited_rooms.append(room_name)
		
	update_music_from_room(r_name)

	var room_elements = null
	if has_node("/root/Main/Room/RoomElements") : 
		room_elements = get_node("/root/Main/Room/RoomElements")
		room_elements.free()

	var room_scene = load("res://scenes/rooms/"+room_name+".tscn")
	current_room = room_scene.instantiate()
	get_tree().get_root().get_node("Main/Room").add_child(current_room)
	
	room_elements = get_node("/root/Main/Room/RoomElements")
	origin = get_node("/root/Main/Room/RoomElements/origin").global_position
	cam = get_node("/root/Main/Room/RoomElements/Camera")
	cam.make_current()
	
	room_size = room_elements.get_meta("size")
	
	if setup_sound_fx and room_elements.has_meta("fire") and room_elements.get_meta("fire") == true : $/root/Main/Sounds/Fire.play()
	else : $/root/Main/Sounds/Fire.stop()

	if setup_sound_fx and room_elements.has_meta("lava") and room_elements.get_meta("lava") == true : $/root/Main/Sounds/Lava.play()
	else : $/root/Main/Sounds/Lava.stop()

	if setup_sound_fx and room_elements.has_meta("rain") and room_elements.get_meta("rain") == true : $/root/Main/Sounds/Rain.play()
	else : $/root/Main/Sounds/Rain.stop()


	var sea_sound = get_node("/root/Main/Sounds/Sea")
	if setup_sound_fx and room_elements.has_meta("sea") and room_elements.get_meta("sea") == true and not sea_sound.playing : $/root/Main/Sounds/Sea.play()
	elif not setup_sound_fx or not room_elements.has_meta("sea") or (room_elements.has_meta("sea") and not room_elements.get_meta("sea")) : $/root/Main/Sounds/Sea.stop()
	
	connection_north = room_elements.get_meta("north")
	connection_south = room_elements.get_meta("south")
	connection_west = room_elements.get_meta("west")
	connection_east = room_elements.get_meta("east")
	if room_elements.has_meta("north_offset") : offset_north = room_elements.get_meta("north_offset")
	if room_elements.has_meta("south_offset") : offset_south = room_elements.get_meta("south_offset")
	if room_elements.has_meta("west_offset") : offset_west = room_elements.get_meta("west_offset")
	if room_elements.has_meta("east_offset") : offset_east = room_elements.get_meta("east_offset")	

	replace_helmet_by_guard()
	load_fixed_objects()
	load_non_fixed_objects()
	load_character_objects()

	#print("--------------------------------------------")
	#for obj_scene in scene_objects :
		#if scene_objects[obj_scene]["type"] == "door" :
			#print(scene_objects[obj_scene]["name"],":",scene_objects[obj_scene]["pos"])
	
	load_player(player_position)

	if room_elements.has_meta("light") :
		var l = room_elements.get_meta("light")
		room_elements.modulate = Color(l, l, l, 1.0)
		player.modulate = Color(l, l, l, 1.0)
	else :
		room_elements.modulate = Color(1, 1, 1, 1.0)
		player.modulate = Color(1, 1, 1, 1.0)


	for obj_scene in scene_objects :

		if scene_objects[obj_scene]["type"] == "guard" and characters_repository[scene_objects[obj_scene]["name"]]["status"] == "rebirth" :
			var has_intersect=check_intersection(obj_scene,scene_objects[obj_scene]["pos"])
			var p_z = scene_objects[obj_scene]["pos"].z
			if has_intersect[0] and not has_intersect[3] in ["pirate","ogre","wolf","skel","demon"] and p_z < scene_objects[has_intersect[1]]["pos"].z :
				replace_guard_by_helmet(obj_scene,scene_objects[obj_scene]["name"],0)
			if has_intersect[3]=="guard" and scene_objects[has_intersect[1]]["pos"].z < p_z :
				replace_guard_by_helmet(has_intersect[1],scene_objects[has_intersect[1]]["name"],0)

	var sorted_objects = get_topologically_sorted_ids()	
	var k = 500
	for obj in sorted_objects:
		k+=50
		scene_objects[obj]["depth"] = k
		instance_from_id(obj).z_index = k
		if scene_objects[obj]["name"]=="tom5" : 
			scene_objects[obj]["depth"] = 775
			instance_from_id(obj).z_index = 775

	for obj in sorted_objects:
		if scene_objects[obj]["type"] in ["movable","portable"] :
			update_object_z_index(obj)
			instance_from_id(obj).z_index = scene_objects[obj]["depth"]

	# load_player(player_position)
	tile_rr = room_elements.get_meta("tile_rr")
	cam.make_current()
	#get_node("/root/Main/Room").visible = true
	tween.tween_property(fade, "color:a", 0, 0.3)

# ==========================================================
# LOADS AND REGISTERS ALL FIXED OBJECTS OF THE CURRENT ROOM.
# CONVERTS SCREEN COORDINATES TO ISOMETRIC COORDINATES AND
# REGISTERS OBJECTS IN THE GLOBAL SCENE REGISTRY.
# ==========================================================
func load_fixed_objects():
	var fixed_objects_node = get_node("/root/Main/Room/RoomElements/FixedObjects")
	var pos := Vector3.ZERO
	for obj in fixed_objects_node.get_children():
		
		if obj.has_meta("size") and obj.has_meta("pos"):
			var size = obj.get_meta("size")
			if obj.get_meta("type") == "vgate" :
				pos = obj.get_meta("pos")
			else :
				var z = obj.get_meta("pos").z
				pos = screen_to_iso(obj.global_position,size,origin,SCALE,z)
				var pos_iso_center = Mainglobal.iso_object_center(pos,size)
				var pos_screen = Mainglobal.iso_to_screen(pos_iso_center, Mainglobal.origin, Mainglobal.SCALE)
				obj.global_position = pos_screen
			scene_objects[obj.get_instance_id()] = {
				"room" : r_name,
				"pos": pos,
				"size": size,
				"type": obj.get_meta("type"),
				"name": str(obj.name),
				"status": "none",
				"is_jumping" : false,
				"is_falling" : false,
				"is_moving" : false,
				"exact" : false,
				"depth" : 0
			}
			if obj.has_meta("notinv") : scene_objects[obj.get_instance_id()]["notinv"] = obj.get_meta("notinv")
			if obj.has_meta("has_frame") : scene_objects[obj.get_instance_id()]["has_frame"] = obj.get_meta("has_frame")
			if obj.has_meta("exact") : scene_objects[obj.get_instance_id()]["exact"] = obj.get_meta("exact")
			if obj.has_meta("key") : scene_objects[obj.get_instance_id()]["key"] = obj.get_meta("key")
			if obj.has_meta("target_direction") :  scene_objects[obj.get_instance_id()]["target_direction"] = obj.get_meta("target_direction")
			if obj.has_meta("target") : scene_objects[obj.get_instance_id()]["target"] = obj.get_meta("target")
			if obj.has_meta("target_pos") : scene_objects[obj.get_instance_id()]["target_pos"] = obj.get_meta("target_pos")
			if obj.has_meta("target_offset") : scene_objects[obj.get_instance_id()]["target_offset"] = obj.get_meta("target_offset")
			if obj.has_meta("orientation") : scene_objects[obj.get_instance_id()]["orientation"] = obj.get_meta("orientation")


# ============================================================
# LOADS NON-FIXED OBJECTS (MOVABLE OR PORTABLE).
# PERSISTS THEIR LOGICAL STATE IN A GLOBAL REPOSITORY AND
# REINSTANTIATES THEM ONLY IF THEY BELONG TO THE CURRENT ROOM.
# ============================================================
func load_non_fixed_objects() :
	
	var non_fixed_objects_node = null
	if has_node("/root/Main/Room/RoomElements/NonFixedObjects") : 
		non_fixed_objects_node = get_node("/root/Main/Room/RoomElements/NonFixedObjects")

	if non_fixed_objects_node :
		for obj in non_fixed_objects_node.get_children():
			var uid = obj.get_meta("uid")
			if not non_fixed_objects_repository.has(uid) :
				non_fixed_objects_repository[uid] = {
					"uid" : uid,
					"room" : r_name,
					"pos": screen_to_iso(obj.global_position,obj.get_meta("size"),origin,SCALE,obj.get_meta("pos").z),
					"size": obj.get_meta("size"),
					"type": obj.get_meta("type"),
					"subtype": obj.get_meta("subtype"),
					"sprite": obj.texture.resource_path,
					"weight": obj.get_meta("weight"),
					"status": "none",
					"is_falling" : false,
					"is_moving" : false,
			} 
	
			obj.free()

	for uid in non_fixed_objects_repository :
		if non_fixed_objects_repository[uid]["room"] == r_name :
			if non_fixed_objects_repository[uid]["subtype"] == "crystal" :
				non_fixed_objects_repository[uid]["status"] = "none"
			instantiate_room_object(uid)
  
# ============================================================================
# LOADS CHARACTERS (ENEMIES) DEFINED IN THE ROOM.
# INITIALIZES PERSISTENT STATES, INITIAL DIRECTIONS, AND SPECIAL CONDITIONS.
# ============================================================================
func load_character_objects() :

	var characters_node = null
	if has_node("/root/Main/Room/RoomElements/Characters") : 
		characters_node = get_node("/root/Main/Room/RoomElements/Characters")
	
	if characters_node :
		for obj in characters_node.get_children():
			var uid = obj.get_meta("uid")
			if not characters_repository.has(uid) or obj.get_meta("subtype")=="bubble":
				characters_repository[uid] = {
					"uid" : uid,
					"room" : r_name,
					"pos": screen_to_iso(obj.global_position,obj.get_meta("size"),origin,SCALE,obj.get_meta("z_init")),
					"size": obj.get_meta("size"),
					"type": obj.get_meta("type"),
					"subtype": obj.get_meta("subtype"),
					"weight": obj.get_meta("weight"),
					"status": "none",
					"is_falling" : false,
					"is_jumping" : false,
					 "is_moving" : false,
					"direction" : "",
					"direction_x" : "",
					"direction_y" : "",
					"disabled_door" : "none",
					"life" : life_enemies
				}
				if obj.has_meta("disabled_door") :
					characters_repository[uid]["disabled_door"] = obj.get_meta("disabled_door")
					for s_object in scene_objects :
						if scene_objects[s_object]["name"] == obj.get_meta("disabled_door") :
							scene_objects[s_object]["status"] = "disabled"

			
				if obj.get_meta("type") in ["pirate","guard","ogre","monk","wolf","slab","skel","demon"] :
					characters_repository[uid]["direction"] = obj.get_meta("direction_init")
					
				if obj.get_meta("type") in ["twister","bubble","blob"] :
					characters_repository[uid]["direction_x"] = obj.get_meta("direction_init_x")
					characters_repository[uid]["direction_y"] = obj.get_meta("direction_init_y")
				
			if obj.get_meta("subtype") == "guard-rebirth" : 
				characters_repository[uid]["status"] = "rebirth"
			
			if obj.get_meta("subtype") == "monk-static" and obj.has_meta("door_disabled") :
				pass
				
			obj.free()

	for uid in characters_repository :
		if characters_repository[uid]["room"] == r_name and characters_repository[uid]["type"] != "character":
			if characters_repository[uid]["subtype"] in ["wolf","ogre","bubble","twister","pirate","skel","demon","blob"] :
				characters_repository[uid]["life"] = life_enemies
			instantiate_character(uid,characters_repository[uid]["type"])
	
# ======================================================================
# REPLACES A GUARD CHARACTER WITH A HELMET PORTABLE OBJECT.
# REMOVES THE CHARACTER NODE AND CREATES A PERSISTENT OBJECT EQUIVALENT.
# ======================================================================
func replace_guard_by_helmet(scene_id,repository_id,z) :
	get_node("/root/Main/Room/RoomElements/Characters/"+repository_id).queue_free()
	global_tmp_depth = scene_objects[scene_id]["depth"]
	scene_objects.erase(scene_id)
	non_fixed_objects_repository[repository_id] = characters_repository[repository_id].duplicate()
	non_fixed_objects_repository[repository_id]["sprite"] = "res://assets/objects/helmet.png"
	non_fixed_objects_repository[repository_id]["type"] = "portable"
	non_fixed_objects_repository[repository_id]["subtype"] = "guard-helmet"
	non_fixed_objects_repository[repository_id]["size"] = Vector3(10,10,9.0)
	non_fixed_objects_repository[repository_id]["pos"] += Vector3(0,0,z)
	non_fixed_objects_repository[repository_id]["weight"] = 8
	characters_repository[repository_id]["room"] = "none"
	instantiate_room_object(repository_id)
	return


# ==========================================================
# RESTORES GUARD CHARACTERS FROM PERSISTENT HELMET OBJECTS.
# CONVERTS HELMET OBJECTS BACK INTO GUARDS IN REBIRTH STATE.
# ==========================================================
func replace_helmet_by_guard() :
	var non_fixed_objects_repository_dup = non_fixed_objects_repository.duplicate()
	for obj_repository in non_fixed_objects_repository_dup :
		if non_fixed_objects_repository[obj_repository]["subtype"] == "guard-helmet" and non_fixed_objects_repository[obj_repository]["room"] == r_name:
			characters_repository[non_fixed_objects_repository[obj_repository]["uid"]]["room"] = r_name
			characters_repository[non_fixed_objects_repository[obj_repository]["uid"]]["pos"] = non_fixed_objects_repository[obj_repository]["pos"]
			characters_repository[non_fixed_objects_repository[obj_repository]["uid"]]["status"] = "rebirth"
			characters_repository[non_fixed_objects_repository[obj_repository]["uid"]]["life"] = life_enemies
			non_fixed_objects_repository.erase(obj_repository)


# ======================================================================
# INITIALIZES AND REGISTERS AN INSTANTIATED OBJECT IN THE GLOBAL SYSTEM.
# COMPUTES ITS ISOMETRIC CENTER, SCREEN POSITION, AND INITIAL STATE.
# ======================================================================
func load_data(uid,obj,sprite) :
	var pos_iso_center = Mainglobal.iso_object_center(obj["pos"],obj["size"])
	var pos_screen = Mainglobal.iso_to_screen(pos_iso_center, Mainglobal.origin, Mainglobal.SCALE)
	sprite.global_position = pos_screen
	
	Mainglobal.scene_objects[sprite.get_instance_id()] = {
		"name": uid,
		"node": sprite,
		"pos": obj["pos"],
		"size": obj["size"],
		"type": obj["type"],
		"subtype" : obj["subtype"],
		"weight": obj["weight"],
		"status": obj["status"],
		"is_jumping" : false,
		"is_falling" : false,
		"is_moving" : false,
		"depth" : global_tmp_depth
	}
	if obj["subtype"] == "guard-rebirth" : 
		Mainglobal.scene_objects[sprite.get_instance_id()]["status"] = "rebirth"
	update_object_z_index(sprite.get_instance_id())
	if global_tmp_depth != 0 : global_tmp_depth = 0


# ======================================================================
# COMPUTES THE RESULTING INERTIA OF A PUSH INTERACTION.
# TAKES INTO ACCOUNT SOURCE WEIGHT, TARGET WEIGHT, AND VERTICAL PUSHING.
# ======================================================================
func get_inertia(source_weight,weight,above) :
	var inertia = 0
	if source_weight ==999 : return 999
	if source_weight == weight and source_weight<=4 : inertia = 5
	if source_weight == weight and source_weight>4 : inertia = 4
	
	if source_weight > weight : inertia = source_weight - weight
	
	if source_weight < weight :
		if source_weight == 1 : inertia = 1
		if source_weight in [2,3] : inertia = 2
		if source_weight in [4] : inertia = 3
		if source_weight in [5,6] : inertia = 4
		if source_weight in [7,8,9] : inertia = 5

	inertia = inertia * 2 - 1
	
	#inertia = round(clamp((source_weight / weight) * 4.0 + 1.0, 1, 8))
	
	if above : inertia = 1
	return(inertia)

# ================================================================
# APPLIES AN ACTIVE PUSH BETWEEN OBJECTS OR CHARACTERS.
# HANDLES CHAINED PUSHES, MOVEMENT VALIDATION, DYNAMIC COLLISIONS,
# INERTIA CONSUMPTION, AND POSITION UPDATES.
# ================================================================
func push_object(self_node, speed, obj, self_inertia, direction, repository):

	var is_player = false
	if "name" in obj:
		if obj["name"] == "Player":
			is_player = true

	var self_node_id = self_node.get_instance_id()
	self_inertia -= 1

	var new_pos_iso : Vector3 = obj["pos"] + speed * Mainglobal.get_vector_direction(direction)

	# ───── COMPROBAR SI EL MOVIMIENTO ES VÁLIDO ─────
	var can_move = Mainglobal.can_move_to_iso(self_node_id, new_pos_iso, is_player)

	# ───── COMPROBAR INTERSECCIÓN FRONTAL (PARA EMPUJES) ─────
	var has_intersect : Array = Mainglobal.check_intersection(self_node_id, new_pos_iso)
	

	if can_move or (has_intersect[0] and has_intersect[3] in ["movable","portable","guard","ogre","wolf","monk","twister","character","slab","pirate","skel","demon","blob"]):

		# ───── EMPUJE ACTIVO A OBJETOS ─────
		if has_intersect[0] and has_intersect[3] in ["movable","portable"]:
			var object = get_node("/root/Main/Room/RoomElements/NonFixedObjects/" + has_intersect[2])
			if not direction.contains("upper"):
				object.push(obj, speed, obj["weight"], direction, false)
			else:
				object.push(obj, speed, 1, direction, true)
			await object.push_finished

		# ───── EMPUJE ACTIVO A PERSONAJES ─────
		if has_intersect[0] and has_intersect[3] in ["guard","ogre","monk","wolf","slab","pirate","skel","demon","blob"]:
			var object = get_node("/root/Main/Room/RoomElements/Characters/" + has_intersect[2])
			object.push(obj, speed, 1, direction, false)

		if has_intersect[0] and has_intersect[2] in ["Player"]:
			var object = get_node("/root/Main/Characters/" + has_intersect[2])
			object.push(obj, speed, 1, direction, false)
			return 0

		# ───── RECOMPROBAR INTERSECCIÓN TRAS EMPUJES ─────
		has_intersect = Mainglobal.check_intersection(self_node_id, new_pos_iso)

		if not has_intersect[0] and can_move:

			Mainglobal.scene_objects[self_node_id]["pos"] = new_pos_iso

			if repository == "non_fixed_objects":
				Mainglobal.non_fixed_objects_repository[Mainglobal.scene_objects[self_node_id]["name"]]["pos"] = new_pos_iso

			if repository == "characters":
				Mainglobal.characters_repository[Mainglobal.scene_objects[self_node_id]["name"]]["pos"] = new_pos_iso

			var pos_iso_center = Mainglobal.iso_object_center(Mainglobal.scene_objects[self_node_id]["pos"], Mainglobal.scene_objects[self_node_id]["size"])
			var pos_screen = Mainglobal.iso_to_screen(pos_iso_center, Mainglobal.origin, Mainglobal.SCALE)

			Mainglobal.update_object_z_index(self_node_id)
			self_node.global_position = pos_screen

	else:
		self_inertia = 0

	return self_inertia

# ============================================================================
# APPLIES PASSIVE MOVEMENT TO OBJECTS LOCATED ABOVE ANOTHER MOVING OBJECT.
# ENSURES STACKED OBJECTS MOVE CONSISTENTLY WITH THEIR SUPPORT.
# ============================================================================
func check_over_movement(self_object, variation):

	for object_over in Mainglobal.scene_objects:

		var has_intersect_over : Array = Mainglobal.check_over_intersection(self_object, Mainglobal.scene_objects[self_object]["pos"] + Vector3(0,0,1), object_over)
		if not has_intersect_over[0]:
			continue

		var over_id = has_intersect_over[1]
		var over_type = has_intersect_over[3]
		var over_data = Mainglobal.scene_objects[over_id]

		var new_pos_iso = over_data["pos"] + variation


		if over_type in ["movable","portable"]:
			if Mainglobal.can_move_to_iso(over_id, new_pos_iso, false):
				get_node("/root/Main/Room/RoomElements/NonFixedObjects/" + has_intersect_over[2]).passive_move = variation

		elif over_type == "character":
			if Mainglobal.can_move_to_iso(over_id, new_pos_iso, false):
				get_node("/root/Main/Characters/" + has_intersect_over[2]).passive_move = variation

		elif over_type in ["guard","ogre","monk","wolf","pirate","skel","demon","blob"]:
			if Mainglobal.can_move_to_iso(over_id, new_pos_iso, false):
				get_node("/root/Main/Room/RoomElements/Characters/" + has_intersect_over[2]).passive_move = variation

		var can_move = Mainglobal.can_move_to_iso(over_id, new_pos_iso, false)
		if not can_move:
			continue


# ============================================================================
# DETERMINES WHETHER AN ISOMETRIC POSITION IS WALKABLE.
# CHECKS WALLS, ROOM BOUNDARIES, DOORS, VOID TILES, FLOOR POLYGONS,
# AND COLLISIONS WITH OTHER OBJECTS.
# ============================================================================
func can_move_to_iso(object_id, new_pos_iso, is_player):

	var obj = scene_objects[object_id]

	# ───── 1. MUROS ─────
	var current_tilelevel = int(obj["pos"].z / 20) + 1
	var has_collision_wall = check_exists_tile_from_iso(new_pos_iso + (obj["size"] / 3 * Vector3(1,1,0)), origin, SCALE, current_tilelevel, "wall")
	if has_collision_wall: return false

	# ───── 2. LÍMITES / SUELO (GENÉRICO) ─────
	var reached_limit = check_reached_limit(new_pos_iso, obj["size"], has_collision_wall, is_player)
	if reached_limit: return false

	# ───── 3. COLISIÓN FRONTAL ─────
	var has_intersect = check_intersection(object_id, new_pos_iso)
	if has_intersect[0]: return false

	# ───── 4. PUERTAS / GATE ─────
	var new_pos_iso_center = new_pos_iso + Vector3(obj["size"].x / 2,obj["size"].y / 2,0)
	var has_overlap = check_intersection(object_id, new_pos_iso_center - Vector3(5,5,1))
	if has_overlap[3] == "gate": return false

	# ───── 5. VACÍO ─────
	var has_void = check_exists_void_from_iso(obj["pos"] + get_vector_direction(obj.get("move_direction","")), origin, SCALE)
	if has_void: return false

	# ───── 6. POLÍGONO DE SUELO / ESCALERAS ─────
	var prev_pos_screen = iso_to_screen(obj["pos"] + Vector3(0,0,-1), origin, SCALE)
	var new_pos_screen = iso_to_screen(new_pos_iso + Vector3(0,0,-1), origin, SCALE)
	var prev_has_polygon_floor = in_floor_polygon(obj["pos"] + Vector3(0,0,-1), prev_pos_screen)
	var new_has_polygon_floor = in_floor_polygon(new_pos_iso + Vector3(0,0,-1), new_pos_screen)
	var has_stairs = check_intersection(object_id, new_pos_iso + Vector3(0,0,-6))
	if prev_has_polygon_floor and not new_has_polygon_floor and not has_stairs[0] and obj["pos"].z <= 1: return false

	return true


# ============================================================================
# HANDLES STEP-BY-STEP STAIR CLIMBING.
# MANAGES VERTICAL MOVEMENT, PUSHING OBJECTS ABOVE,
# AND BLOCKING CONDITIONS DURING ASCENT.
# ============================================================================
func climb_stairs(self_id, obj_scene, has_intersect, move_direction, step_status, is_player) -> Dictionary:
	var on_steps = true
	var new_step_status = step_status
	var allow_up_step = true
	var n_steps = int(has_intersect[3].replace("step-",""))
	var dif_height = scene_objects[has_intersect[1]]["size"].z + scene_objects[has_intersect[1]]["pos"].z - obj_scene["pos"].z

	if dif_height <= n_steps and ((move_direction == "up" and has_intersect[4] == "northsouth") or (move_direction == "right" and has_intersect[4] == "westeast")):
		scene_objects[self_id]["is_jumping"] = false
		if is_player : check_over_movement(self_id, get_vector_direction(move_direction) + Vector3(0,0,1))
		for object_over in scene_objects:
			var has_intersect_over = check_over_intersection(self_id, obj_scene["pos"] + Vector3(0,0,1), object_over)
			if has_intersect_over[0] and has_intersect_over[3] in ["movable","portable"]:
				scene_objects[has_intersect_over[1]]["node"].push(obj_scene,1,1,"upper",true)
				await scene_objects[has_intersect_over[1]]["node"].push_finished
				has_intersect_over = check_over_intersection(self_id, obj_scene["pos"] + Vector3(0,0,1), object_over)
				if has_intersect_over[0]:
					allow_up_step = false

		check_over_movement(self_id, get_vector_direction(move_direction) + Vector3(0,0,1))

		if allow_up_step:
			new_step_status += 1
			obj_scene["pos"] += Vector3(0,0,1)

			if new_step_status == n_steps:
				new_step_status = 0
				obj_scene["pos"] += get_vector_direction(move_direction)

				for object_over in scene_objects:
					var has_intersect_over = check_over_intersection(self_id, obj_scene["pos"] + Vector3(0,0,1), object_over)
					if has_intersect_over[0] and has_intersect_over[3] in ["movable","portable"]:
						var node = get_node("/root/Main/Room/RoomElements/NonFixedObjects/"+has_intersect_over[2])
						node.push(object_over,1,1,move_direction+"upper",true)
						await node.push_finished

				check_over_movement(self_id, get_vector_direction(move_direction) + Vector3(0,0,1))

	return {
		"on_steps": on_steps,
		"step_status": new_step_status,
		"z_jump": 0
	}


# Determines the optimal movement direction towards the player.
# Adjusts enemy direction dynamically based on distance and blocked paths.
func set_best_move_direction(obj_scene,move_direction,blocked_direction,type) :
	var prev_pos_iso = obj_scene["pos"]
	var distance_to_player_x = 9999.9999
	var distance_to_player_y = 9999.9999
	var difference = 0
	
	distance_to_player_x = abs(prev_pos_iso.x - Mainglobal.scene_objects[Mainglobal.player.self_id]["pos"].x)
	distance_to_player_y = abs(prev_pos_iso.y - Mainglobal.scene_objects[Mainglobal.player.self_id]["pos"].y)
		
	var change_direction = true
	var player_pos = Mainglobal.scene_objects[Mainglobal.player.self_id]["pos"]
	if prev_pos_iso.x + difference <= player_pos.x and move_direction == "down" and blocked_direction != "down" : change_direction = false
	if prev_pos_iso.x + difference > player_pos.x and move_direction == "up" and blocked_direction != "up" : change_direction = false
	if prev_pos_iso.y + difference <= player_pos.y and move_direction == "left" and blocked_direction != "left" : change_direction = false
	if prev_pos_iso.y + difference > player_pos.y and move_direction == "right" and blocked_direction != "right" : change_direction = false
		
	if change_direction :
		if prev_pos_iso.x + difference <= player_pos.x and distance_to_player_x >= distance_to_player_y and blocked_direction != "down":
			move_direction = "down"
		elif prev_pos_iso.x - difference > player_pos.x and distance_to_player_x >= distance_to_player_y and blocked_direction != "up":
			move_direction = "up"
		elif prev_pos_iso.y + difference <= player_pos.y and distance_to_player_x < distance_to_player_y and blocked_direction != "left":
			move_direction = "left"
		elif prev_pos_iso.y - difference > player_pos.y and distance_to_player_x < distance_to_player_y and blocked_direction != "right":
			move_direction = "right"
	
	if type=="wolf" and Mainglobal.player_is_woman :
		move_direction = "left"
	
	return move_direction


# Displays a temporary on-screen message.
# Shows the player's current life along with the provided text.
func show_temporary_message(text: String, duration: float) -> void:
	if get_node("/root/Main/UI2/CanvasLayer2/Control/Frame/message") :
		get_node("/root/Main/UI2/CanvasLayer2/Control/Frame/message").text = "     LIFE FORCE: "+str(life_player)+"\n     "+text
	await get_tree().create_timer(duration).timeout
	if get_node("/root/Main/UI2/CanvasLayer2/Control/Frame/message") :
		get_node("/root/Main/UI2/CanvasLayer2/Control/Frame/message").text = "     LIFE FORCE: "+str(life_player)+"\n                       "


# Instantiates a non-fixed object in the current room.
# Creates its visual node, registers it globally, and adds a shadow occluder.
func instantiate_room_object(uid) :
	var object_scene = null
	if non_fixed_objects_repository[uid]["subtype"] != "crystal" :
		object_scene = load("res://scenes/object.tscn").instantiate()
	else : 
		object_scene = load("res://scenes/crystal.tscn").instantiate()

	var room_elements = get_node("/root/Main/Room/RoomElements")
	if not room_elements.has_node("NonFixedObjects"):
		var new_node = Node2D.new()
		new_node.name = "NonFixedObjects"
		room_elements.add_child(new_node)

	object_scene.name = uid
	get_node("/root/Main/Room/RoomElements/NonFixedObjects").add_child(object_scene)
	object_scene.load_data(uid)
	
	# ===== Añadir LightOccluder2D como hijo para simular la sombra =====
	var sprite = object_scene  # el sprite es el nodo raíz
	var half_w = (Mainglobal.scene_objects[sprite.get_instance_id()]["size"].x/2 + Mainglobal.scene_objects[sprite.get_instance_id()]["size"].y/2) / 2
	var half_h = Mainglobal.scene_objects[sprite.get_instance_id()]["size"].z/2

	var polygon := OccluderPolygon2D.new()
	polygon.polygon = create_oval_polygon(half_w, half_h, 20)

	var occluder := LightOccluder2D.new()
	occluder.name = "AutoOccluder"
	occluder.position = occluder.position + Vector2(0,half_h)
	occluder.occluder = polygon
	# occluder.z_index = 1
	sprite.add_child(occluder)


# Instantiates a character in the current room.
# Creates the character node and registers it in the global systems.
func instantiate_character(uid,type) :
	var object_scene = load("res://scenes/characters/"+type+".tscn").instantiate()
	var room_elements = get_node("/root/Main/Room/RoomElements")
	if not room_elements.has_node("Characters"):
		var new_node = Node2D.new()
		new_node.name = "Characters"
		room_elements.add_child(new_node)

	object_scene.name = uid
	get_node("/root/Main/Room/RoomElements/Characters").add_child(object_scene)
	object_scene.load_data(uid)
	

# Activates the currently selected inventory slot visually.
# Updates slot visibility and scaling.
func set_active_inv() :
	var inv_node = null
	var k:=0
	while k<5 :
		k+=1
		inv_node = get_node("/root/Main/UI/InventoryLayer/inv"+str(k))
		var sprite_node = get_node("/root/Main/UI/InventoryLayer/sprite_inv"+str(k))
		inv_node.visible = false
		sprite_node.scale = SCALE
	inv_node = get_node("/root/Main/UI/InventoryLayer/inv"+str(active_inv))
	inv_node.visible = true
		

# Loads or repositions the player in the current room.
# Instantiates the player if needed and registers its logical state.
func load_player(player_position : Vector3) :
	
	if not player:
		var player_scene = load(PLAYER_SCENE_PATH)
		player = player_scene.instantiate()
		get_node("/root/Main/Characters").add_child(player)
	
	if player.move_direction == "down" : player_position = Vector3(ceil(player_position.x), round(player_position.y), player_position.z)
	if player.move_direction == "left" : player_position = Vector3(round(player_position.x), ceil(player_position.y), player_position.z)
	if player.move_direction == "up" : player_position = Vector3(floor(player_position.x), round(player_position.y), player_position.z)
	if player.move_direction == "right" : player_position = Vector3(round(player_position.x), floor(player_position.y), player_position.z)

	
	if player_position.x+player.object_size.x>room_size.x-1 : player_position.x=room_size.x-1-player.object_size.x
	if player_position.y+player.object_size.y>room_size.y-1 : player_position.y=room_size.y-1-player.object_size.y
	if player_position.x<1 : player_position.x=1
	if player_position.y<1 : player_position.y=1
	player.pos_iso = player_position
	scene_objects[player.get_instance_id()] = {
		"pos": player.pos_iso,
		"size": player.object_size,
		"type": "character",
		"name": str(player.name),
		"status":"none",
		"weight": 6,
		"is_jumping" : false,
		"is_falling" : false,
		"is_moving" : false,
		"is_attacking" : false,
		"is_pickup" : false,
		"depth" : 0
	}
	
	characters_repository["Player"] = {
		"uid" : "Player",
		"room" : r_name,
		"pos": player.pos_iso,
		"size": player.object_size,
		"type": "character",
		"subtype": "Player",
		"weight": 6,
		"status": "none",
		"is_falling" : false,
		"is_moving" : false,
		"direction" : ""
	}
		
	if r_name in ["tower-north-loft","tower-south-loft","big-tower-loft"] and not p_r_name in ["tower-north-loft","tower-south-loft"]:
		scene_objects[player.get_instance_id()]["is_jumping"] = true
		if player.jump_direction != "" :
			scene_objects[player.get_instance_id()]["is_moving"] = true
	
	var pos_iso_center := iso_object_center(player.pos_iso,player.object_size)
	var pos_screen := iso_to_screen(pos_iso_center, origin, SCALE)
	player.global_position = pos_screen
	update_object_z_index(player.get_instance_id())


# Converts isometric coordinates to screen coordinates.
# Transforms a logical 3D position (X,Y,Z) into 2D render space.
func iso_to_screen(iso: Vector3, origin_point: Vector2, scale: Vector2) -> Vector2:
	# iso representa la esquina inferior izquierda posterior (min x, min y, min z)
	var px = iso.x - iso.y
	var py = (iso.x + iso.y) * 0.5 - iso.z
	var screen_x = origin_point.x + px * scale.x
	var screen_y = origin_point.y + py * scale.y
	return Vector2(screen_x, screen_y)


# Computes the volumetric center of an isometric object.
# Used for accurate visual positioning.
func iso_object_center(pos_iso: Vector3, size: Vector3) -> Vector3:
	var x = pos_iso.x + size.x / 2.0
	var y = pos_iso.y + size.y / 2.0
	var z = pos_iso.z + size.z / 2.0
	return Vector3(x, y, z)


# Converts screen coordinates back to isometric coordinates.
# Reconstructs logical 3D position from a 2D screen position.
func screen_to_iso(global_pos: Vector2, size: Vector3, origin_point: Vector2, scale: Vector2, z_base: float) -> Vector3:
	var v :=  2
	var sx = (global_pos.x - origin_point.x) / scale.x
	var sy = (global_pos.y - origin_point.y) / scale.y
	var z_center = z_base + size.z / v
	var cx = (sx + v * (sy + z_center)) / v
	var cy = (v * (sy + z_center) - sx) / v
	var x = cx - size.x / v
	var y = cy - size.y / v
	var z = z_base
	return Vector3(x, y, z)


# Checks intersection between two 3D axis-aligned bounding boxes.
# Used for volumetric collision detection in isometric space.
func intersects(a_pos: Vector3, a_size: Vector3, b_pos: Vector3, b_size: Vector3) -> bool:
	var a_min = a_pos
	var a_max = a_pos + a_size 
	var b_min = b_pos 
	var b_max = b_pos + b_size 
	return (
		a_min.x < b_max.x and a_max.x > b_min.x and
		a_min.y < b_max.y and a_max.y > b_min.y and
		a_min.z < b_max.z and a_max.z > b_min.z
	)
	

# Computes a general visual depth value.
# Used as a helper for depth ordering calculations.
func compute_general_visual_depth(pos: Vector3, _size: Vector3) -> float:
	var depth = pos.x + pos.y  + pos.z
	return depth
	

# Sorts scene objects based on spatial dependencies.
# Uses a topological sorting approach to resolve drawing order.
func get_topologically_sorted_ids() -> Array:
	var ids := scene_objects.keys()
	var graph := {}  # id → dependencias (lista de ids que deben ir antes)
	var in_degree := {}  # id → número de dependencias

	# Inicializar estructuras
	for id in ids:
		graph[id] = []
		in_degree[id] = 0

	# Construir relaciones basadas en la condición Filmation
	for a in ids:
		var a_pos = scene_objects[a]["pos"]
		var a_size = scene_objects[a]["size"]
		var a_max = a_pos + a_size
		for b in ids:
			if a == b:
				continue
			var b_pos = scene_objects[b]["pos"]
			# Filmation: A va antes que B si A está completamente detrás de B
			if a_max.x <= b_pos.x and a_max.y <= b_pos.y and a_max.z <= b_pos.z:
				graph[a].append(b)
				in_degree[b] += 1

	# Ordenación topológica (Kahn's algorithm)
	var queue := []
	for id in ids:
		if in_degree[id] == 0:
			queue.append(id)

	var sorted := []
	while not queue.is_empty():
		var current = queue.pop_front()
		sorted.append(current)
		for neighbor in graph[current]:
			in_degree[neighbor] -= 1
			if in_degree[neighbor] == 0:
				queue.append(neighbor)

	# Si hay ciclos, se devuelven incompletos
	if sorted.size() < ids.size():
		push_warning("Ordenación incompleta: hay ciclos o solapamientos no resueltos")

	return sorted

# Dynamically updates the z_index of an object.
# Ensures correct visual layering relative to other objects.
func update_object_z_index(id_object) :
	var pos_a = scene_objects[id_object]["pos"]
	scene_objects[id_object]["depth"] = 4000
	for id in scene_objects.keys() :
		if id_object != id :
			var size_b = scene_objects[id]["size"]
			var pos_b = scene_objects[id]["pos"]
		
			if (pos_a.y < pos_b.y + size_b.y and pos_a.x < pos_b.x + size_b.x and pos_a.z < pos_b.z + size_b.z):
				if scene_objects[id]["depth"] <= scene_objects[id_object]["depth"] :
					scene_objects[id_object]["depth"] = scene_objects[id]["depth"] - 1

	if instance_from_id(id_object).z_index != scene_objects[id_object]["depth"] :
		instance_from_id(id_object).z_index = scene_objects[id_object]["depth"]
	

# Checks whether a movement reaches room boundaries.
# Considers room connections and player-specific rules.
func check_reached_limit(new_pos_iso,size,has_collision_wall,is_player) :
	if is_player :
		if has_collision_wall : return true
		if new_pos_iso.x < 1 and (connection_north=="none" or has_collision_wall) :  return true
		if new_pos_iso.x+size.x > room_size.x and (connection_south=="none" or has_collision_wall) : return true
		if new_pos_iso.y < 1 and (connection_east=="none" or has_collision_wall) :  return true
		if new_pos_iso.y+size.y > room_size.y and (connection_west=="none" or has_collision_wall) : return true
	else:
		if new_pos_iso.x < 1 or has_collision_wall :  return true
		if new_pos_iso.x+size.x > room_size.x or has_collision_wall : return true
		if new_pos_iso.y < 1 or has_collision_wall :  return true
		if new_pos_iso.y+size.y > room_size.y or has_collision_wall : return true		
	return false


# Detects volumetric collisions between objects.
# Returns detailed information about the intersecting object.
func check_intersection(id, pos_iso) :
	var has_intersect : bool = false
	if id in Mainglobal.scene_objects :
		for obj in Mainglobal.scene_objects :
			if id != obj :
				var object_a = Mainglobal.scene_objects[id]
				var object_b = Mainglobal.scene_objects[obj]
				has_intersect = Mainglobal.intersects(pos_iso, object_a["size"], object_b["pos"], object_b["size"])
				if has_intersect :
					var type : String = scene_objects[obj]["type"]
					if type.begins_with("step-") : return [true, obj,scene_objects[obj]["name"],scene_objects[obj]["type"],scene_objects[obj]["orientation"]]
					if type in ["gate","gate-down-loft"] : return [true, obj,scene_objects[obj]["name"],scene_objects[obj]["type"],scene_objects[obj]["target"],scene_objects[obj]["target_offset"]]
					if has_intersect and not scene_objects[obj].has("target") and not scene_objects[obj].has("orientation"): return [true, obj,scene_objects[obj]["name"],scene_objects[obj]["type"]]
					if has_intersect and scene_objects[obj].has("target"): return [true, obj,scene_objects[obj]["name"],scene_objects[obj]["type"],scene_objects[obj]["target"],scene_objects[obj]["target_pos"]]
				
	return [false,"","","",""]


# Detects vertical overlap with objects above.
# Used for stacking logic and vertical interactions.
func check_over_intersection(id, pos_iso, obj) :
	var has_intersect : bool = false
	if id != obj and Mainglobal.scene_objects[id]:
		var object_a = Mainglobal.scene_objects[id]
		var object_b = Mainglobal.scene_objects[obj]
		has_intersect = Mainglobal.intersects(pos_iso, object_a["size"], object_b["pos"], object_b["size"])
		if has_intersect :
			return [true, obj,scene_objects[obj]["name"],scene_objects[obj]["type"]]
	return [false,"","",""]

	
# Checks whether a portable object can be picked up.
# Detects intersection with portable objects only.
func check_for_pick_portable_object(id, pos_iso) :
	var has_intersect : bool = false
	for obj in Mainglobal.scene_objects :
		if id != obj :
			var object_a = Mainglobal.scene_objects[id]
			var object_b = Mainglobal.scene_objects[obj]
			has_intersect = Mainglobal.intersects(pos_iso, object_a["size"], object_b["pos"], object_b["size"])
			if has_intersect :
				var type : String = scene_objects[obj]["type"]
				if type == "portable" :
					if has_intersect and not scene_objects[obj].has("target") and not scene_objects[obj].has("orientation"): return [true, obj,scene_objects[obj]["name"],scene_objects[obj]["type"]]
	return [false,"","","",""]
	
	
# Checks whether an object can be dropped at a position.
# Prevents dropping on top of other objects.
func check_drop_intersection(pos_iso,size) :
	var has_intersect : bool = false
	for obj in Mainglobal.scene_objects :
		var object_b = Mainglobal.scene_objects[obj]
		has_intersect = Mainglobal.intersects(pos_iso, size, object_b["pos"], object_b["size"])
		if has_intersect : return true
	return false


# Checks whether an object is being dropped onto a gate.
# Prevents accidental blocking of doors or gates.
func check_drop_gate(pos_iso,size) :
	var has_intersect : bool = false
	for obj in Mainglobal.scene_objects :
		var object_b = Mainglobal.scene_objects[obj]
		has_intersect = Mainglobal.intersects(pos_iso, size, object_b["pos"], object_b["size"])
		if has_intersect :
			var type : String = scene_objects[obj]["type"]
			if type == "gate" : return true
	return false


# Converts a logical direction string into an isometric movement vector.
func get_vector_direction(direction : String) -> Vector3 :
	var variation : Vector3 = Vector3.ZERO
	if direction=="down" : variation = Vector3(1,0,0)
	if direction=="up" : variation = Vector3(-1,0,0)
	if direction=="left" : variation = Vector3(0,1,0)
	if direction=="right" : variation = Vector3(0,-1,0)
	if direction=="downleft" : variation = Vector3(1,1,0)
	if direction=="downright" : variation = Vector3(1,-1,0)
	if direction=="upleft" : variation = Vector3(-1,1,0)
	if direction=="upright" : variation = Vector3(-1,-1,0)
	if direction=="none" : variation = Vector3(0,0,0)
	if direction=="upper" : variation = Vector3(0,0,1)
	if direction=="downupper" : variation = Vector3(1,0,1)
	if direction=="upupper" : variation = Vector3(-1,0,1)
	if direction=="leftupper" : variation = Vector3(0,1,1)
	if direction=="rightupper" : variation = Vector3(0,-1,1)
	if direction=="upcarpet" : variation = Vector3(0,0,2)
	return(variation)
	

# Returns the inverse of a given movement direction.
func get_inverse_direction(direction : String) -> String :
	if direction=="down" : return "up"
	if direction=="up" : return "down"
	if direction=="left" : return "right"
	if direction=="right" : return "left"
	if direction=="downleft" : return "upright"
	if direction=="downright" : return "upleft"
	if direction=="upleft" : return "downright"
	if direction=="upright" : return "downleft"
	if direction=="none" : return "none"
	if direction=="upper" : return "upper"
	return ""


# Checks for solid tiles at an isometric position.
# Supports both TileMap layers and custom polygon-based walls.
func check_exists_tile_from_iso(pos: Vector3, origin_point: Vector2, _scale: Vector2, tile_level: int, type: String) -> bool:
	if tile_level<=0 : tile_level = 1
	var tilemaplayer = null
	if has_node("/root/Main/Room/RoomElements/Layers/Layer_" + type + "_" + str(tile_level)) :
		tilemaplayer = get_node("/root/Main/Room/RoomElements/Layers/Layer_" + type + "_" + str(tile_level))
	if tilemaplayer :
		var map: Vector2i = Vector2i(int(floor(pos.x/30)),int(floor(pos.y/30)))+tile_rr
		var source_id: int = tilemaplayer.get_cell_source_id(map)
		if source_id != -1 : return(true)
		
	if type == "wall" :
		var pos_screen = iso_to_screen(pos,origin_point,SCALE)
		var polygons = null
		if has_node("/root/Main/Room/RoomElements/Polygons") : 
			polygons = get_node("/root/Main/Room/RoomElements/Polygons")
		if polygons :
			for p in polygons.get_children() :
				if p.has_meta("type") and p.get_meta("type") == "wall" and pos.z >= p.get_meta("z_from") and pos.z <= p.get_meta("z_from") + p.get_meta("z_size") -1 :
					var poly_points = p.polygon
					var global_points = PackedVector2Array()
					for point in poly_points:
						global_points.append(p.to_global(point))
					pos_screen = iso_to_screen(Vector3(pos.x,pos.y,p.get_meta("z_from")),origin_point,SCALE)
						
					if Geometry2D.is_point_in_polygon(pos_screen, global_points):
						return true
	return false


# Detects void or hole tiles in the floor.
# Used to prevent movement over empty or falling areas.
func check_exists_void_from_iso(pos: Vector3, _origin: Vector2, _scale: Vector2) -> bool:
	var tilemaplayer: TileMapLayer = get_node("/root/Main/Room/RoomElements/Layers/Layer_floor_1")
	if tilemaplayer :
		var map: Vector2i = Vector2i(int(floor(pos.x/30)),int(floor(pos.y/30)))+tile_rr
		var source_id: int = tilemaplayer.get_cell_source_id(map)
		if source_id != -1 : 
			var tileset: TileSet = tilemaplayer.tile_set
			var source := tileset.get_source(source_id)
			if source is TileSetAtlasSource:
				var texture: Texture2D = source.texture
				if texture.resource_path.contains("void.png") or texture.resource_path.contains("void-2.png") or texture.resource_path.contains("blank-semi.png")  or texture.resource_path.contains("blank.png"):
					return(true)
	return false


 # Applies gravity to an object.
# Handles falling, floor detection, collision damage, and special effects.
func gravity(obj) :
	var has_floor = null
	var has_intersect = null
	#var has_intersect_step = null
	if not Mainglobal.scene_objects[obj]["is_jumping"] :
		var new_pos_iso = scene_objects[obj]["pos"] + Vector3(0,0,-1)
		var new_pos_screen = iso_to_screen(new_pos_iso,origin,SCALE)
		has_intersect = check_intersection(obj, new_pos_iso)
		#has_intersect_step = check_intersection(obj,new_pos_iso+Vector3(0,0,-5))
		if int(scene_objects[obj]["pos"].z)%20 == 0 :
			has_floor = Mainglobal.check_exists_tile_from_iso(new_pos_iso,origin,SCALE,int(scene_objects[obj]["pos"].z/20)+1,"floor")
			if not has_floor :
				pass
		
		var has_polygon_floor=in_floor_polygon(new_pos_iso,new_pos_screen)
		
		if has_intersect[0] and Mainglobal.scene_objects[obj]["type"] == "portable" and Mainglobal.scene_objects[obj]["subtype"] == "crystal" :
			var type = Mainglobal.scene_objects[has_intersect[1]]["type"]
			if type in ["monk","guard","pirate","wolf","ogre","demon","blob","bubble","twister","skel"] :
				lightning(Mainglobal.scene_objects[has_intersect[1]]["node"],Mainglobal.non_fixed_objects_repository[Mainglobal.scene_objects[obj]["name"]])

		if has_intersect[0] or has_floor or has_polygon_floor :
			scene_objects[obj]["is_falling"] = false
			if (scene_objects[obj]["name"] == "Player" and (begins_with_any(has_intersect[2], ["twister","skel","demon","pirate","guard-","wolf","ogre","monk","torch","venon","fire","tableonfire","blob"]))) or (has_intersect[2] == "Player" and scene_objects[obj]["type"] in ["monk","guard","pirate","wolf","ogre","demon","blob","bubble","twister","skel"]):
				if player_last_damage_below == 0 : player_last_damage_below = Time.get_ticks_msec()
				if Time.get_ticks_msec() - player_last_damage_below > 200 :
					Mainglobal.update_life_player(-1)
					player_last_damage_below = 0
		else:
			scene_objects[obj]["pos"] = new_pos_iso
			Mainglobal.scene_objects[obj]["is_falling"] = true
		
	#update_object_z_index(obj)

	return(has_intersect)


# Checks whether a position belongs to a floor polygon.
# Allows complex floor shapes beyond tile-based floors.
func in_floor_polygon(pos_iso,pos_screen) :
	var polygons = null
	if has_node("/root/Main/Room/RoomElements/Polygons") : 
		polygons = get_node("/root/Main/Room/RoomElements/Polygons")
	var has_polygon_floor = false
	if polygons :
		for p in polygons.get_children() :
			if p.has_meta("type") and p.get_meta("type") == "floor" and p.get_meta("z") == pos_iso.z :
				var poly_points = p.polygon
				var global_points = PackedVector2Array()
				for point in poly_points:
					global_points.append(p.to_global(point))
				if Geometry2D.is_point_in_polygon(pos_screen, global_points):
					has_polygon_floor = true
	return has_polygon_floor
	

# Generates an oval polygon.
# Used primarily for automatic shadow occluders.
func create_oval_polygon(radius_x: float, radius_y: float, points: int = 20) -> PackedVector2Array:
	var verts = PackedVector2Array()
	for i in points:
		var angle = TAU * i / points
		var x = radius_x * cos(angle)
		var y = radius_y * sin(angle)
		verts.append(Vector2(x, y))
	return verts


# Updates the player's life value.
# Applies limits, dev mode overrides, and UI feedback.
func update_life_player(value) :
	life_player += value
	if life_player > 99 : life_player = 99
	if life_player < 0 : life_player = 0
	if Mainglobal.active_dev_mode : life_player = 99
	show_temporary_message("",0.1)


# Updates background music based on the current room.
# Selects tracks by room name prefix and applies smooth transitions.
func update_music_from_room(room_name: String):
	# Si la música está desactivada, detener todo y salir
	if not setup_sound_music:
		music_a.stop()
		music_b.stop()
		current_stream = null
		return

	var found_stream: AudioStream = null

	# Buscar coincidencia por prefijo
	for prefix in area_music.keys():
		if room_name.begins_with(prefix):
			found_stream = area_music[prefix]

	# Si no hay coincidencia, usar tema genérico
	if found_stream == null:
		found_stream = generic_theme

	# Si el tema ya está sonando, no hacer nada
	if found_stream == current_stream:
		return

	# Guardar nuevo tema y reproducir con crossfade
	current_stream = found_stream
	play_music(found_stream)


# Plays music using crossfading between two audio players.
# Prevents abrupt audio transitions.
func play_music(new_stream: AudioStream):
	var fade_time := 0.5
	if active_player == 1:
		music_a.stop()
		music_b.stream = new_stream
		music_b.volume_db = -80
		music_b.play()

		var tween = create_tween()
		tween.tween_property(music_a, "volume_db", -80, fade_time)
		tween.parallel().tween_property(music_b, "volume_db", 0, fade_time)

		active_player = 2
	else:
		music_b.stop()
		music_a.stream = new_stream
		music_a.volume_db = -80
		music_a.play()
		var tween = create_tween()
		tween.tween_property(music_b, "volume_db", -80, fade_time)
		tween.parallel().tween_property(music_a, "volume_db", 0, fade_time)

		active_player = 1

# Updates the inventory slot sprite.
# Assigns the correct texture based on the picked object.
func set_inventory_sprite(inv_slot,picked_object) :
	var inv_sprite = get_node("/root/Main/UI/InventoryLayer/sprite_inv"+str(inv_slot))
	#if picked_object["sprite"] == "res://assets/objects/key.png" :
		#inv_sprite.texture = load("res://assets/objects/key-white.png")
	if picked_object["subtype"] == "crystal" and picked_object["status"] == "active" :
		inv_sprite.texture = load("res://assets/objects/crystal-003.png")
	else :
		inv_sprite.texture = load(picked_object["sprite"])

# Executes the lightning effect.
# Applies visual flashes, sound effects, object destruction,
# character removal, and door unlocking logic.
func lightning(obj_character, obj_object) :

	var room_elements = get_node("/root/Main/Room/RoomElements")
	if room_elements.has_meta("light") :
		room_elements.modulate = Color(1, 1, 1, 1.0)
		player.modulate = Color(1, 1, 1, 1.0)
	
	var object_path = "/root/Main/Room/RoomElements/NonFixedObjects/" + obj_object["uid"]
	var object_node = get_node_or_null(object_path)
	var door = "none"
	var char_name = Mainglobal.scene_objects[obj_character.get_instance_id()]["name"]
	var flash_character = obj_character.get_node("flash")
	var flash_object = object_node.get_node("flash")

	if Mainglobal.characters_repository[char_name]["disabled_door"] != "none" :
		door = Mainglobal.characters_repository[char_name]["disabled_door"]

	if Mainglobal.setup_sound_fx and not get_node("/root/Main/light").playing: get_node("/root/Main/light").play()

	object_node.get_node("AutoOccluder").visible = false

	var tween = get_tree().create_tween()
	tween.tween_property(flash_character, "energy", 3.0, 0.1)
	tween.parallel().tween_property(flash_object, "energy", 10.0, 0.1)
	await tween.finished

	if is_instance_valid(object_node): object_node.queue_free()
	if is_instance_valid(obj_character): obj_character.queue_free()

	if room_elements.has_meta("light") :
		var l = room_elements.get_meta("light")
		room_elements.modulate = Color(l, l, l, 1.0)
		player.modulate = Color(l, l, l, 1.0)


	Mainglobal.non_fixed_objects_repository[obj_object["uid"]]["room"] = "none"
	Mainglobal.characters_repository[char_name]["room"] = "none"

	if door != "none" :
		for s_object in Mainglobal.scene_objects :
			if Mainglobal.scene_objects[s_object]["name"] == door :
				Mainglobal.scene_objects[s_object]["status"] = "none"


func begins_with_any(text: String, prefixes: Array) -> bool:
	for p in prefixes:
		if text.begins_with(p):
			return true
	return false
