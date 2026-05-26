extends CharacterBody2D

signal player_hit

func _ready():
	var t = Timer.new()
	t.one_shot = true
	t.wait_time = 9.0
	t.timeout.connect(_on_timeout)
	add_child(t)
	t.start()

func _on_timeout():
	if is_instance_valid(self):
		queue_free()

func _physics_process(delta):
	var remaining = velocity * delta
	for _i in range(5):
		var collision = move_and_collide(remaining)
		if not collision:
			break
		var collider = collision.get_collider()
		if collider.name == "TimeAunote" or collider.is_in_group("player"):
			player_hit.emit()
			queue_free()
			return
		var normal = collision.get_normal()
		velocity = velocity.bounce(normal)
		remaining = remaining.bounce(normal)
