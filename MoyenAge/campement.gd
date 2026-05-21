extends Node2D

# Points de Vie
var player_max_hp := 5
var player_hp := 5
var assassin_max_hp := 100
var assassin_hp := 100

# États du combat
var is_combat_active := false
var is_player_stunned := false
var stun_timer := 0.0
var attack_cooldown := 0.0

var player_action := "idle" # "idle", "attack", "defense"
var assassin_posture := "idle" # "idle", "defense", "attack"

var attack_timer := 0.0
var attack_evaluated := false
var posture_timer := 0.0

# Secousse de l'écran
var _shake_amount := 0.0
var _bg_default_pos := Vector2(1213.5, 808)

# Références des nœuds
@onready var campement_sprite: Sprite2D = $campement
@onready var epee_bouclier_sprite: Sprite2D = $epee_bouclier
@onready var combat_ui: CanvasLayer = $CombatUI
@onready var status_label: Label = $CombatUI/Control/StatusLabel
@onready var stun_label: Label = $CombatUI/Control/StunLabel
@onready var player_hp_bar: ProgressBar = $CombatUI/Control/PlayerHPBar
@onready var player_hp_label: Label = $CombatUI/Control/PlayerHPLabel
@onready var assassin_hp_bar: ProgressBar = $CombatUI/Control/AssassinHPBar
@onready var assassin_hp_label: Label = $CombatUI/Control/AssassinHPLabel
@onready var screen_flash: ColorRect = $CombatUI/Control/ScreenFlash

# Assassin instancié
var pnj_assassin: Node2D = null

func _ready() -> void:
	hide()
	combat_ui.hide()
	screen_flash.modulate.a = 0.0
	stun_label.visible = false

func start_combat() -> void:
	# Initialisation
	player_hp = player_max_hp
	assassin_hp = assassin_max_hp
	is_combat_active = true
	is_player_stunned = false
	stun_timer = 0.0
	attack_cooldown = 0.0
	_shake_amount = 0.0
	attack_evaluated = false
	
	# Instancier ou récupérer l'assassin
	if not pnj_assassin:
		var assassin_scene = load("res://MoyenAge/assassin.tscn")
		pnj_assassin = assassin_scene.instantiate()
		pnj_assassin.name = "AssassinCombat"
		add_child(pnj_assassin)
		# Placer l'assassin au second plan au centre du campement
		pnj_assassin.position = Vector2(1214, 850)
		pnj_assassin.scale = Vector2(1.8, 1.8)
		# S'assurer qu'il n'a pas la logique de dialogue dans ce mode
		if pnj_assassin.has_node("ZoneDialogue"):
			pnj_assassin.get_node("ZoneDialogue").queue_free()
	
	pnj_assassin.show()
	var animated_sprite = pnj_assassin.get_node("AnimatedSprite2D") as AnimatedSprite2D
	animated_sprite.play("default")
	
	# Cacher la fenêtre d'objectifs du parent
	var parent_ma_start = get_parent()
	if parent_ma_start and parent_ma_start.has_node("ObjectiveHUD"):
		parent_ma_start.get_node("ObjectiveHUD").hide()

	# Configurer les sprites de premier plan (grand z-index et grande taille pour occuper l'écran)
	epee_bouclier_sprite.z_index = 10
	epee_bouclier_sprite.position = Vector2(1213.5, 808)
	epee_bouclier_sprite.scale = Vector2(4.4, 4.4)
	_set_weapon_sprite("idle")
	epee_bouclier_sprite.show()
	
	# Configurer l'UI
	player_hp_bar.max_value = player_max_hp
	assassin_hp_bar.max_value = assassin_max_hp
	_update_hp_ui()
	status_label.text = "Le combat commence ! Parez avec A/Q, attaquez avec E."
	status_label.add_theme_color_override("font_color", Color.WHITE)
	combat_ui.show()
	show()
	
	# Lancer le timer de posture
	posture_timer = randf_range(1.5, 2.5)
	assassin_posture = "idle"

func _process(delta: float) -> void:
	if not is_combat_active:
		return
	
	# Gérer la secousse d'écran
	if _shake_amount > 0.0:
		campement_sprite.position = _bg_default_pos + Vector2(randf_range(-_shake_amount, _shake_amount), randf_range(-_shake_amount, _shake_amount))
		_shake_amount -= delta * 30.0
		if _shake_amount <= 0.0:
			campement_sprite.position = _bg_default_pos
			
	# Gérer l'étourdissement du joueur
	if is_player_stunned:
		stun_timer -= delta
		if stun_timer <= 0.0:
			is_player_stunned = false
			stun_label.visible = false
			status_label.text = "Vous avez récupéré de l'étourdissement !"
			status_label.add_theme_color_override("font_color", Color.WHITE)
		else:
			stun_label.visible = true
			stun_label.text = "ÉTOURDI ! (%d s)" % clampi(ceil(stun_timer), 1, 3)
			_set_weapon_sprite("idle")
			player_action = "idle"
			_handle_assassin_logic(delta)
			return

	# Gérer le cooldown de l'attaque joueur
	if attack_cooldown > 0.0:
		attack_cooldown -= delta
		_set_weapon_sprite("attack")
		player_action = "attack"
	else:
		# Gérer la parade (bouton maintenu)
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_Q):
			_set_weapon_sprite("defense")
			player_action = "defense"
		else:
			_set_weapon_sprite("idle")
			player_action = "idle"
			
	# Entrée de l'attaque
	if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_E):
		# Empêcher le spam si en cooldown
		if attack_cooldown <= 0.0:
			_perform_attack()

	_handle_assassin_logic(delta)

func _handle_assassin_logic(delta: float) -> void:
	# Gérer l'attaque en cours de l'assassin
	if assassin_posture == "attack" and not attack_evaluated:
		attack_timer -= delta
		if attack_timer <= 0.0:
			attack_evaluated = true
			if player_action == "defense":
				_play_sound("res://audio/combat/sword_clash.1.ogg")
				_flash_screen(Color(1.0, 1.0, 1.0, 0.3))
				_shake_screen(8.0)
				status_label.text = "Coup paré ! Vous bloquez l'assassin !"
				status_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
				# L'assassin retourne direct en idle après avoir été paré
				_change_assassin_posture("idle")
			else:
				_damage_player()
				_change_assassin_posture("idle")
				
	# Gérer le changement de posture
	posture_timer -= delta
	if posture_timer <= 0.0:
		_choose_random_posture()

func _choose_random_posture() -> void:
	var rand := randf()
	if assassin_hp < 50:
		# Mode rage : l'assassin se défend plus souvent (55% de chance)
		if rand < 0.15:
			_change_assassin_posture("idle")
		elif rand < 0.70:
			_change_assassin_posture("defense")
		else:
			_change_assassin_posture("attack")
	else:
		# Mode normal
		if rand < 0.35:
			_change_assassin_posture("idle")
		elif rand < 0.70:
			_change_assassin_posture("defense")
		else:
			_change_assassin_posture("attack")

func _change_assassin_posture(new_posture: String) -> void:
	assassin_posture = new_posture
	
	if assassin_hp < 50:
		posture_timer = randf_range(1.2, 2.0) # Change de posture plus rapidement en mode rage
	else:
		posture_timer = randf_range(2.0, 3.0)
	
	if not pnj_assassin:
		return
		
	var animated_sprite = pnj_assassin.get_node("AnimatedSprite2D") as AnimatedSprite2D
	
	match assassin_posture:
		"idle":
			animated_sprite.play("default")
			if assassin_hp < 50:
				status_label.text = "L'assassin baisse sa garde ! VITE, ATTAQUEZ SPAM !"
				status_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
			else:
				status_label.text = "L'assassin baisse sa garde ! Attaquez !"
				status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		"defense":
			animated_sprite.play("defense")
			if assassin_hp < 50:
				status_label.text = "RAGE : L'assassin est en posture défensive !"
				status_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
			else:
				status_label.text = "L'assassin lève sa garde ! Ne l'attaquez pas !"
				status_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.3))
		"attack":
			animated_sprite.play("attaque")
			animated_sprite.frame = 0
			if assassin_hp < 50:
				status_label.text = "⚠️ RAGE ! COUP FOUDROYANT ! (0.5s)"
				status_label.add_theme_color_override("font_color", Color(1.0, 0.1, 0.1))
				attack_timer = 0.5 # Attaque deux fois plus rapide en mode rage !
			else:
				status_label.text = "ATTENTION ! L'assassin va attaquer !"
				status_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
				attack_timer = 1.0
			attack_evaluated = false
			# Un petit flash rouge d'avertissement
			_flash_screen(Color(1.0, 0.0, 0.0, 0.15))

func _perform_attack() -> void:
	attack_cooldown = 0.3
	_set_weapon_sprite("attack")
	
	_play_sound("res://audio/combat/sword_swing_1.ogg")
	
	match assassin_posture:
		"idle":
			_damage_assassin()
		"defense":
			_stun_player()
		"attack":
			# Attaquer pendant qu'il charge permet de le toucher, mais on prend le coup aussi si on ne pare pas à la fin !
			_damage_assassin()

func _damage_assassin() -> void:
	assassin_hp -= 1
	_play_sound("res://audio/combat/sword_swing_3.ogg")
	_shake_screen(12.0)
	_flash_node(pnj_assassin, Color(1.5, 0.3, 0.3)) # Flash rouge
	_update_hp_ui()
	
	if assassin_hp <= 0:
		_victory()
	else:
		status_label.text = "Vous touchez l'assassin ! (-1 PV)"
		status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))

func _damage_player() -> void:
	player_hp -= 1
	_play_sound("res://audio/combat/sword_clash.3.ogg")
	_shake_screen(25.0)
	_flash_screen(Color(1.0, 0.0, 0.0, 0.5)) # Gros flash rouge
	_update_hp_ui()
	
	if player_hp <= 0:
		_defeat()
	else:
		status_label.text = "L'assassin vous frappe ! (-1 PV)"
		status_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))

func _stun_player() -> void:
	is_player_stunned = true
	stun_timer = 3.0
	attack_cooldown = 0.0
	_play_sound("res://audio/combat/sword_clash.5.ogg")
	_shake_screen(15.0)
	_flash_screen(Color(1.0, 0.5, 0.0, 0.35)) # Flash orange
	_update_hp_ui()
	status_label.text = "PARÉ ! L'assassin bloque votre coup et vous étourdit !"
	status_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0))

func _set_weapon_sprite(state: String) -> void:
	match state:
		"idle":
			epee_bouclier_sprite.texture = load("res://art/MoyenAge/epee_bouclier.png")
		"defense":
			epee_bouclier_sprite.texture = load("res://art/MoyenAge/epee_bouclier_defense.png")
		"attack":
			epee_bouclier_sprite.texture = load("res://art/MoyenAge/epee_bouclier_attaque.png")

func _update_hp_ui() -> void:
	player_hp_bar.value = player_hp
	player_hp_label.text = "Joueur : %d / %d" % [player_hp, player_max_hp]
	
	assassin_hp_bar.value = assassin_hp
	assassin_hp_label.text = "Assassin : %d / %d" % [assassin_hp, assassin_max_hp]

func _flash_screen(color: Color) -> void:
	screen_flash.color = color
	screen_flash.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(screen_flash, "modulate:a", 0.0, 0.4)

func _flash_node(node: Node2D, color: Color) -> void:
	if not node:
		return
	node.modulate = color
	var tween := create_tween()
	tween.tween_property(node, "modulate", Color(1, 1, 1), 0.25)

func _shake_screen(amount: float) -> void:
	_shake_amount = amount

func _play_sound(path: String) -> void:
	if ResourceLoader.exists(path):
		var player := AudioStreamPlayer.new()
		player.stream = load(path)
		player.bus = "Master"
		player.volume_db = -6.0
		add_child(player)
		player.play()
		player.finished.connect(player.queue_free)

func _victory() -> void:
	is_combat_active = false
	status_label.text = "VICTOIRE ! L'assassin est vaincu !"
	status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	_play_sound("res://audio/combat/victory_fanfare.ogg")
	
	# Terminer la quête
	DialogueSystem.complete_step("quete_piste_assassin", "etape_trouver_assassin")
	
	# Animation de fondu noir et retour au hub
	var parent_ma = get_parent()
	if parent_ma and parent_ma.has_node("fade_layer"):
		# Utiliser le fade de MoyenAge
		var fade_rect_node = parent_ma.fade_rect
		var tween := create_tween()
		tween.tween_property(fade_rect_node, "modulate:a", 1.0, 1.5)
		await tween.finished
		
		# Afficher le message sur l'écran noir
		var label := Label.new()
		label.text = "la distorsion semble plus stable..."
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font", SystemFont.new())
		label.add_theme_font_size_override("font_size", 28)
		label.add_theme_color_override("font_color", Color(0, 0.8, 1, 1))
		label.size = get_viewport_rect().size
		parent_ma.fade_layer.add_child(label)
		
		await get_tree().create_timer(2.0).timeout
		label.queue_free()
		
		# Arrêter le combat et retourner au hub
		parent_ma.stop()
		var main = get_tree().current_scene
		if main and main.has_method("warp_to_era"):
			main.warp_to_era("hub", "entree")
			# Remettre le fade à 0
			create_tween().tween_property(fade_rect_node, "modulate:a", 0.0, 1.0)

func _defeat() -> void:
	is_combat_active = false
	status_label.text = "DÉFAITE !"
	status_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	
	var parent_ma = get_parent()
	if parent_ma:
		var fade_rect_node = parent_ma.fade_rect
		var tween := create_tween()
		tween.tween_property(fade_rect_node, "modulate:a", 1.0, 1.0)
		await tween.finished
		
		# Créer le message sur l'écran noir
		var label := Label.new()
		label.text = "vous êtes sauvés par la distorsion..."
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font", SystemFont.new())
		label.add_theme_font_size_override("font_size", 32)
		label.add_theme_color_override("font_color", Color(0, 0.8, 1, 1))
		label.size = get_viewport_rect().size
		parent_ma.fade_layer.add_child(label)
		
		await get_tree().create_timer(3.0).timeout
		if not is_inside_tree():
			return
		
		label.queue_free()
		
		# Cacher l'arène de combat et restaurer la forêt
		hide()
		combat_ui.hide()
		
		# Réinitialiser la forêt et replacer le joueur
		parent_ma.foret.show()
		var static_foret = parent_ma.foret.get_node_or_null("StaticBody2D")
		if static_foret:
			static_foret.collision_layer = 4
			
		# Réactiver la zone d'interaction du PNJ assassin pour pouvoir relancer le dialogue
		var forest_assassin = parent_ma.foret.get_node_or_null("markers2D/assassin/assassin")
		if forest_assassin and forest_assassin.has_node("ZoneDialogue"):
			forest_assassin.get_node("ZoneDialogue").monitoring = true
			
		# Rendre le joueur à nouveau visible et actif
		parent_ma.time_aunote.show()
		parent_ma.time_aunote.modulate.a = 1.0
		parent_ma.time_aunote.scale = Vector2(0.8, 0.8)
		parent_ma.time_aunote.rotation = 0.0
		var col_node := parent_ma.time_aunote.get_node("collision") as CollisionShape2D
		if col_node:
			col_node.disabled = false
			
		parent_ma.time_aunote.global_position = parent_ma.foret.get_node("markers2D/apparition").global_position
		parent_ma.can_move = true
		parent_ma._play_zone_audio("parc")
		if parent_ma.has_node("ObjectiveHUD"):
			parent_ma.get_node("ObjectiveHUD").show()
		parent_ma._update_objective("Trouver l'assassin dans la forêt")
		
		# Fondu de retour
		var tween_back := create_tween()
		tween_back.tween_property(fade_rect_node, "modulate:a", 0.0, 1.0)
