extends CanvasLayer

@onready var fade_rect := $FadeRect

var fade_duration := 2.0
var current_tween: Tween


func _ready():
	if Mainglobal.setup_sound_music :
		$music/music_off.visible = false
		$Intro_Music.play()
	if Mainglobal.setup_sound_fx : $sound/sound_off.visible = false
	fade_rect.modulate.a = 1.0
	Input.set_mouse_mode(Input.MouseMode.MOUSE_MODE_VISIBLE)
	var sword_cursor := load("res://assets/UI/sword.png")
	Input.set_custom_mouse_cursor(sword_cursor, Input.CursorShape.CURSOR_ARROW, Vector2(63,15))
	Input.set_custom_mouse_cursor(sword_cursor, Input.CursorShape.CURSOR_POINTING_HAND, Vector2(63,15))
	
	
	for i in range(1,4) :
		if FileAccess.file_exists("fairlight-savegame-"+str(i)+".dat"):
			var file = FileAccess.open("fairlight-savegame-"+str(i)+".dat", FileAccess.READ)
			var data = file.get_var()
			file.close()
			if data.has("life_player") and data.has("r_room") and data.has("pos") and data.has("liberated_wizard") : 
				get_node("/root/SplashScreen/ColorRect_"+str(i)+"/message_new_"+str(i)).visible = false
				get_node("/root/SplashScreen/ColorRect_"+str(i)+"/message_load_"+str(i)).visible = true
				#Mainglobal.life_player = data["life_player"]
				#Mainglobal.visited_rooms = data["visited_rooms"]
				get_node("/root/SplashScreen/ColorRect_"+str(i)+"/message_load_info_"+str(i)).text = "Life: "+str(int(data["life_player"]))+"% / Explored: "+ str(int(data["visited_rooms"].size()*100/205))+"%"
				get_node("/root/SplashScreen/ColorRect_"+str(i)+"/message_load_info_"+str(i)).visible = true
				get_node("/root/SplashScreen/ColorRect_"+str(i)+"/message_delete_icon_"+str(i)).visible = true
			else :
				get_node("/root/SplashScreen/ColorRect_"+str(i)+"/message_new_"+str(i)).visible = true
				get_node("/root/SplashScreen/ColorRect_"+str(i)+"/message_load_"+str(i)).visible = false
				get_node("/root/SplashScreen/ColorRect_"+str(i)+"/message_load_info_"+str(i)).visible = false
				get_node("/root/SplashScreen/ColorRect_"+str(i)+"/message_delete_icon_"+str(i)).visible = false
				
	fade_in()

func _exit_tree():
	Input.set_custom_mouse_cursor(null)
	Input.set_mouse_mode(Input.MouseMode.MOUSE_MODE_HIDDEN)

func fade_in():
	current_tween = create_tween()
	current_tween.tween_property(fade_rect, "modulate:a", 0.0, fade_duration)
	current_tween.connect("finished", Callable(self, "_on_fade_in_finished"))

func fade_out():
	Input.set_custom_mouse_cursor(null)
	Input.set_mouse_mode(Input.MouseMode.MOUSE_MODE_HIDDEN)
	Input.set_mouse_mode(Input.MouseMode.MOUSE_MODE_CAPTURED)
	current_tween = create_tween()
	current_tween.tween_property(fade_rect, "modulate:a", 1.0, fade_duration)
	current_tween.connect("finished", Callable(self, "_on_fade_out_finished"))

func _on_fade_out_finished():
	await get_tree().process_frame  # Espera 1 frame para asegurar que el negro se quede
	if Mainglobal.action_from_instructions == "load" :
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	if Mainglobal.action_from_instructions == "new" :
		get_tree().change_scene_to_file("res://scenes/chapter-1.tscn")


func _on_color_rect_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		if Mainglobal.setup_sound_fx : $Click.play()
		Mainglobal.slot_game_active = 1
		if $ColorRect_1/message_new_1.visible : Mainglobal.action_from_instructions = "new"
		if not $ColorRect_1/message_new_1.visible : Mainglobal.action_from_instructions = "load"
		fade_out()

func _on_color_rect_2_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		if Mainglobal.setup_sound_fx : $Click.play()
		Mainglobal.slot_game_active = 2
		if $ColorRect_2/message_new_2.visible : Mainglobal.action_from_instructions = "new"
		if not $ColorRect_2/message_new_2.visible : Mainglobal.action_from_instructions = "load"
		fade_out()

func _on_color_rect_3_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		if Mainglobal.setup_sound_fx : $Click.play()
		Mainglobal.slot_game_active = 3
		if $ColorRect_3/message_new_3.visible : Mainglobal.action_from_instructions = "new"
		if not $ColorRect_3/message_new_3.visible : Mainglobal.action_from_instructions = "load"
		fade_out()

func _on_music_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		if Mainglobal.setup_sound_fx : $Click.play()
		if Mainglobal.setup_sound_music :
			$music/music_off.visible = true
			Mainglobal.setup_sound_music = false
			$Intro_Music.stop()
		else :
			$music/music_off.visible = false
			Mainglobal.setup_sound_music = true
			$Intro_Music.play()


func _on_sound_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		if Mainglobal.setup_sound_fx : $Click.play()
		if Mainglobal.setup_sound_fx :
			$sound/sound_off.visible = true
			Mainglobal.setup_sound_fx = false
		else :
			$sound/sound_off.visible = false
			Mainglobal.setup_sound_fx = true


func _on_message_delete_icon_1_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		show_delete_opciones(1)

func _on_message_delete_icon_2_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		show_delete_opciones(2)

func _on_message_delete_icon_3_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		show_delete_opciones(3)

func _on_message_delete_no_1_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		hide_delete_opciones(1)

func _on_message_delete_no_2_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		hide_delete_opciones(2)

func _on_message_delete_no_3_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		hide_delete_opciones(3)

func _on_message_delete_yes_1_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		delete_file(1)

func _on_message_delete_yes_2_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		delete_file(2)

func _on_message_delete_yes_3_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		delete_file(3)

func show_delete_opciones(slot) :
	if Mainglobal.setup_sound_fx : $Click.play()
	get_node("/root/SplashScreen/ColorRect_"+str(slot)+"/message_load_"+str(slot)).visible = false
	get_node("/root/SplashScreen/ColorRect_"+str(slot)+"/message_load_info_"+str(slot)).visible = false
	get_node("/root/SplashScreen/ColorRect_"+str(slot)+"/message_delete_icon_"+str(slot)).visible = false	
	get_node("/root/SplashScreen/ColorRect_"+str(slot)+"/message_delete_"+str(slot)).visible = true	
	get_node("/root/SplashScreen/ColorRect_"+str(slot)+"/message_delete_yes_"+str(slot)).visible = true	
	get_node("/root/SplashScreen/ColorRect_"+str(slot)+"/message_delete_no_"+str(slot)).visible = true	

func hide_delete_opciones(slot) :
	if Mainglobal.setup_sound_fx : $Click.play()
	get_node("/root/SplashScreen/ColorRect_"+str(slot)+"/message_load_"+str(slot)).visible = true
	get_node("/root/SplashScreen/ColorRect_"+str(slot)+"/message_load_info_"+str(slot)).visible = true
	get_node("/root/SplashScreen/ColorRect_"+str(slot)+"/message_delete_icon_"+str(slot)).visible = true
	get_node("/root/SplashScreen/ColorRect_"+str(slot)+"/message_delete_"+str(slot)).visible = false
	get_node("/root/SplashScreen/ColorRect_"+str(slot)+"/message_delete_yes_"+str(slot)).visible = false
	get_node("/root/SplashScreen/ColorRect_"+str(slot)+"/message_delete_no_"+str(slot)).visible = false

func delete_file(slot) :
	if Mainglobal.setup_sound_fx : $Click.play()
	DirAccess.remove_absolute("fairlight-savegame-"+str(slot)+".dat")
	get_node("/root/SplashScreen/ColorRect_"+str(slot)+"/message_delete_"+str(slot)).visible = false
	get_node("/root/SplashScreen/ColorRect_"+str(slot)+"/message_delete_yes_"+str(slot)).visible = false
	get_node("/root/SplashScreen/ColorRect_"+str(slot)+"/message_delete_no_"+str(slot)).visible = false
	get_node("/root/SplashScreen/ColorRect_"+str(slot)+"/message_new_"+str(slot)).visible = true
		

func load_saved_game(slot) : 
	if Mainglobal.setup_sound_fx : $Click.play()
	if FileAccess.file_exists("fairlight-savegame-"+str(slot)+".dat"):
		var file = FileAccess.open("fairlight-savegame-"+str(slot)+".dat", FileAccess.READ)
		var text = file.get_as_text()
		var data = JSON.parse_string(text)
		file.close()
		if data.has("life_player") and data.has("r_room") and data.has("pos") and data.has("liberated_wizard") : 
			Mainglobal.life_player = data["life_player"]
			Mainglobal.visited_rooms = data["visited_rooms"]
			Mainglobal.liberated_wizard = data["liberated_wizard"]
			Mainglobal.set_inventory = data["set_inventory"]
			Mainglobal.visited_rooms = data["visited_rooms"]
			Mainglobal.non_fixed_objects_repository = data["non_fixed_objects_repository"]
			Mainglobal.characters_repository = data["characters_repository"]
			Mainglobal.player_is_woman = data["player_is_woman"]
			Mainglobal.player_on_carpet = data["player_on_carpet"]


func _on_color_rect_1_mouse_entered() -> void:
	$ColorRect_1/message_new_1.add_theme_color_override("font_color",Color("005a92"))
	$ColorRect_1/message_load_1.add_theme_color_override("font_color",Color("005a92"))
	$ColorRect_1/message_load_info_1.add_theme_color_override("font_color",Color("005a92"))
	$ColorRect_1.set_default_cursor_shape(2)

func _on_color_rect_1_mouse_exited() -> void:
	$ColorRect_1/message_new_1.add_theme_color_override("font_color",Color("ffffff"))
	$ColorRect_1/message_load_1.add_theme_color_override("font_color",Color("ffffff"))
	$ColorRect_1/message_load_info_1.add_theme_color_override("font_color",Color("ffffff"))
	$ColorRect_1.set_default_cursor_shape(0)

func _on_message_delete_icon_1_mouse_entered() -> void:
	$ColorRect_1/message_delete_icon_1.add_theme_color_override("font_color",Color("005a92"))
	$ColorRect_1/message_delete_icon_1.set_default_cursor_shape(2)
	
func _on_message_delete_icon_1_mouse_exited() -> void:
	$ColorRect_1/message_delete_icon_1.add_theme_color_override("font_color",Color("ffffff"))
	$ColorRect_1/message_delete_icon_1.set_default_cursor_shape(0)

func _on_message_delete_yes_1_mouse_entered() -> void:
	$ColorRect_1/message_delete_yes_1.add_theme_color_override("font_color",Color("005a92"))
	$ColorRect_1/message_delete_yes_1.set_default_cursor_shape(2)

func _on_message_delete_yes_1_mouse_exited() -> void:
	$ColorRect_1/message_delete_yes_1.add_theme_color_override("font_color",Color("ffffff"))
	$ColorRect_1/message_delete_yes_1.set_default_cursor_shape(0)

func _on_message_delete_no_1_mouse_entered() -> void:
	$ColorRect_1/message_delete_no_1.add_theme_color_override("font_color",Color("005a92"))
	$ColorRect_1/message_delete_no_1.set_default_cursor_shape(2)

func _on_message_delete_no_1_mouse_exited() -> void:
	$ColorRect_1/message_delete_no_1.add_theme_color_override("font_color",Color("ffffff"))
	$ColorRect_1/message_delete_no_1.set_default_cursor_shape(0)



func _on_color_rect_2_mouse_entered() -> void:
	$ColorRect_2/message_new_2.add_theme_color_override("font_color",Color("005a92"))
	$ColorRect_2/message_load_2.add_theme_color_override("font_color",Color("005a92"))
	$ColorRect_2/message_load_info_2.add_theme_color_override("font_color",Color("005a92"))
	$ColorRect_2.set_default_cursor_shape(2)

func _on_color_rect_2_mouse_exited() -> void:
	$ColorRect_2/message_new_2.add_theme_color_override("font_color",Color("ffffff"))
	$ColorRect_2/message_load_2.add_theme_color_override("font_color",Color("ffffff"))
	$ColorRect_2/message_load_info_2.add_theme_color_override("font_color",Color("ffffff"))
	$ColorRect_2.set_default_cursor_shape(0)

func _on_message_delete_icon_2_mouse_entered() -> void:
	$ColorRect_2/message_delete_icon_2.add_theme_color_override("font_color",Color("005a92"))
	$ColorRect_2/message_delete_icon_2.set_default_cursor_shape(2)
	
func _on_message_delete_icon_2_mouse_exited() -> void:
	$ColorRect_2/message_delete_icon_2.add_theme_color_override("font_color",Color("ffffff"))
	$ColorRect_2/message_delete_icon_2.set_default_cursor_shape(0)

func _on_message_delete_yes_2_mouse_entered() -> void:
	$ColorRect_2/message_delete_yes_2.add_theme_color_override("font_color",Color("005a92"))
	$ColorRect_2/message_delete_yes_2.set_default_cursor_shape(2)

func _on_message_delete_yes_2_mouse_exited() -> void:
	$ColorRect_2/message_delete_yes_2.add_theme_color_override("font_color",Color("ffffff"))
	$ColorRect_2/message_delete_yes_2.set_default_cursor_shape(0)

func _on_message_delete_no_2_mouse_entered() -> void:
	$ColorRect_2/message_delete_no_2.add_theme_color_override("font_color",Color("005a92"))
	$ColorRect_2/message_delete_no_2.set_default_cursor_shape(2)

func _on_message_delete_no_2_mouse_exited() -> void:
	$ColorRect_2/message_delete_no_2.add_theme_color_override("font_color",Color("ffffff"))
	$ColorRect_2/message_delete_no_2.set_default_cursor_shape(0)


func _on_color_rect_3_mouse_entered() -> void:
	$ColorRect_3/message_new_3.add_theme_color_override("font_color",Color("005a92"))
	$ColorRect_3/message_load_3.add_theme_color_override("font_color",Color("005a92"))
	$ColorRect_3/message_load_info_3.add_theme_color_override("font_color",Color("005a92"))
	$ColorRect_3.set_default_cursor_shape(2)

func _on_color_rect_3_mouse_exited() -> void:
	$ColorRect_3/message_new_3.add_theme_color_override("font_color",Color("ffffff"))
	$ColorRect_3/message_load_3.add_theme_color_override("font_color",Color("ffffff"))
	$ColorRect_3/message_load_info_3.add_theme_color_override("font_color",Color("ffffff"))
	$ColorRect_3.set_default_cursor_shape(0)

func _on_message_delete_icon_3_mouse_entered() -> void:
	$ColorRect_3/message_delete_icon_3.add_theme_color_override("font_color",Color("005a92"))
	$ColorRect_3/message_delete_icon_3.set_default_cursor_shape(2)
	
func _on_message_delete_icon_3_mouse_exited() -> void:
	$ColorRect_3/message_delete_icon_3.add_theme_color_override("font_color",Color("ffffff"))
	$ColorRect_3/message_delete_icon_3.set_default_cursor_shape(0)

func _on_message_delete_yes_3_mouse_entered() -> void:
	$ColorRect_3/message_delete_yes_3.add_theme_color_override("font_color",Color("005a92"))
	$ColorRect_3/message_delete_yes_3.set_default_cursor_shape(2)

func _on_message_delete_yes_3_mouse_exited() -> void:
	$ColorRect_3/message_delete_yes_3.add_theme_color_override("font_color",Color("ffffff"))
	$ColorRect_3/message_delete_yes_3.set_default_cursor_shape(0)

func _on_message_delete_no_3_mouse_entered() -> void:
	$ColorRect_3/message_delete_no_3.add_theme_color_override("font_color",Color("005a92"))
	$ColorRect_3/message_delete_no_3.set_default_cursor_shape(2)

func _on_message_delete_no_3_mouse_exited() -> void:
	$ColorRect_3/message_delete_no_3.add_theme_color_override("font_color",Color("ffffff"))
	$ColorRect_3/message_delete_no_3.set_default_cursor_shape(0)

#func _on_music_mouse_entered() -> void:
	#$music.add_theme_color_override("font_color",Color("005a92"))
	#$music.set_default_cursor_shape(2)
#
#func _on_music_mouse_exited() -> void:
	#$music.add_theme_color_override("font_color",Color("ffffff"))
	#$music.set_default_cursor_shape(0)
#
#func _on_sound_mouse_entered() -> void:
	#$sound.add_theme_color_override("font_color",Color("005a92"))
	#$sound.set_default_cursor_shape(2)
#
#func _on_sound_mouse_exited() -> void:
	#$sound.add_theme_color_override("font_color",Color("ffffff"))
	#$sound.set_default_cursor_shape(0)
