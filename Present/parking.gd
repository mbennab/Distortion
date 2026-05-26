extends Node2D

const MINIGAME_SCENE = preload("res://Scripts/MiniJeuSoleil.tscn")

var _player_near_minigame := false
var _minigame_running := false
var _minigame_instance: CanvasLayer = null
var _badge_obtained := false

var _thought_layer: CanvasLayer
var _thought_bubble: Label
var _prompt_layer: CanvasLayer
var _prompt_lbl: Label


func _ready() -> void:
	_connect_retour_signal()
	_connect_minigame_zone()
	_setup_ui()


func _connect_retour_signal() -> void:
	var zone_retour = get_node_or_null("zone retour parking")
	if zone_retour:
		zone_retour.body_entered.connect(_on_retour_parking_entered)


func _connect_minigame_zone() -> void:
	var zone = get_node_or_null("zone interation minijeux")
	if zone:
		zone.monitoring = false
		zone.body_entered.connect(_on_minigame_zone_entered)
		zone.body_exited.connect(_on_minigame_zone_exited)


func _setup_ui() -> void:
	_thought_layer = CanvasLayer.new()
	_thought_layer.layer = 50
	add_child(_thought_layer)

	_thought_bubble = Label.new()
	_thought_bubble.text = "Tiens, on dirait un employé…\nJe peux peut-être lui voler\nson badge, il ne m'en voudra pas"
	_thought_bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_thought_bubble.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_thought_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_thought_bubble.add_theme_font_size_override("font_size", 16)
	_thought_bubble.add_theme_color_override("font_color", Color(0.12, 0.12, 0.2))
	var bstyle := StyleBoxFlat.new()
	bstyle.bg_color = Color(0.82, 0.9, 1.0, 0.93)
	bstyle.border_color = Color(0.35, 0.45, 0.65, 0.6)
	bstyle.border_width_top = 1
	bstyle.border_width_bottom = 1
	bstyle.border_width_left = 1
	bstyle.border_width_right = 1
	bstyle.corner_radius_top_left = 10
	bstyle.corner_radius_top_right = 10
	bstyle.corner_radius_bottom_left = 2
	bstyle.corner_radius_bottom_right = 10
	_thought_bubble.add_theme_stylebox_override("normal", bstyle)
	_thought_bubble.custom_minimum_size = Vector2(280, 0)
	_thought_bubble.visible = false
	_thought_bubble.z_index = 100
	_thought_layer.add_child(_thought_bubble)

	_prompt_layer = CanvasLayer.new()
	_prompt_layer.layer = 50
	add_child(_prompt_layer)

	_prompt_lbl = Label.new()
	_prompt_lbl.text = "Appuyez sur E pour s'approcher"
	_prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_lbl.add_theme_font_size_override("font_size", 18)
	_prompt_lbl.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.08, 0.08, 0.12, 0.85)
	pstyle.border_color = Color(0.6, 0.55, 0.3, 0.7)
	pstyle.border_width_top = 2
	pstyle.border_width_bottom = 2
	pstyle.border_width_left = 2
	pstyle.border_width_right = 2
	pstyle.corner_radius_top_left = 8
	pstyle.corner_radius_top_right = 8
	pstyle.corner_radius_bottom_left = 8
	pstyle.corner_radius_bottom_right = 8
	_prompt_lbl.add_theme_stylebox_override("normal", pstyle)
	_prompt_lbl.custom_minimum_size = Vector2(340, 40)
	_prompt_lbl.visible = false
	_prompt_layer.add_child(_prompt_lbl)


func _process(_delta: float) -> void:
	if not visible:
		return
	_update_thought_bubble_position()
	_update_prompt_position()


func _update_thought_bubble_position() -> void:
	if not _thought_bubble or not _thought_bubble.visible:
		return
	var parent = get_parent()
	if not parent or not parent.time_aunote:
		return
	var cam = get_viewport().get_camera_2d()
	if not cam:
		return
	var player_global: Vector2 = parent.time_aunote.global_position
	var screen: Vector2 = cam.get_screen_center_position()
	var zoom_val: Vector2 = cam.zoom
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var sx: float = (player_global.x - screen.x) * zoom_val.x + vp_size.x / 2.0
	var sy: float = (player_global.y - screen.y) * zoom_val.y + vp_size.y / 2.0
	_thought_bubble.position = Vector2(sx - _thought_bubble.size.x / 2.0, sy - 200.0)


func _update_prompt_position() -> void:
	if not _prompt_lbl or not _prompt_lbl.visible:
		return
	var vp_size := get_viewport().get_visible_rect().size
	_prompt_lbl.position = Vector2(vp_size.x / 2.0 - _prompt_lbl.size.x / 2.0, vp_size.y - 80.0)


func _on_retour_parking_entered(body: Node2D) -> void:
	if not visible:
		return
	var parent = get_parent()
	if body == parent.time_aunote and parent.can_move:
		parent._return_from_parking()


func _on_minigame_zone_entered(body: Node2D) -> void:
	if not visible:
		return
	if body.name == "TimeAunote" and not _badge_obtained:
		_player_near_minigame = true
		_show_thought_bubble()
		_show_prompt()

func _on_minigame_zone_exited(body: Node2D) -> void:
	if body.name == "TimeAunote":
		_player_near_minigame = false
		_hide_thought_bubble()
		_hide_prompt()


func _show_thought_bubble() -> void:
	if _minigame_running or _badge_obtained or _thought_bubble == null:
		return
	_thought_bubble.visible = true


func _hide_thought_bubble() -> void:
	if _thought_bubble:
		_thought_bubble.visible = false


func _show_prompt() -> void:
	if _minigame_running or _badge_obtained or _prompt_lbl == null:
		return
	_prompt_lbl.visible = true


func _hide_prompt() -> void:
	if _prompt_lbl:
		_prompt_lbl.visible = false


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _minigame_running:
		return
	if not event.is_action_pressed("interagir"):
		return
	if not _player_near_minigame:
		return
	if _badge_obtained:
		return
	var parent = get_parent()
	if not parent or not parent.can_move:
		return
	get_viewport().set_input_as_handled()
	_start_minigame()


func _start_minigame() -> void:
	_minigame_running = true
	_hide_thought_bubble()
	_hide_prompt()
	var parent = get_parent()
	parent.can_move = false
	if parent.time_aunote:
		parent.time_aunote.hide()
	
	# Stop parking music, play minigame BGM
	parent._stop_ambient()
	parent._play_bgm("minijeu_soleil")

	var map_pnj = get_node_or_null("pnjMaintenanceMap")
	if map_pnj:
		map_pnj.hide()

	_minigame_instance = MINIGAME_SCENE.instantiate()
	_minigame_instance.done.connect(_on_minigame_done)
	get_tree().root.add_child(_minigame_instance)


func _on_minigame_done(success: bool) -> void:
	_minigame_running = false
	_minigame_instance = null
	var parent = get_parent()
	
	# Stop minigame BGM, resume zone music
	parent._stop_bgm()
	parent._update_audio_stage()
	
	if parent.time_aunote:
		parent.time_aunote.show()

	var map_pnj = get_node_or_null("pnjMaintenanceMap")
	if map_pnj:
		map_pnj.show()

	if success:
		_badge_obtained = true
		parent._on_parking_minigame_won()
	else:
		parent.can_move = true
		if _player_near_minigame and not _badge_obtained:
			_show_thought_bubble()
			_show_prompt()


func stop_minigame() -> void:
	if _minigame_instance and is_instance_valid(_minigame_instance):
		_minigame_instance.queue_free()
		_minigame_instance = null
	_minigame_running = false
	_hide_thought_bubble()
	_hide_prompt()
	var parent = get_parent()
	if parent and parent.time_aunote:
		parent.time_aunote.show()


func set_interactive(active: bool) -> void:
	var zone = get_node_or_null("zone interation minijeux")
	if zone:
		zone.monitoring = active
	if not active:
		_player_near_minigame = false
		_hide_thought_bubble()
		_hide_prompt()
