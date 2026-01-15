extends Node2D

@export var interval := 3.0
@export var probability := 0.2

var timer := 0.0
var spectrum : AudioEffectSpectrumAnalyzerInstance
var playing_flash = false

func _ready():
	var bus_index := AudioServer.get_bus_index("RainBus")
	spectrum = AudioServer.get_bus_effect_instance(bus_index, 0)

func _process(delta):

	if spectrum == null:
		return

	var energy := spectrum.get_magnitude_for_frequency_range(20, 220).length()

	timer += delta
	#if timer >= interval:
		#timer = 0.0
		#try_flash()
	
	if energy>=0.01 and not playing_flash : 
		timer = 0.0
		flash()
	elif timer>=interval and not playing_flash:
		var r := randf()
		timer = 0.0
		if r <= probability :
			flash()
	else :
		return


func flash():
	playing_flash = true
	var original_color = $Lightnin.modulate
	var flash_duration := randf_range(0.25, 0.5)
	var intensity = randf_range(85,89)
	$Lightnin.modulate = Color(1*intensity, 1*intensity, 1*intensity, 0.5)
	var tween3 := get_tree().create_tween()
	tween3.tween_property($Lightnin, "modulate", original_color, flash_duration)
	await tween3.finished
	
	flash_duration = randf_range(0.25, 0.5)
	intensity = randf_range(10,20)
	$Lightnin.modulate = Color(1*intensity, 1*intensity, 1*intensity, 0.75)
	var tween := get_tree().create_tween()
	tween.tween_property($Lightnin, "modulate", original_color, flash_duration)
	await tween.finished
	
	flash_duration = randf_range(0.15, 0.25)
	intensity = randf_range(3,5)
	$Lightnin.modulate = Color(1*intensity, 1*intensity, 1*intensity, 0.5)
	var tween2 := get_tree().create_tween()
	tween2.tween_property($Lightnin, "modulate", original_color, flash_duration)
	await tween2.finished
	$Lightnin.modulate = original_color
	playing_flash = false
	
