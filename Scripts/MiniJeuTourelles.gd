extends Node2D

signal finished(success: bool)

var game_active: bool = false
var spawn_timer: Timer
var elapsed: float = 0.0
var orb_texture: Texture2D

const SPAWN_INTERVAL: float = 0.2
const GAME_DURATION: float = 30.0
const ORB_SPEED: float = 400.0
const ANGLE_T1_MIN: float = -0.35
const ANGLE_T1_MAX: float = 1.48
const ANGLE_T2_MIN: float = 1.66
const ANGLE_T2_MAX: float = 3.49

@export var tourelle1_position: Vector2
@export var tourelle2_position: Vector2


func _ready() -> void:
	hide()
	orb_texture = preload("res://art/Futur/orbe.png")
	spawn_timer = Timer.new()
	spawn_timer.one_shot = false
	spawn_timer.wait_time = SPAWN_INTERVAL
	spawn_timer.timeout.connect(_spawn_orb)
	add_child(spawn_timer)


func start_game() -> void:
	game_active = true
	elapsed = 0.0
	show()
	_spawn_orb()
	spawn_timer.start()


func stop_game() -> void:
	game_active = false
	spawn_timer.stop()
	for orb in get_tree().get_nodes_in_group("tourelle_orbs"):
		orb.queue_free()
	hide()


func _process(delta: float) -> void:
	if not game_active:
		return
	elapsed += delta
	if elapsed >= GAME_DURATION:
		_on_victory()


func _spawn_orb() -> void:
	if not game_active:
		return
	var from_tourelle1: bool = randf() < 0.5
	var spawn_pos: Vector2 = tourelle1_position if from_tourelle1 else tourelle2_position
	var angle = randf_range(ANGLE_T1_MIN, ANGLE_T1_MAX) if from_tourelle1 else randf_range(ANGLE_T2_MIN, ANGLE_T2_MAX)
	var direction = Vector2.RIGHT.rotated(angle)
	_create_orb(spawn_pos, direction)


func _create_orb(pos: Vector2, dir: Vector2) -> void:
	var orb_script = preload("res://Scripts/OrbeTourelle.gd")
	var orb = CharacterBody2D.new()
	orb.set_script(orb_script)
	orb.add_to_group("tourelle_orbs")
	orb.position = pos
	orb.collision_layer = 0
	orb.collision_mask = 17

	var sprite = Sprite2D.new()
	sprite.texture = orb_texture
	sprite.scale = Vector2(0.3, 0.3)
	orb.add_child(sprite)

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 43.0
	shape.shape = circle
	shape.position = Vector2(0, -20)
	orb.add_child(shape)

	orb.velocity = dir * ORB_SPEED
	orb.player_hit.connect(_on_game_over)
	add_child(orb)


func _on_game_over() -> void:
	game_active = false
	spawn_timer.stop()
	for orb in get_tree().get_nodes_in_group("tourelle_orbs"):
		orb.queue_free()
	finished.emit(false)


func _on_victory() -> void:
	game_active = false
	spawn_timer.stop()
	for orb in get_tree().get_nodes_in_group("tourelle_orbs"):
		orb.queue_free()
	finished.emit(true)
