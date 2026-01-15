extends CanvasLayer

@onready var fade_rect := $FadeRect

var fade_duration := 2.0
var current_tween: Tween
var time_wait = 0
var scene_name = null

func _ready():
	scene_name = get_tree().current_scene.scene_file_path.get_file()
	fade_rect.modulate.a = 1.0
	if Mainglobal.setup_sound_music :
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"),0)
		$chapter_music.play()
	if scene_name in ["chapter-1.tscn"] : Mainglobal.current_chapter = 1
	if scene_name in ["chapter-2.tscn","chapter-2-intro.tscn"] : Mainglobal.current_chapter = 2
	if scene_name in ["chapter-2-intro.tscn"] : Mainglobal.current_chapter = 0
	if scene_name in ["chapter-3.tscn","chapter-final.tscn"] : Mainglobal.current_chapter = 3
	fade_in()

func _physics_process(_delta: float) -> void :
	if scene_name in ["chapter-1.tscn","chapter-2.tscn","chapter-3.tscn","chapter-2-intro.tscn"] :
		time_wait += 1
		if time_wait > 5000 :
			time_wait = 0
			fade_out()
	elif get_tree().current_scene.scene_file_path.get_file() in ["chapter-final.tscn"] :
		pass

func fade_in():
	current_tween = create_tween()
	current_tween.tween_property(fade_rect, "modulate:a", 0.0, fade_duration)
	current_tween.connect("finished", Callable(self, "_on_fade_in_finished"))

func _input(event):
	if (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) :
		fade_out()

func fade_out():
	current_tween = create_tween()
	current_tween.tween_property(fade_rect, "modulate:a", 1.0, fade_duration)
	current_tween.connect("finished", Callable(self, "_on_fade_out_finished"))

func _on_fade_out_finished():
	await get_tree().process_frame  # Espera 1 frame para asegurar que el negro se quede
	$chapter_music.stop()
	if scene_name in ["chapter-1.tscn","chapter-2.tscn","chapter-3.tscn"] :
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	elif scene_name in ["chapter-2-intro.tscn"] :
		get_tree().change_scene_to_file("res://scenes/chapter-2.tscn")
	elif scene_name in ["chapter-final.tscn"] :
		get_tree().change_scene_to_file("res://scenes/instructions.tscn")
