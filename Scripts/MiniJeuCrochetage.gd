extends CanvasLayer

signal done(success: bool)

const STAGES := 5
const CIRCLE_RADIUS := 150.0
const INDICATOR_SPEED := 2.0

var current_stage := 0
var green_angle := deg_to_rad(90.0)
var green_offset := 0.0
var indicator_angle := 0.0
var running := false

var draw_area: Node2D
var stage_label: Label
var msg_label: Label
var bg: ColorRect

var _stage_angles := [
	deg_to_rad(90.0),
	deg_to_rad(60.0),
	deg_to_rad(40.0),
	deg_to_rad(25.0),
	deg_to_rad(15.0),
]


func _ready() -> void:
	draw_area = $draw_area
	stage_label = $stage_label
	bg = $bg
	bg.size = get_viewport().get_visible_rect().size
	draw_area.position = get_viewport().get_visible_rect().size / 2.0
	stage_label.position = Vector2(get_viewport().get_visible_rect().size.x / 2.0 - 100, 50)
	stage_label.size = Vector2(200, 40)

	msg_label = Label.new()
	msg_label.text = "Appuyez sur E quand l'indicateur\nest dans la zone verte"
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.add_theme_font_size_override("font_size", 16)
	msg_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	msg_label.position = Vector2(get_viewport().get_visible_rect().size.x / 2.0 - 150, get_viewport().get_visible_rect().size.y - 80)
	msg_label.size = Vector2(300, 60)
	add_child(msg_label)

	draw_area.draw.connect(_on_draw_area_draw)
	start_stage(0)


func start_stage(stage: int) -> void:
	current_stage = stage
	green_angle = _stage_angles[stage]
	green_offset = randf_range(0, TAU)
	indicator_angle = 0
	stage_label.text = "Étape %d / %d" % [stage + 1, STAGES]
	running = true


func _process(delta: float) -> void:
	if not running:
		return
	indicator_angle += INDICATOR_SPEED * delta
	if indicator_angle > TAU:
		indicator_angle -= TAU
	draw_area.queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_inside_tree() or not running:
		return
	if event.is_action_pressed("interagir"):
		get_viewport().set_input_as_handled()
		_check_hit()


func _check_hit() -> void:
	var diff := wrapf(indicator_angle - green_offset, 0, TAU)
	if diff <= green_angle:
		_on_success()
	else:
		_on_failure()


func _on_success() -> void:
	if current_stage >= STAGES - 1:
		running = false
		done.emit(true)
		queue_free()
	else:
		start_stage(current_stage + 1)


func _on_failure() -> void:
	start_stage(0)


func _on_draw_area_draw() -> void:
	var r := CIRCLE_RADIUS
	var col := Color(0.8, 0.8, 0.8)
	draw_area.draw_arc(Vector2.ZERO, r, 0, TAU, 64, col, 2.0, true)
	if green_angle > 0:
		draw_area.draw_arc(Vector2.ZERO, r, green_offset, green_offset + green_angle, 64, Color(0.2, 0.9, 0.2), 14.0, true)
	var tip := Vector2(cos(indicator_angle), sin(indicator_angle)) * r
	draw_area.draw_line(Vector2.ZERO, tip, Color(1, 0.2, 0.2), 3.0, true)
	draw_area.draw_circle(tip, 8, Color(1, 0.2, 0.2))
