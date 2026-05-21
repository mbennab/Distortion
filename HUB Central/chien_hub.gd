extends Node2D

var _player_nearby: bool = false

var _bark_texts: Array[String] = [
	"Wouf !",
	"Wouf wouf !",
	"Waff !",
	"Waf !",
	"Ouaf ouaf !",
	"Wouuuf !",
	"Grrr... wouf !",
	"Waf waf waf !",
]

@onready var _animation: AnimatedSprite2D = $animation_chien_hub
@onready var _area: Area2D = $Area2D
@onready var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _bubble: Label
var _bubble_timer: Timer
var _prompt_label: Label
var _bark_sounds: Array[AudioStream] = []
var _bark_player: AudioStreamPlayer
var _idle_bark_timer: Timer


func _ready() -> void:
	hide()
	_rng.randomize()

	_animation.speed_scale = 2.0
	_animation.play()

	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)

	_setup_bubble()
	_setup_prompt()
	_setup_bark_audio()
	_setup_idle_bark()


func _setup_bubble() -> void:
	_bubble = Label.new()
	_bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bubble.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bubble.add_theme_font_size_override("font_size", 28)
	_bubble.add_theme_color_override("font_color", Color(0.9, 0.75, 1.0, 1.0))

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.18, 0.94)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.65, 0.35, 0.9, 0.7)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 14
	style.set_content_margin_all(12)
	_bubble.add_theme_stylebox_override("normal", style)

	_bubble.visible = false
	_bubble.z_index = 100
	add_child(_bubble)

	_bubble_timer = Timer.new()
	_bubble_timer.one_shot = true
	_bubble_timer.timeout.connect(_hide_bubble)
	add_child(_bubble_timer)


func _setup_prompt() -> void:
	_prompt_label = Label.new()
	_prompt_label.text = "Appuyez sur E pour dire bonjour au chien"
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 26)
	_prompt_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	_prompt_label.visible = false
	_prompt_label.z_index = 100
	add_child(_prompt_label)


func _setup_bark_audio() -> void:
	_bark_player = AudioStreamPlayer.new()
	_bark_player.bus = "Master"
	add_child(_bark_player)

	var dir := DirAccess.open("res://audio/chien/")
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.get_extension() in ["mp3", "ogg", "wav"]:
				var stream := load("res://audio/chien/" + file_name) as AudioStream
				if stream:
					_bark_sounds.append(stream)
			file_name = dir.get_next()
		dir.list_dir_end()


func _setup_idle_bark() -> void:
	_idle_bark_timer = Timer.new()
	_idle_bark_timer.one_shot = true
	_idle_bark_timer.timeout.connect(_on_idle_bark_timeout)
	add_child(_idle_bark_timer)


func _schedule_next_idle_bark() -> void:
	_idle_bark_timer.start(_rng.randf_range(10.0, 30.0))


func _on_idle_bark_timeout() -> void:
	if not visible:
		return
	if _player_nearby or _bubble.visible:
		_schedule_next_idle_bark()
		return
	_bark()
	_schedule_next_idle_bark()


func _update_prompt_position() -> void:
	_prompt_label.position = Vector2(-_prompt_label.size.x / 2.0, -95)


func _update_bubble_position() -> void:
	_bubble.position = Vector2(58, -50)


func show_bubble(text: String) -> void:
	_bubble.text = text
	_bubble.visible = true
	_bubble_timer.start(2.0)
	await get_tree().process_frame
	_update_bubble_position()


func _hide_bubble() -> void:
	_bubble.visible = false
	_bubble_timer.stop()
	_animation.speed_scale = 2.0


func _on_body_entered(body: Node2D) -> void:
	if is_instance_valid(body) and body.name == "TimeAunote":
		_player_nearby = true
		_prompt_label.visible = true
		await get_tree().process_frame
		_update_prompt_position()


func _on_body_exited(body: Node2D) -> void:
	if is_instance_valid(body) and body.name == "TimeAunote":
		_player_nearby = false
		_prompt_label.visible = false


func _input(event: InputEvent) -> void:
	if event.is_echo() or not _player_nearby:
		return
	if event.is_action_pressed("interagir"):
		_bark()
		get_viewport().set_input_as_handled()


func _bark() -> void:
	var idx := _rng.randi_range(0, _bark_texts.size() - 1)
	show_bubble(_bark_texts[idx])
	_animation.speed_scale = 7.0

	if not _bark_sounds.is_empty():
		_bark_player.stream = _bark_sounds[_rng.randi_range(0, _bark_sounds.size() - 1)]
		_bark_player.play()

	_schedule_next_idle_bark()


func stop_idle() -> void:
	_idle_bark_timer.stop()
	_bark_player.stop()
	_hide_bubble()


func apparition(pos: Vector2) -> void:
	_animation.animation = "idle-dog"
	_animation.speed_scale = 2.0
	self.position = pos
	show()
	_schedule_next_idle_bark()
