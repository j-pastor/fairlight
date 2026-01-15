extends AnimatedSprite2D

var step_time := 0.05
var timer := 0.0

var step_count := 0
var max_steps := 80

#var direction := Vector2(-0.2, 0.2)

func _process(delta):
	timer += delta
	if timer >= step_time:
		timer = 0.0
		move_step()

func move_step():
	position += Mainglobal.sea_direction
	step_count += 1

	if step_count >= max_steps:
		step_count = 0
		Mainglobal.sea_direction = -Mainglobal.sea_direction
