extends CanvasLayer

@onready var fade_rect := $FadeRect

var fade_duration := 2.0
var current_tween: Tween

func _ready():
	if Mainglobal.liberated_wizard and "crown" in Mainglobal.set_inventory : $message_result.text = "You have succeeded\nin your quest..."
	if Mainglobal.liberated_wizard : $message_wizard.text = "The Wizard is Free..."
	if "crown" in Mainglobal.set_inventory : $message_kingdom.text = "The Kingdom of Fairlight\nhas been restored..."
	fade_rect.modulate.a = 1.0
	fade_in()
	

func fade_in():
	current_tween = create_tween()
	current_tween.tween_property(fade_rect, "modulate:a", 0.0, fade_duration)
	current_tween.connect("finished", Callable(self, "_on_fade_in_finished"))

func _input(event):
	if (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) :
		fade_out()

func fade_out():
	current_tween = create_tween()
	current_tween.tween_property(fade_rect, "modulate:a", 1, fade_duration)
	current_tween.connect("finished", Callable(self, "_on_fade_out_finished"))

func _on_fade_out_finished():
	await get_tree().process_frame  # Espera 1 frame para asegurar que el negro se quede
	get_tree().change_scene_to_file("res://scenes/instructions.tscn")
