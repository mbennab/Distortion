extends CanvasLayer

signal done(success: bool)

const LANE_COUNT := 3
const LANE_HEIGHT := 130.0
const ROAD_LEFT := 120.0
const ROAD_RIGHT := 960.0
const PLAYER_X := 220.0
const PLAYER_WIDTH := 44.0
const PLAYER_HEIGHT := 64.0
const BASE_SPEED := 280.0
const SPEED_INCREASE := 0.4
const SPAWN_INTERVAL := 1.2
const MIN_SPAWN_INTERVAL := 0.35

var lanes_y: Array[float] = []
var current_lane := 1
var target_y: float
var player_y: float
var obstacles: Array[Dictionary] = []
var score := 0
var running := false
var elapsed := 0.0
var spawn_timer := 0.0
var speed_multiplier := 1.0

var bg: ColorRect
var draw_area: Node2D
var score_label: Label
var game_over_label: Label
var msg_label: Label


func _ready() -> void:
	var vs := get_viewport().get_visible_rect().size
	var cy := vs.y / 2.0

	for i in range(LANE_COUNT):
		lanes_y.append(cy + (i - 1) * LANE_HEIGHT)

	current_lane = 1
	player_y = lanes_y[1]
	target_y = player_y

	bg = $bg
	bg.size = vs

	draw_area = $draw_area
	draw_area.draw.connect(_on_draw)

	score_label = $score_label

	msg_label = Label.new()
	msg_label.text = "↑↓ Z/S pour changer de voie"
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.add_theme_font_size_override("font_size", 16)
	msg_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	msg_label.position = Vector2(vs.x / 2.0 - 150, vs.y - 60)
	msg_label.size = Vector2(300, 40)
	add_child(msg_label)

	game_over_label = Label.new()
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.add_theme_font_size_override("font_size", 36)
	game_over_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	game_over_label.position = Vector2(vs.x / 2.0 - 200, vs.y / 2.0 - 100)
	game_over_label.size = Vector2(400, 80)
	game_over_label.visible = false
	add_child(game_over_label)

	score_label.position = Vector2(20, 20)
	score_label.text = "Score: 0"

	running = true


func _process(delta: float) -> void:
	if not running:
		return

	elapsed += delta
	speed_multiplier = 1.0 + elapsed * SPEED_INCREASE

	player_y = move_toward(player_y, target_y, 500.0 * delta)

	spawn_timer -= delta
	if spawn_timer <= 0:
		_spawn_obstacle()
		var interval = maxf(MIN_SPAWN_INTERVAL, SPAWN_INTERVAL - elapsed * 0.02)
		spawn_timer = interval + randf_range(-0.2, 0.2)

	var speed = BASE_SPEED * speed_multiplier
	for obs in obstacles:
		obs.x -= speed * delta

	obstacles = obstacles.filter(func(o): return o.x > -80.0)

	_check_collisions()

	score = int(elapsed * 10)
	score_label.text = "Score: %d" % score

	draw_area.queue_redraw()


func _spawn_obstacle() -> void:
	var lane = randi() % LANE_COUNT
	var variant = randi() % 3
	obstacles.append({
		"x": ROAD_RIGHT + 60.0,
		"lane": lane,
		"variant": variant,
		"width": 56.0 + variant * 14.0,
		"height": 48.0 + variant * 8.0,
	})


func _check_collisions() -> void:
	var px := PLAYER_X - PLAYER_WIDTH / 2.0
	var py := player_y - PLAYER_HEIGHT / 2.0
	var pw := PLAYER_WIDTH
	var ph := PLAYER_HEIGHT

	for obs in obstacles:
		var ow := obs.width
		var oh := obs.height
		var ox := obs.x - ow / 2.0
		var oy := lanes_y[obs.lane] - oh / 2.0

		if ox < px + pw and ox + ow > px and oy < py + ph and oy + oh > py:
			_game_over()
			return


func _game_over() -> void:
	running = false
	msg_label.visible = false
	game_over_label.text = "PERDU !\nScore: %d" % score
	game_over_label.visible = true

	await get_tree().create_timer(2.0).timeout
	done.emit(false)
	queue_free()


func _input(event: InputEvent) -> void:
	if not is_inside_tree() or not running:
		return

	if event.is_action_pressed("marche_haut") and current_lane > 0:
		current_lane -= 1
		target_y = lanes_y[current_lane]
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("marche_bas") and current_lane < LANE_COUNT - 1:
		current_lane += 1
		target_y = lanes_y[current_lane]
		get_viewport().set_input_as_handled()


func _on_draw() -> void:
	_draw_road()
	_draw_player()
	_draw_obstacles()


func _draw_road() -> void:
	var vs := get_viewport().get_visible_rect().size
	var rw := ROAD_RIGHT - ROAD_LEFT
	var top_y := lanes_y[0] - LANE_HEIGHT / 2.0 - 30.0
	var road_h := LANE_COUNT * LANE_HEIGHT + 60.0

	draw_area.draw_rect(Rect2(ROAD_LEFT, top_y, rw, road_h), Color(0.2, 0.2, 0.2))
	draw_area.draw_rect(Rect2(ROAD_LEFT, top_y, rw, road_h), Color(0.35, 0.35, 0.35), false, 2.0)

	for i in range(LANE_COUNT - 1):
		var y := (lanes_y[i] + lanes_y[i + 1]) / 2.0
		var x := ROAD_LEFT + 10.0
		while x < ROAD_RIGHT - 20.0:
			draw_area.draw_rect(Rect2(x, y - 1.5, 30.0, 3.0), Color(0.9, 0.9, 0.2, 0.7))
			x += 60.0

	draw_area.draw_rect(Rect2(ROAD_LEFT - 4, top_y - 4, 4, road_h + 8), Color.WHITE)
	draw_area.draw_rect(Rect2(ROAD_RIGHT, top_y - 4, 4, road_h + 8), Color.WHITE)

	var grass := Color(0.15, 0.45, 0.1)
	draw_area.draw_rect(Rect2(0, 0, ROAD_LEFT - 4, vs.y), grass)
	draw_area.draw_rect(Rect2(ROAD_RIGHT + 4, 0, vs.x - ROAD_RIGHT - 4, vs.y), grass)


func _draw_player() -> void:
	var x := PLAYER_X - PLAYER_WIDTH / 2.0
	var y := player_y - PLAYER_HEIGHT / 2.0

	draw_area.draw_rect(Rect2(x, y, PLAYER_WIDTH, PLAYER_HEIGHT), Color(0.15, 0.5, 0.9))
	draw_area.draw_rect(Rect2(x + 2, y + 2, PLAYER_WIDTH - 4, PLAYER_HEIGHT - 4), Color(0.2, 0.6, 1.0))
	draw_area.draw_rect(Rect2(x + PLAYER_WIDTH - 14, y + 6, 10, PLAYER_HEIGHT - 12), Color(0.5, 0.8, 1.0))

	draw_area.draw_rect(Rect2(x - 3, y - 2, 6, 12), Color(0.1, 0.1, 0.1))
	draw_area.draw_rect(Rect2(x - 3, y + PLAYER_HEIGHT - 10, 6, 12), Color(0.1, 0.1, 0.1))
	draw_area.draw_rect(Rect2(x + PLAYER_WIDTH - 3, y - 2, 6, 12), Color(0.1, 0.1, 0.1))
	draw_area.draw_rect(Rect2(x + PLAYER_WIDTH - 3, y + PLAYER_HEIGHT - 10, 6, 12), Color(0.1, 0.1, 0.1))


func _draw_obstacles() -> void:
	var colors := [Color(0.8, 0.15, 0.15), Color(0.5, 0.1, 0.5), Color(0.6, 0.4, 0.1)]
	for obs in obstacles:
		var ox := obs.x
		var oy := lanes_y[obs.lane]
		var ow := obs.width
		var oh := obs.height
		var col := colors[obs.variant]
		var x := ox - ow / 2.0
		var y := oy - oh / 2.0

		match obs.variant:
			0:
				draw_area.draw_rect(Rect2(x, y, ow, oh), col)
				draw_area.draw_rect(Rect2(x + 4, y + 4, 10, oh - 8), Color(1.0, 0.5, 0.5))
				draw_area.draw_rect(Rect2(x - 2, y - 2, 4, 8), Color(0.1, 0.1, 0.1))
				draw_area.draw_rect(Rect2(x - 2, y + oh - 6, 4, 8), Color(0.1, 0.1, 0.1))
			1:
				draw_area.draw_rect(Rect2(x, y, ow, oh), col)
				draw_area.draw_rect(Rect2(x + 4, y + 4, ow - 8, oh - 8), Color(0.6, 0.2, 0.6))
			2:
				draw_area.draw_circle(Vector2(ox, oy), oh / 2.0, col)
				draw_area.draw_circle(Vector2(ox, oy), oh / 2.0 - 4, Color(0.4, 0.25, 0.05))
