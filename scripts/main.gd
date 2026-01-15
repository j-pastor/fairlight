extends Node2D


func _ready() -> void:
	randomize()

	Mainglobal.music_a = $/root/Main/music_player_a
	Mainglobal.music_b = $/root/Main/music_player_b

	#var initial_room_name := "z-forest-door-3"
	#var initial_player_position := Vector3(90,90,4)

	var initial_room_name := "yard"
	var initial_player_position := Vector3(100,140,0)
	
	if Mainglobal.current_chapter == 1 and Mainglobal.action_from_instructions != "load":
		Mainglobal.set_inventory = ["","","","",""]
		Mainglobal.characters_repository.clear()
		Mainglobal.non_fixed_objects_repository.clear()
	
	if Mainglobal.current_chapter == 2 and Mainglobal.action_from_instructions != "load":
		initial_room_name = "z-avars-entry"
		initial_player_position = Vector3(70,130,0)
		var i = 0
		for inv in Mainglobal.set_inventory :
			if inv in ["crown","book-light"] : Mainglobal.set_inventory[i] = ""
			if Mainglobal.set_inventory[i] != "" : Mainglobal.set_inventory_sprite(i+1,Mainglobal.non_fixed_objects_repository[inv])
			i += 1

	if Mainglobal.current_chapter == 3 :
		initial_room_name = "x-tower-entry"
		initial_player_position = Vector3(80,80,0)
		var i = 0
		for inv in Mainglobal.set_inventory :
			i += 1
			if inv != "" : Mainglobal.set_inventory_sprite(i,Mainglobal.non_fixed_objects_repository[inv])
	
	self.scale = Mainglobal.SCALE
	get_node("/root/Main/UI2/CanvasLayer2/Control/Frame/message").text=""
	
	Mainglobal.r_name  = ""
	Mainglobal.p_r_name = ""
	Mainglobal.current_room = null
	Mainglobal.scene_objects.clear()
	# Mainglobal.non_fixed_objects_repository.clear()
	# Mainglobal.characters_repository.clear()
	Mainglobal.visited_rooms.clear()
	Mainglobal.active_inv = 1
	# Mainglobal.set_inventory = ["","","","",""]
	Mainglobal.life_player = 99
	Mainglobal.player_last_damage_below = 0
	Mainglobal.time_stoped = false
	Mainglobal.liberated_wizard = false
	Mainglobal.active_player = 1
	Mainglobal.current_stream = null
	
	if Mainglobal.action_from_instructions == "load" :
		Mainglobal.action_from_instructions = ""
		if FileAccess.file_exists("fairlight-savegame-"+str(Mainglobal.slot_game_active)+".dat"):
			var file = FileAccess.open("fairlight-savegame-"+str(Mainglobal.slot_game_active)+".dat", FileAccess.READ)
			var data = file.get_var()
			if data.has("life_player") and data.has("r_room") and data.has("pos") and data.has("liberated_wizard") : 
				Mainglobal.life_player = data["life_player"]
				Mainglobal.liberated_wizard = data["liberated_wizard"]
				Mainglobal.set_inventory = data["set_inventory"]
				initial_room_name = data["r_room"]
				initial_player_position = data["pos"]
				Mainglobal.visited_rooms = data["visited_rooms"]
				Mainglobal.non_fixed_objects_repository = data["non_fixed_objects_repository"]
				Mainglobal.characters_repository = data["characters_repository"]
				Mainglobal.time_stoped = data["time_stoped"]
				Mainglobal.active_inv = data["active_inv"]
				Mainglobal.player_is_woman = data["player_is_woman"]
				Mainglobal.player_on_carpet = data["player_on_carpet"]

		
			var i = 0
			for inv in Mainglobal.set_inventory :
				i += 1
				if inv != "" : Mainglobal.set_inventory_sprite(i,Mainglobal.non_fixed_objects_repository[inv])


	Mainglobal.load_room(initial_room_name, initial_player_position)
	Mainglobal.set_active_inv()
	Mainglobal.show_temporary_message("99",0.5)
