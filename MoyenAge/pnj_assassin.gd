extends Node2D

@export var npc_id: String = "npc_assassin"
@export var npc_name: String = "L'Assassin"
@export var portrait_path: String = "res://art/MoyenAge/portrait_assassin.png"

var animation_assassin: AnimatedSprite2D
var zone_dialogue: Area2D
var player_nearby: bool = false
var bubble: Label
var bubble_timer: Timer

func _ready() -> void:
	add_to_group("npc_dialogue")

	animation_assassin = $AnimatedSprite2D
	animation_assassin.play("default") # Animation idle par défaut

	# Créer la ZoneDialogue si elle n'existe pas déjà comme enfant
	zone_dialogue = get_node_or_null("ZoneDialogue")
	if not zone_dialogue:
		zone_dialogue = Area2D.new()
		zone_dialogue.name = "ZoneDialogue"
		zone_dialogue.collision_layer = 0
		zone_dialogue.collision_mask = 1 # Détecte le joueur (layer 1)
		
		var col = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = 220.0
		col.shape = shape
		zone_dialogue.add_child(col)
		add_child(zone_dialogue)

	zone_dialogue.body_entered.connect(_on_body_entered)
	zone_dialogue.body_exited.connect(_on_body_exited)

	_setup_bubble()

func _setup_bubble() -> void:
	bubble = Label.new()
	bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble.add_theme_font_size_override("font_size", 13)
	bubble.add_theme_color_override("font_color", Color(0.18, 0.12, 0.05, 1.0))
	bubble.custom_minimum_size = Vector2(240, 0)
	var bubble_style = StyleBoxFlat.new()
	bubble_style.bg_color = Color(0.96, 0.93, 0.85, 0.95)
	bubble_style.border_width_left = 2
	bubble_style.border_width_top = 2
	bubble_style.border_width_right = 2
	bubble_style.border_width_bottom = 2
	bubble_style.border_color = Color(0.48, 0.38, 0.28, 0.7)
	bubble_style.corner_radius_top_left = 12
	bubble_style.corner_radius_top_right = 12
	bubble_style.corner_radius_bottom_left = 12
	bubble_style.corner_radius_bottom_right = 2
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
	bubble.position = Vector2(-bubble.size.x / 2.0, -220)

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

func apparition(pos: Vector2) -> void:
	animation_assassin.animation = "default"
	animation_assassin.play()
	self.position = pos
	show()

func get_npc_id() -> String:
	return npc_id

func get_npc_name() -> String:
	return npc_name
