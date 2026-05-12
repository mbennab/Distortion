extends Node2D

var voiture: AnimatedSprite2D
var current_lane: int = 1
var lane_positions: Array[Vector2] = []
var obstacle_textures: Array[Texture2D] = []
var game_active: bool = false
var car_area: Area2D
var collision_label: Label
var timer_label: Label

const OBSTACLE_SPEED: float = 400.0
const LANE_COUNT: int = 3
const RESTART_DELAY: float = 1.5
const GAME_DURATION: float = 40.0


func _ready() -> void:
	voiture = $voitureFuture

	for i in LANE_COUNT:
		lane_positions.append($Markers.get_child(i).position)

	voiture.position = lane_positions[1]

	collision_label = $CanvasLayer/collision_label
	timer_label = $CanvasLayer/timer_label

	_load_obstacle_textures()
	_setup_car_collision()

	$obstacle_timer.timeout.connect(_spawn_obstacle)
	$game_timer.timeout.connect(_on_game_timeout)

	game_active = true
	$obstacle_timer.start(randf_range(3.0, 4.0))
	$game_timer.start(GAME_DURATION)


func _process(delta: float) -> void:
	if not game_active:
		return

	_handle_input()
	_move_obstacles(delta)
	_update_timer_display()


func _handle_input() -> void:
	if Input.is_action_just_pressed("marche_haut"):
		current_lane = clampi(current_lane - 1, 0, LANE_COUNT - 1)
		voiture.position.y = lane_positions[current_lane].y
	if Input.is_action_just_pressed("marche_bas"):
		current_lane = clampi(current_lane + 1, 0, LANE_COUNT - 1)
		voiture.position.y = lane_positions[current_lane].y


func _load_obstacle_textures() -> void:
	for i in range(1, 4):
		var tex = load("res://art/Futur/obstacle" + str(i) + ".png")
		if tex:
			obstacle_textures.append(tex)


func _setup_car_collision() -> void:
	car_area = Area2D.new()
	car_area.name = "car_area"
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(100, 70)
	shape.shape = rect
	car_area.add_child(shape)
	car_area.area_entered.connect(_on_car_hit)
	voiture.add_child(car_area)


func _spawn_obstacle() -> void:
	if not game_active:
		return

	var lane_index = randi() % LANE_COUNT
	var obs_marker = $ObsMarkers.get_child(lane_index)
	var tex_index = randi() % obstacle_textures.size()

	var obstacle = Area2D.new()
	obstacle.add_to_group("obstacles")

	var sprite = Sprite2D.new()
	sprite.texture = obstacle_textures[tex_index]
	obstacle.add_child(sprite)

	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(80, 60)
	shape.shape = rect
	obstacle.add_child(shape)

	obstacle.position = obs_marker.position

	add_child(obstacle)

	$obstacle_timer.start(randf_range(3.0, 4.0))


func _move_obstacles(delta: float) -> void:
	for obs in get_tree().get_nodes_in_group("obstacles"):
		obs.position.x -= OBSTACLE_SPEED * delta
		if obs.position.x < -300:
			obs.queue_free()


func _on_car_hit(area: Area2D) -> void:
	if not game_active:
		return
	if area.is_in_group("obstacles"):
		_crash()


func _crash() -> void:
	game_active = false
	$obstacle_timer.stop()
	collision_label.show()

	await get_tree().create_timer(RESTART_DELAY).timeout

	if not is_inside_tree():
		return

	_clear_obstacles()
	voiture.position = lane_positions[1]
	current_lane = 1
	game_active = true
	collision_label.hide()
	$obstacle_timer.start(randf_range(3.0, 4.0))


func _clear_obstacles() -> void:
	for obs in get_tree().get_nodes_in_group("obstacles"):
		obs.queue_free()


func _on_game_timeout() -> void:
	game_active = false
	$obstacle_timer.stop()
	_clear_obstacles()
	collision_label.text = "Fin du mini-jeu !"
	collision_label.show()


func _update_timer_display() -> void:
	var remaining = int($game_timer.time_left)
	timer_label.text = str(remaining) + "s"
