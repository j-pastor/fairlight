extends Sprite2D

var step_time := 0.05
var timer := 0.0

var step_count := 0
var max_steps := 60

var direction := Vector2(0, 0.05)
var cumulated := 1


func _process(delta):
	timer += delta
	if timer >= step_time:
		timer = 0.0
		move_step()

func move_step():
	position += direction
	step_count += 1
	cumulated += direction.y

	_update_glow()

	if step_count >= max_steps:
		step_count = 0
		direction = -direction

	var c := self.modulate
	c.r += -direction.y * 0.15
	c.g += -direction.y * 0.15
	c.b += -direction.y * 0.15
	
	self.modulate = c


func _update_glow():
	var glowlava := $Glowlava
	if direction.y > 0:
		# La lava baja
		glowlava.energy -= 0.01
		glowlava.texture_scale -= 0.1
	else:
		# La lava sube
		glowlava.energy += 0.01
		glowlava.texture_scale += 0.1

	# Opcional: límites para evitar valores absurdos
	glowlava.energy = clamp(glowlava.energy, 0.1, 0.5)
	glowlava.texture_scale = clamp(glowlava.scale.x, 0.5, 3.0)
	return
	
