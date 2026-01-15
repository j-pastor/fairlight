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
var move_direction = ""
var frame_counter = 0
var just_started = true
var passive_move := Vector3.ZERO

var attacked_in_frame = false


func _ready() :
	self_id = self.get_instance_id()
	#self.play("none")
	just_started = true
	
func _physics_process(_delta: float) -> void:
	obj = Mainglobal.characters_repository[Mainglobal.scene_objects[self_id]["name"]]
	var obj_scene = Mainglobal.scene_objects[self_id]
	Mainglobal.update_object_z_index(self_id)

	if just_started :
		just_started = false
		return

	frame_counter += 1
	if frame_counter > 2 :
		frame_counter = 0
		return

	var pos_iso = obj_scene["pos"]
	var distance_to_player_x = 9999.9999
	var distance_to_player_y = 9999.9999


	if Mainglobal.player.obj != null and "pos" in Mainglobal.player.obj and Mainglobal.player:
		distance_to_player_x = abs((pos_iso.x+obj_scene["size"].x/2)-(Mainglobal.player.obj["pos"].x+Mainglobal.player.obj["size"].x/2))
		distance_to_player_y = Mainglobal.player.obj["pos"].y - (pos_iso.y+obj_scene["size"].y)

	if not Mainglobal.time_stoped and distance_to_player_x <= 6 and distance_to_player_y <= 6 and distance_to_player_y > 0:
		sprite.play("carnivore")
		if sprite.frame in [3] and not attacked_in_frame :
			Mainglobal.update_life_player(-2)
			attacked_in_frame = true
		if not sprite.frame in [3] :
			attacked_in_frame = false
	else :
		sprite.pause()

	# APLICAR DESPLAZAMIENTO PASIVO (ARRASTRE)
	if passive_move != Vector3.ZERO :
		Mainglobal.scene_objects[self_id]["pos"] += passive_move
		passive_move = Vector3.ZERO


func load_data(uid_object) :
	obj = Mainglobal.characters_repository[uid_object]
	Mainglobal.load_data(uid_object,obj,sprite)


func push(source_weight,direction,above) :
	inertia = Mainglobal.get_inertia(source_weight,weight,above)
	push_direction = direction
	
