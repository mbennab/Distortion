extends Node2D

signal finished(success: bool)

var voiture: AnimatedSprite2D
var current_lane: int = 1
var lane_positions: Array[Vector2] = []
var obstacle_textures: Array[Texture2D] = []
var game_active: bool = false
var car_area: Area2D
var collision_label: Label
var _timer_panel: Panel
var _timer_title: Label
var _timer_value: Label
var _elapsed: float = 0.0

const OBSTACLE_SPEED: float = 1600.0
const LANE_COUNT: int = 3
const RESTART_DELAY: float = 1.0
const GAME_DURATION: float = 30.0
const BASE_SPAWN_MIN: float = 0.4
const BASE_SPAWN_MAX: float = 0.8
const SPAWN_SPEEDUP: float = 0.002


func _ready() -> void:
	voiture = $voitureFuture

	for i in LANE_COUNT:
		lane_positions.append($Markers.get_child(i).position)

	voiture.position = lane_positions[1]

	collision_label = $CanvasLayer/collision_label
	collision_label.hide()

	_setup_timer_panel()

	_load_obstacle_textures()
	_setup_car_collision()

	$obstacle_timer.timeout.connect(_spawn_obstacle)
	$game_timer.timeout.connect(_on_game_timeout)

	hide()
	game_active = false


func _setup_timer_panel() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.15, 0.85)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.4, 0.6, 1, 0.6)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.corner_radius_bottom_left = 8

	_timer_panel = Panel.new()
	_timer_panel.size = Vector2(160, 56)
	_timer_panel.position = Vector2(844, 16)
	_timer_panel.add_theme_stylebox_override("panel", panel_style)
	_timer_panel.hide()
	$CanvasLayer.add_child(_timer_panel)

	_timer_title = Label.new()
	_timer_title.text = "Temps restant"
	_timer_title.add_theme_font_size_override("font_size", 14)
	_timer_title.add_theme_color_override("font_color", Color(0.8, 0.9, 1))
	_timer_title.position = Vector2(10, 4)
	_timer_title.size = Vector2(140, 20)
	_timer_panel.add_child(_timer_title)

	_timer_value = Label.new()
	_timer_value.text = str(GAME_DURATION) + "s"
	_timer_value.add_theme_font_size_override("font_size", 22)
	_timer_value.add_theme_color_override("font_color", Color(1, 1, 1))
	_timer_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_value.position = Vector2(0, 26)
	_timer_value.size = Vector2(160, 26)
	_timer_panel.add_child(_timer_value)


func start_game() -> void:
	game_active = true
	_elapsed = 0.0
	show()
	collision_label.hide()
	_timer_panel.show()
	voiture.position = lane_positions[1]
	current_lane = 1
	$obstacle_timer.start(randf_range(0.3, 0.6))
	$game_timer.start(GAME_DURATION)


func stop_game() -> void:
	game_active = false
	$obstacle_timer.stop()
	$game_timer.stop()
	_clear_obstacles()
	_timer_panel.hide()
	hide()


func _process(delta: float) -> void:
	if not game_active:
		return

	_elapsed += delta
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
	sprite.scale = Vector2(0.28, 0.28)
	obstacle.add_child(sprite)

	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(60, 40)
	shape.shape = rect
	obstacle.add_child(shape)

	obstacle.position = obs_marker.position

	add_child(obstacle)

	var speedup := _elapsed * SPAWN_SPEEDUP
	var min_t := maxf(0.08, BASE_SPAWN_MIN - speedup)
	var max_t := maxf(0.15, BASE_SPAWN_MAX - speedup)
	$obstacle_timer.start(randf_range(min_t, max_t))


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
	$game_timer.stop()
	$game_timer.start(GAME_DURATION)
	collision_label.show()

	await get_tree().create_timer(RESTART_DELAY).timeout

	if not is_inside_tree():
		return

	_clear_obstacles()
	_elapsed = 0.0
	voiture.position = lane_positions[1]
	current_lane = 1
	game_active = true
	collision_label.hide()
	$obstacle_timer.start(randf_range(0.3, 0.6))


func _clear_obstacles() -> void:
	for obs in get_tree().get_nodes_in_group("obstacles"):
		obs.queue_free()


func _input(event: InputEvent) -> void:
	if not game_active or not is_inside_tree():
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		stop_game()
		finished.emit(false)


func _on_game_timeout() -> void:
	game_active = false
	$obstacle_timer.stop()
	_clear_obstacles()
	await get_tree().create_timer(1.5).timeout

	if not is_inside_tree():
		return

	stop_game()
	finished.emit(true)


func _update_timer_display() -> void:
	var remaining = int($game_timer.time_left)
	_timer_value.text = str(remaining) + "s"
