extends Node2D

enum Direction { LEFT, RIGHT, FRONT }

var current_direction := Direction.LEFT
var active := true
var _turn_timer := 0.0
var _turn_interval := 3.0

signal player_caught

var _sprite: Sprite2D
var _arc: Polygon2D
var _detect_area: Area2D
var _detect_shape: CollisionShape2D


func _ready() -> void:
	_sprite = Sprite2D.new()
	add_child(_sprite)

	_arc = Polygon2D.new()
	_arc.color = Color(1, 0, 0, 0.15)
	add_child(_arc)

	_detect_area = Area2D.new()
	_detect_area.collision_mask = 1
	add_child(_detect_area)

	_detect_shape = CollisionShape2D.new()
	_detect_area.add_child(_detect_shape)

	_detect_area.body_entered.connect(_on_detected)

	_turn_interval = randf_range(2.0, 4.0)
	_set_direction(current_direction)


func _process(delta: float) -> void:
	if not active:
		return
	_turn_timer += delta
	if _turn_timer >= _turn_interval:
		_turn_timer = 0.0
		_turn()

	if _detect_area.has_overlapping_bodies():
		for body in _detect_area.get_overlapping_bodies():
			if body.name == "TimeAunote" and active:
				player_caught.emit()
				set_active(false)
				modulate = Color(1, 0.4, 0.4)
				break


func _turn() -> void:
	var dirs := [Direction.LEFT, Direction.RIGHT, Direction.FRONT]
	var filtered: Array[Direction] = []
	for d in dirs:
		if d != current_direction:
			filtered.append(d)
	_set_direction(filtered[randi() % filtered.size()])
	_turn_interval = randf_range(2.0, 4.0)


func _set_direction(dir: Direction) -> void:
	current_direction = dir
	var tex: Texture2D
	match dir:
		Direction.LEFT:
			tex = load("res://art/Futur/gardeGauche.png")
		Direction.RIGHT:
			tex = load("res://art/Futur/gardeDroite.png")
		Direction.FRONT:
			tex = load("res://art/Futur/gardeFace.png")
	_sprite.texture = tex
	var tex_size := tex.get_size()
	_sprite.scale = Vector2(350.0 / tex_size.x, 500.0 / tex_size.y)
	_update_cone()


func _update_cone() -> void:
	var origin_local: Vector2
	var base_angle: float

	match current_direction:
		Direction.LEFT:
			origin_local = Vector2(-175, 0)
			base_angle = PI
		Direction.RIGHT:
			origin_local = Vector2(175, 0)
			base_angle = 0.0
		Direction.FRONT:
			origin_local = Vector2(0, 250)
			base_angle = PI / 2.0

	var radius := 550.0
	var spread_deg := 65.0
	var start_angle := base_angle - deg_to_rad(spread_deg)
	var end_angle := base_angle + deg_to_rad(spread_deg)
	var num_segments := 20

	var pts := PackedVector2Array()
	pts.append(origin_local)
	for i in range(num_segments + 1):
		var t := float(i) / float(num_segments)
		var a := lerpf(start_angle, end_angle, t)
		pts.append(origin_local + Vector2(cos(a), sin(a)) * radius)

	_arc.polygon = pts

	var rect := RectangleShape2D.new()
	match current_direction:
		Direction.LEFT, Direction.RIGHT:
			rect.size = Vector2(radius, 400)
			_detect_shape.position = origin_local + Vector2(radius / -2.0 if current_direction == Direction.LEFT else radius / 2.0, 0)
		Direction.FRONT:
			rect.size = Vector2(400, radius)
			_detect_shape.position = origin_local + Vector2(0, radius / 2.0)
	_detect_shape.shape = rect


func set_active(value: bool) -> void:
	active = value
	_detect_area.monitoring = value


func _on_detected(body: Node2D) -> void:
	if body.name == "TimeAunote" and active:
		player_caught.emit()
		set_active(false)
		modulate = Color(1, 0.4, 0.4)
