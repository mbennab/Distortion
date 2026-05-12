extends Node2D

@export var npc_id: String = "npc_guide_hub"
@export var npc_name: String = "Le Gardien du Nexus"

var pnj_hub_animation: AnimatedSprite2D
var zone_dialogue: Area2D
var player_nearby: bool = false
var bubble: Label
var bubble_timer: Timer
var _idle_murmur_timer: Timer

var _murmurs: Array[String] = [
	"Le temps est un fleuve... et je n'en suis que le passeur.",
	"Trois portails, trois destins...",
	"Je sens les époques trembler...",
	"Le Nexus attend... il attend toujours.",
	"Chaque époque a son ombre, voyageur.",
	"Les échos du passé résonnent encore.",
	"Ne reste pas trop longtemps ici... le temps n'attend personne.",
	"Parfois, je me souviens de choses qui n'ont pas encore eu lieu.",
	"Hmm... l'air sent le changement.",
	"La Distorsion grandit... doucement.",
]


func _ready() -> void:
	hide()
	add_to_group("npc_dialogue")
	pnj_hub_animation = $animation_pnj_hub
	pnj_hub_animation.play()

	zone_dialogue = $ZoneDialogue
	zone_dialogue.body_entered.connect(_on_body_entered)
	zone_dialogue.body_exited.connect(_on_body_exited)

	_setup_bubble()
	_setup_idle_murmur()


func _setup_bubble() -> void:
	bubble = Label.new()
	bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble.add_theme_font_size_override("font_size", 28)
	bubble.add_theme_color_override("font_color", Color(0.15, 0.1, 0.05))
	bubble.custom_minimum_size = Vector2(420, 0)
	var bubble_style = StyleBoxFlat.new()
	bubble_style.bg_color = Color(1, 1, 1, 0.88)
	bubble_style.set_content_margin_all(12)
	bubble_style.corner_radius_top_left = 12
	bubble_style.corner_radius_top_right = 12
	bubble_style.corner_radius_bottom_left = 4
	bubble_style.corner_radius_bottom_right = 12
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
	# Wait one frame for size to calculate, then center
	await get_tree().process_frame
	_update_bubble_position()


func hide_bubble() -> void:
	bubble.visible = false
	bubble_timer.stop()


func _update_bubble_position() -> void:
	if not bubble.visible:
		return
	bubble.position = Vector2(80, -30)


func _on_bubble_timeout() -> void:
	hide_bubble()


func _setup_idle_murmur() -> void:
	_idle_murmur_timer = Timer.new()
	_idle_murmur_timer.one_shot = true
	_idle_murmur_timer.timeout.connect(_on_idle_murmur_timeout)
	add_child(_idle_murmur_timer)


func _schedule_next_murmur() -> void:
	_idle_murmur_timer.start(randf_range(15.0, 35.0))


func _on_idle_murmur_timeout() -> void:
	if not visible:
		return
	if player_nearby or bubble.visible or DialogueUI.is_dialogue_active():
		_schedule_next_murmur()
		return
	var msg := _murmurs[randi() % _murmurs.size()]
	show_bubble(msg)
	_schedule_next_murmur()


func _on_body_entered(body: Node2D) -> void:
	if body.name == "TimeAunote":
		player_nearby = true
		DialogueUI.show_prompt(npc_id, npc_name)


func _on_body_exited(body: Node2D) -> void:
	if body.name == "TimeAunote":
		player_nearby = false
		DialogueUI.hide_prompt()


func stop_idle() -> void:
	_idle_murmur_timer.stop()
	hide_bubble()


func apparition(position: Vector2) -> void:
	pnj_hub_animation.animation = "idle"
	self.position = position
	show()
	_schedule_next_murmur()


func get_npc_id() -> String:
	return npc_id


func get_npc_name() -> String:
	return npc_name
