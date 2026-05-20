extends Node2D

@export var npc_id: String = "npc_koiai2_futur"
@export var npc_name: String = "Koiai"

var pnjkoiai2Animation: AnimatedSprite2D
var zone_dialogue: Area2D
var player_nearby: bool = false
var bubble: Label
var bubble_timer: Timer


func _ready() -> void:
	hide()
	add_to_group("npc_dialogue")
	pnjkoiai2Animation = $pnjkoiai2Animation
	pnjkoiai2Animation.play()

	zone_dialogue = $ZoneDialogue
	zone_dialogue.body_entered.connect(_on_body_entered)
	zone_dialogue.body_exited.connect(_on_body_exited)

	_setup_bubble()


func _setup_bubble() -> void:
	bubble = Label.new()
	bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble.add_theme_font_size_override("font_size", 13)
	bubble.add_theme_color_override("font_color", Color(0.4, 0.95, 0.6, 1.0))
	bubble.custom_minimum_size = Vector2(240, 0)
	var bubble_style = StyleBoxFlat.new()
	bubble_style.bg_color = Color(0.06, 0.06, 0.1, 0.93)
	bubble_style.border_width_left = 2
	bubble_style.border_width_top = 2
	bubble_style.border_width_right = 2
	bubble_style.border_width_bottom = 2
	bubble_style.border_color = Color(0.2, 0.8, 0.4, 0.7)
	bubble_style.corner_radius_top_left = 6
	bubble_style.corner_radius_top_right = 6
	bubble_style.corner_radius_bottom_left = 6
	bubble_style.corner_radius_bottom_right = 1
	bubble.add_theme_stylebox_override("normal", bubble_style)
	bubble.visible = false
	bubble.z_index = 100
	add_child(bubble)

	bubble_timer = Timer.new()
	bubble_timer.one_shot = true
	bubble_timer.timeout.connect(_on_bubble_timeout)
	add_child(bubble_timer)


func show_bubble(text: String) -> void:
	bubble.text = text
	bubble.visible = true
	bubble_timer.start(5.0)
	await get_tree().process_frame
	_update_bubble_position()


func hide_bubble() -> void:
	bubble.visible = false
	bubble_timer.stop()


func _update_bubble_position() -> void:
	if not bubble.visible:
		return
	bubble.position = Vector2(-bubble.size.x / 2.0, -320)


func _on_bubble_timeout() -> void:
	hide_bubble()


func _on_body_entered(body: Node2D) -> void:
	if body.name == "TimeAunote":
		player_nearby = true
		DialogueUI.show_prompt(npc_id, npc_name)


func _on_body_exited(body: Node2D) -> void:
	if body.name == "TimeAunote":
		player_nearby = false
		DialogueUI.hide_prompt()


func apparition(position: Vector2) -> void:
	pnjkoiai2Animation.animation = "pnj-koiai"
	self.position = position
	show()


func get_npc_id() -> String:
	return npc_id


func get_npc_name() -> String:
	return npc_name
