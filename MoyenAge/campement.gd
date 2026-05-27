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

var assassin_stunned := false
var assassin_stun_timer := 0.0

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
@onready var etourdi_sprite: AnimatedSprite2D = $etourdi

# Assassin instancié
var pnj_assassin: Node2D = null

func _ready() -> void:
	hide()
	combat_ui.hide()
	screen_flash.modulate.a = 0.0
	stun_label.visible = false
	etourdi_sprite.hide()
	etourdi_sprite.stop()

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
	assassin_stunned = false
	assassin_stun_timer = 0.0
	etourdi_sprite.hide()
	etourdi_sprite.stop()
	
	# Instancier ou récupérer l'assassin
	if not pnj_assassin:
		var assassin_scene = load("res://MoyenAge/assassin.tscn")
		pnj_assassin = assassin_scene.instantiate()
		pnj_assassin.name = "AssassinCombat"
		add_child(pnj_assassin)
		# S'assurer qu'il n'a pas la logique de dialogue dans ce mode
		if pnj_assassin.has_node("ZoneDialogue"):
			pnj_assassin.get_node("ZoneDialogue").queue_free()
	
	# Placer et mettre à l'échelle l'assassin (plus grand et plus bas)
	pnj_assassin.position = Vector2(1214, 915)
	pnj_assassin.scale = Vector2(2.5, 2.5)
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
			
	# Gérer l'étourdissement de l'assassin
	if assassin_stunned:
		etourdi_sprite.show()
		if pnj_assassin:
			etourdi_sprite.position = pnj_assassin.position - Vector2(0, 140)
		if not etourdi_sprite.is_playing():
			etourdi_sprite.play()
		assassin_stun_timer -= delta
		if assassin_stun_timer <= 0.0:
			assassin_stunned = false
			etourdi_sprite.hide()
			etourdi_sprite.stop()
			status_label.text = ""
		else:
			pass # Le timer continue, l'assassin reste étourdi
	else:
		etourdi_sprite.hide()
		etourdi_sprite.stop()

	# Gérer l'étourdissement du joueur
	if is_player_stunned:
		stun_timer -= delta
		if stun_timer <= 0.0:
			is_player_stunned = false
			stun_label.visible = false
			status_label.text = ""
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
				status_label.text = ""
				# L'assassin est étourdi : il n'attaque pas pendant 3s
				assassin_stunned = true
				assassin_stun_timer = 3.0
				_change_assassin_posture("idle")
			else:
				_damage_player()
				_change_assassin_posture("idle")
				
	# Gérer le changement de posture (l'assassin étourdi ne change pas)
	if not assassin_stunned:
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
			status_label.text = ""
		"defense":
			animated_sprite.play("defense")
			status_label.text = ""
		"attack":
			animated_sprite.play("attaque")
			animated_sprite.frame = 0
			status_label.text = ""
			if assassin_hp < 50:
				attack_timer = 0.5 # Attaque deux fois plus rapide en mode rage !
			else:
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
	var dmg := 1
	if assassin_stunned:
		dmg = 2
		
	assassin_hp -= dmg
	_play_sound("res://audio/combat/sword_swing_3.ogg")
	_shake_screen(12.0)
	_flash_node(pnj_assassin, Color(1.5, 0.3, 0.3)) # Flash rouge
	_update_hp_ui()
	
	if assassin_hp <= 0:
		_victory()
	else:
		if assassin_stunned:
			status_label.text = "CRITIQUE ! -2 PV"
		else:
			status_label.text = ""


func _damage_player() -> void:
	player_hp -= 1
	_play_sound("res://audio/combat/sword_clash.3.ogg")
	_shake_screen(25.0)
	_flash_screen(Color(1.0, 0.0, 0.0, 0.5)) # Gros flash rouge
	_update_hp_ui()
	
	if player_hp <= 0:
		_defeat()
	else:
		status_label.text = ""

func _stun_player() -> void:
	is_player_stunned = true
	stun_timer = 3.0
	attack_cooldown = 0.0
	_play_sound("res://audio/combat/sword_clash.5.ogg")
	_shake_screen(15.0)
	_flash_screen(Color(1.0, 0.5, 0.0, 0.35)) # Flash orange
	_update_hp_ui()
	status_label.text = ""

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
	var target_path := path
	if not ResourceLoader.exists(target_path):
		# Fallbacks malins basés sur les fichiers audio existants dans le projet
		match path:
			"res://audio/combat/sword_swing_1.ogg":
				target_path = "res://audio/marchandage/miss/miss01.mp3" # Magnifique son de "whoosh" (tranchant d'épée)
			"res://audio/combat/sword_swing_3.ogg":
				target_path = "res://audio/crochetage/success/success_click.mp3" # Impact clair et net pour un coup réussi
			"res://audio/combat/sword_clash.1.ogg":
				target_path = "res://audio/crochetage/final/final_unlock.mp3" # Son métallique lourd "clink-clang" pour la parade au bouclier
			"res://audio/combat/sword_clash.3.ogg":
				target_path = "res://audio/crochetage/failure/failure01.mp3" # Bruit d'impact sourd et lourd pour les dégâts subis
			"res://audio/combat/sword_clash.5.ogg":
				target_path = "res://audio/marchandage/decoy/decoy_error.mp3" # Buzz de désorientation pour l'étourdissement du joueur
			"res://audio/combat/victory_fanfare.ogg":
				target_path = "res://audio/crochetage/final/final_unlock.mp3" # Fanfare de déblocage pour la victoire

	if ResourceLoader.exists(target_path):
		var player := AudioStreamPlayer.new()
		player.stream = load(target_path)
		player.bus = "Master"
		player.volume_db = -6.0
		add_child(player)
		player.play()
		player.finished.connect(player.queue_free)

func _typewriter_text(label: Label, target_text: String) -> void:
	label.text = ""
	for i in range(target_text.length()):
		if not is_inside_tree():
			return
		label.text += target_text[i]
		await get_tree().create_timer(0.04).timeout

func _victory() -> void:
	if not is_combat_active:
		# Just set dialogue steps and return, don't trigger combat cinematic or crash
		var quest_state = DialogueSystem.game_state.get("quete_piste_assassin")
		if quest_state:
			if quest_state.get("current_step", "") == "etape_enqueter_foret":
				DialogueSystem.complete_step("quete_piste_assassin", "etape_enqueter_foret")
		DialogueSystem.complete_step("quete_piste_assassin", "etape_trouver_assassin")
		return

	is_combat_active = false
	status_label.text = "VICTOIRE ! L'assassin est vaincu !"
	status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	_play_sound("res://audio/combat/victory_fanfare.ogg")
	
	# Terminer la quête
	var quest_state = DialogueSystem.game_state.get("quete_piste_assassin")
	if quest_state:
		if quest_state.get("current_step", "") == "etape_enqueter_foret":
			DialogueSystem.complete_step("quete_piste_assassin", "etape_enqueter_foret")
	DialogueSystem.complete_step("quete_piste_assassin", "etape_trouver_assassin")
	
	# Masquer l'UI de combat pour laisser place à la cinématique
	combat_ui.hide()
	epee_bouclier_sprite.hide()
	if pnj_assassin:
		pnj_assassin.hide()
	
	# Animation de fondu noir
	var parent_ma = get_parent()
	if parent_ma and parent_ma.fade_layer and parent_ma.fade_rect:
		var fade_rect_node = parent_ma.fade_rect
		var fade_tween := create_tween()
		fade_tween.tween_property(fade_rect_node, "modulate:a", 1.0, 1.5)
		await fade_tween.finished
		
		if not is_inside_tree():
			return
			
		# Obtenir la taille de l'écran avec une valeur de repli sécurisée
		var viewport_size := get_viewport_rect().size
		if viewport_size.x <= 0 or viewport_size.y <= 0:
			viewport_size = Vector2(1024, 682)
			
		# Créer le conteneur principal de la cinématique
		var cinematic_container := Control.new()
		cinematic_container.size = viewport_size
		cinematic_container.clip_contents = true
		parent_ma.fade_layer.add_child(cinematic_container)
		parent_ma.fade_layer.move_child(cinematic_container, 0) # Placer sous fade_rect
		
		# Fond noir sous les images
		var bg_rect := ColorRect.new()
		bg_rect.color = Color.BLACK
		bg_rect.size = viewport_size
		cinematic_container.add_child(bg_rect)
		
		# Clipper pour masquer les bords débordants des images zoomées
		var image_clipper := Control.new()
		image_clipper.size = viewport_size
		image_clipper.clip_contents = true
		cinematic_container.add_child(image_clipper)
		
		# 1. Première image (cinematique_MA1.png) - Panoramique droite -> gauche sans déformation
		var tex_rect1 := TextureRect.new()
		var tex1 := load("res://art/MoyenAge/cinematique_MA1.png") as Texture2D
		tex_rect1.texture = tex1
		tex_rect1.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect1.stretch_mode = TextureRect.STRETCH_SCALE
		
		# Calculer la taille en conservant l'aspect ratio exact (basé sur la hauteur du viewport)
		var aspect_ratio1 := float(tex1.get_width()) / float(tex1.get_height())
		var tex_height1 := viewport_size.y
		var tex_width1 := tex_height1 * aspect_ratio1
		tex_rect1.size = Vector2(tex_width1, tex_height1)
		
		var start_x1 := -(tex_width1 - viewport_size.x)
		var end_x1 := 0.0
		tex_rect1.position = Vector2(start_x1, 0.0)
		image_clipper.add_child(tex_rect1)
		
		# Zone de sous-titre premium avec contours bleutés
		var subtitles_bg := Panel.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0.75)
		style.corner_radius_top_left = 12
		style.corner_radius_top_right = 12
		style.corner_radius_bottom_left = 12
		style.corner_radius_bottom_right = 12
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(0, 0.8, 1.0, 0.4) # Couleur distortion
		subtitles_bg.add_theme_stylebox_override("panel", style)
		
		var bg_width := viewport_size.x * 0.85
		var bg_height := 120.0
		subtitles_bg.size = Vector2(bg_width, bg_height)
		subtitles_bg.position = Vector2(
			(viewport_size.x - bg_width) / 2.0,
			viewport_size.y - bg_height - 40.0
		)
		subtitles_bg.modulate.a = 0.0
		cinematic_container.add_child(subtitles_bg)
		
		var subtitles_label := Label.new()
		subtitles_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		subtitles_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitles_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		subtitles_label.size = subtitles_bg.size - Vector2(40, 20)
		subtitles_label.position = Vector2(20, 10)
		subtitles_label.add_theme_font_override("font", SystemFont.new())
		subtitles_label.add_theme_font_size_override("font_size", 20)
		subtitles_label.add_theme_color_override("font_color", Color.WHITE)
		subtitles_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		subtitles_label.add_theme_constant_override("shadow_offset_x", 2)
		subtitles_label.add_theme_constant_override("shadow_offset_y", 2)
		subtitles_bg.add_child(subtitles_label)
		
		# --- Phase 1 : Lancement de la première scène ---
		# Rétablir le fondu de MoyenAge pour faire apparaître l'image
		var tween_in1 := create_tween()
		tween_in1.tween_property(fade_rect_node, "modulate:a", 0.0, 1.5)
		
		# Lancer le mouvement lent droite -> gauche
		var pan_tween1 := create_tween()
		pan_tween1.set_ease(Tween.EASE_IN_OUT)
		pan_tween1.set_trans(Tween.TRANS_SINE)
		pan_tween1.tween_property(tex_rect1, "position:x", end_x1, 9.0)
		
		# Faire apparaître la boîte de sous-titres
		var bg_tween1 := create_tween()
		bg_tween1.tween_property(subtitles_bg, "modulate:a", 1.0, 0.8)
		await bg_tween1.finished
		
		if not is_inside_tree():
			return
			
		# Écrire le texte de victoire face à l'assassin
		await _typewriter_text(subtitles_label, "Vous avez terrassé l'assassin. La ligne temporelle de cette époque est désormais hors de danger.")
		
		if not is_inside_tree():
			return
			
		# Attendre la fin du panoramique
		await get_tree().create_timer(2.0).timeout
		if pan_tween1.is_running():
			await pan_tween1.finished
			
		if not is_inside_tree():
			return
			
		# Disparition des sous-titres
		var bg_fadeout1 := create_tween()
		bg_fadeout1.tween_property(subtitles_bg, "modulate:a", 0.0, 0.6)
		await bg_fadeout1.finished
		
		subtitles_label.text = ""
		
		if not is_inside_tree():
			return
			
		# --- Phase 2 : Deuxième image (cinematique_MA2.png) - Panoramique gauche -> droite ---
		var tex_rect2 := TextureRect.new()
		var tex2 := load("res://art/MoyenAge/cinematique_MA2.png") as Texture2D
		tex_rect2.texture = tex2
		tex_rect2.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect2.stretch_mode = TextureRect.STRETCH_SCALE
		
		# Calculer la taille en conservant l'aspect ratio exact (basé sur la hauteur du viewport)
		var aspect_ratio2 := float(tex2.get_width()) / float(tex2.get_height())
		var tex_height2 := viewport_size.y
		var tex_width2 := tex_height2 * aspect_ratio2
		tex_rect2.size = Vector2(tex_width2, tex_height2)
		tex_rect2.modulate.a = 0.0
		
		var start_x2 := 0.0
		var end_x2 := -(tex_width2 - viewport_size.x)
		tex_rect2.position = Vector2(start_x2, 0.0)
		image_clipper.add_child(tex_rect2)
		
		# Transition en fondu enchaîné (Cross-fade)
		var cross_fade := create_tween()
		cross_fade.tween_property(tex_rect2, "modulate:a", 1.0, 1.5)
		
		# Lancer le mouvement lent gauche -> droite
		var pan_tween2 := create_tween()
		pan_tween2.set_ease(Tween.EASE_IN_OUT)
		pan_tween2.set_trans(Tween.TRANS_SINE)
		pan_tween2.tween_property(tex_rect2, "position:x", end_x2, 9.0)
		
		await cross_fade.finished
		if not is_inside_tree():
			return
			
		# Libérer la première texture pour économiser la mémoire
		tex_rect1.queue_free()
		
		# Faire réapparaître les sous-titres
		var bg_tween2 := create_tween()
		bg_tween2.tween_property(subtitles_bg, "modulate:a", 1.0, 0.8)
		await bg_tween2.finished
		
		if not is_inside_tree():
			return
			
		# Écrire le texte sur la stabilité de la distorsion et le retour au nexus
		await _typewriter_text(subtitles_label, "La distorsion semble plus stable et nous pouvons retourner au nexus maintenant.")
		
		if not is_inside_tree():
			return
			
		# Laisser le temps de lire puis fondu au noir final
		await get_tree().create_timer(3.0).timeout
		
		if not is_inside_tree():
			return
			
		var fade_out_tween := create_tween()
		fade_out_tween.tween_property(fade_rect_node, "modulate:a", 1.0, 1.5)
		await fade_out_tween.finished
		
		if not is_inside_tree():
			return
			
		# Nettoyage et transition finale
		cinematic_container.queue_free()
		fade_rect_node.modulate.a = 0.0
		
		var main = get_tree().current_scene
		if main and main.has_method("warp_to_era"):
			main.warp_to_era("hub", "entree")
	else:
		# Repli si les nodes de fondu du parent ne sont pas trouvés
		var main = get_tree().current_scene
		if main and main.has_method("warp_to_era"):
			main.warp_to_era("hub", "entree")

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
		
		# Recommencer le combat directement de zéro (pv au max)
		start_combat()
		
		# Fondu de retour
		var tween_back := create_tween()
		tween_back.tween_property(fade_rect_node, "modulate:a", 0.0, 1.0)
