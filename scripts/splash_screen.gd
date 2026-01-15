extends CanvasLayer

@onready var fade_rect := $FadeRect


var fade_duration := 2.0
var current_tween: Tween
var time_wait = 0

func _ready():
	fade_rect.modulate.a = 1.0
	fade_in()
	Input.set_custom_mouse_cursor(null, Input.CursorShape.CURSOR_ARROW)
	Input.set_mouse_mode(Input.MouseMode.MOUSE_MODE_HIDDEN)

func _physics_process(_delta: float) -> void :
	time_wait += 1
	if time_wait > 500 :
		time_wait = 0
		fade_out()


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
	get_tree().change_scene_to_file("res://scenes/instructions.tscn")
