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
var self_id = null
var push_direction = ""
var move_direction_x = ""
var move_direction_y = ""
var step_status = 0
var frame_counter = 0
var frame_counter_bis = 0
var on_steps = false
var just_started = true
var passive_move : Vector3 = Vector3.ZERO

func _ready() :
	self_id = self.get_instance_id()
	self.play("bat")
	just_started = true
	randomize()

func _physics_process(_delta: float) -> void:
	obj = Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]
	var obj_scene = Mainglobal.scene_objects[self_id]
	Mainglobal.update_object_z_index(self_id)
	
	if obj["pos"].z < -20 :
		self.queue_free()
		Mainglobal.characters_repository[Mainglobal.scene_objects[self.get_instance_id()]["name"]]["room"] = "none"

	frame_counter += 1
	
	if frame_counter > 2 :
		frame_counter = 0
		return
		
	var prev_pos_iso = obj_scene["pos"]
	var new_pos_iso = prev_pos_iso
	
	if not Mainglobal.time_stoped :
		new_pos_iso += Vector3(1,0,0.25)
	
	if Mainglobal.setup_sound_fx and not $Flap.playing: $Flap.play()
	
		
	Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]["pos"]=Mainglobal.scene_objects[self_id]["pos"]
	
	var reached_limit : bool = Mainglobal.check_reached_limit(new_pos_iso,obj_scene["size"], false,false)

	if reached_limit : self.queue_free()
	Mainglobal.scene_objects[self_id]["pos"] = new_pos_iso
	if prev_pos_iso != Mainglobal.scene_objects[self_id]["pos"] : 
		var pos_iso_center = Mainglobal.iso_object_center(Mainglobal.scene_objects[self_id]["pos"],obj_scene["size"])
		var pos_screen = Mainglobal.iso_to_screen(pos_iso_center, Mainglobal.origin, Mainglobal.SCALE)
		global_position = pos_screen


func load_data(uid_object) :
	obj = Mainglobal.characters_repository[uid_object]
	Mainglobal.load_data(uid_object,obj,sprite)

func _exit_tree() :
	$Flap.stop()
	Mainglobal.scene_objects.erase(self.get_instance_id())
