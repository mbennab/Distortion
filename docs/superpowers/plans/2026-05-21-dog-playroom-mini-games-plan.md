# Nexus Dog Playroom Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single-game receiver with a multi-game hub ("Nexus Dog Playroom") containing retro Tic-Tac-Toe and Pong games played directly against the dog, fully centered and responsive.

**Architecture:** A single, clean, self-contained CanvasLayer script (`MiniJeuChien.gd`) managing a GameState enum (MENU, MORPION, PONG). All gameplay renderings are procedurally drawn via `_draw()`, utilizing existing dog audio bark resources and era particles.

**Tech Stack:** Godot 4.6 standard, GDScript only, custom vector drawing.

---

## File Structure Mapout
- **Modify**: `res://HUB Central/MiniJeuChien.gd` (Overwritten entirely to house the playroom selection, state machine, Morpion AI/draw, and Pong physics/draw).
- **Verify**: Headless Godot syntax checker (`/home/rimbaud/GODOT/godot --headless --check-only`).

---

### Task 1: Playroom Hub Core & State Machine

**Files:**
- Modify: `res://HUB Central/MiniJeuChien.gd`

- [ ] **Step 1: Write core playroom template**
  Define states, variables, UI components, and the basic dog tail-wagging drawing routine in `MiniJeuChien.gd`.

  Write the following code template:
  ```gdscript
  extends CanvasLayer

  signal game_finished

  enum GameState { MENU, MORPION, PONG }
  var current_state: GameState = GameState.MENU

  var is_active: bool = false

  # UI controls
  var root_control: Control
  var background_panel: Panel
  var scope_control: Control
  var label_status: Label
  var label_score_info: Label
  var btn_quit: Button

  # Menu specific buttons
  var menu_container: VBoxContainer
  var btn_play_morpion: Button
  var btn_play_pong: Button

  # Tail wagging animation helpers
  var animation_time: float = 0.0

  # Sound
  var _audio_player: AudioStreamPlayer
  var _bark_sounds: Array[AudioStream] = []
  var _rng := RandomNumberGenerator.new()

  func _ready() -> void:
  	layer = 100
  	visible = false
  	_rng.randomize()
  	_setup_audio()
  	_setup_ui()

  func _setup_audio() -> void:
  	_audio_player = AudioStreamPlayer.new()
  	_audio_player.bus = "Master"
  	add_child(_audio_player)
  	
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

  func _setup_ui() -> void:
  	root_control = Control.new()
  	root_control.name = "RootControl"
  	root_control.anchor_right = 1.0
  	root_control.anchor_bottom = 1.0
  	add_child(root_control)

  	background_panel = Panel.new()
  	background_panel.name = "BackgroundPanel"
  	background_panel.custom_minimum_size = Vector2(640, 500)
  	background_panel.anchor_left = 0.5
  	background_panel.anchor_right = 0.5
  	background_panel.anchor_top = 0.5
  	background_panel.anchor_bottom = 0.5
  	background_panel.offset_left = -320
  	background_panel.offset_right = 320
  	background_panel.offset_top = -250
  	background_panel.offset_bottom = 250
  	
  	var style := StyleBoxFlat.new()
  	style.bg_color = Color(0.06, 0.04, 0.11, 0.96)
  	style.border_width_left = 3
  	style.border_width_top = 3
  	style.border_width_right = 3
  	style.border_width_bottom = 3
  	style.border_color = Color(0.8, 0.5, 1.0, 0.8) # Purple
  	style.corner_radius_top_left = 8
  	style.corner_radius_top_right = 8
  	style.corner_radius_bottom_left = 8
  	style.corner_radius_bottom_right = 8
  	background_panel.add_theme_stylebox_override("panel", style)
  	root_control.add_child(background_panel)

  	# Title Bar
  	var label_title := Label.new()
  	label_title.text = "🐾 NEXUS DOG PLAYROOM - JOUER AVEC LE CHIEN"
  	label_title.position = Vector2(20, 15)
  	label_title.add_theme_font_size_override("font_size", 16)
  	label_title.add_theme_color_override("font_color", Color(0.8, 0.5, 1.0, 1.0))
  	background_panel.add_child(label_title)

  	# Scope Play Screen
  	scope_control = Control.new()
  	scope_control.position = Vector2(20, 70)
  	scope_control.custom_minimum_size = Vector2(600, 290)
  	scope_control.draw.connect(_on_scope_draw)
  	scope_control.gui_input.connect(_on_scope_gui_input)
  	background_panel.add_child(scope_control)

  	# Bottom Info Panel
  	label_score_info = Label.new()
  	label_score_info.text = "CHOISISSEZ UN MINI-JEU POUR COMMENCER A JOUER"
  	label_score_info.position = Vector2(20, 380)
  	label_score_info.size = Vector2(600, 20)
  	label_score_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  	label_score_info.add_theme_font_size_override("font_size", 13)
  	label_score_info.add_theme_color_override("font_color", Color(0.9, 0.85, 1.0, 0.9))
  	background_panel.add_child(label_score_info)

  	label_status = Label.new()
  	label_status.text = "🟢 PRÊT À AMUSER LE CHIEN"
  	label_status.position = Vector2(20, 405)
  	label_status.size = Vector2(600, 20)
  	label_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  	label_status.add_theme_font_size_override("font_size", 12)
  	label_status.add_theme_color_override("font_color", Color(0.24, 0.95, 0.79, 1.0))
  	background_panel.add_child(label_status)

  	# Main Menu Buttons Container
  	menu_container = VBoxContainer.new()
  	menu_container.position = Vector2(170, 120)
  	menu_container.size = Vector2(300, 140)
  	menu_container.add_theme_constant_override("separation", 15)
  	background_panel.add_child(menu_container)

  	btn_play_morpion = Button.new()
  	btn_play_morpion.text = "🦴 MORPION CANIN (TIC-TAC-TOE)"
  	btn_play_morpion.focus_mode = Control.FOCUS_NONE
  	btn_play_morpion.pressed.connect(_on_play_morpion_pressed)
  	menu_container.add_child(btn_play_morpion)

  	btn_play_pong = Button.new()
  	btn_play_pong.text = "🏓 CHIEN-PONG (ARCADE)"
  	btn_play_pong.focus_mode = Control.FOCUS_NONE
  	btn_play_pong.pressed.connect(_on_play_pong_pressed)
  	menu_container.add_child(btn_play_pong)

  	btn_quit = Button.new()
  	btn_quit.text = "[ ÉCHAP ] RETOUR / QUITTER"
  	btn_quit.position = Vector2(170, 440)
  	btn_quit.size = Vector2(300, 36)
  	btn_quit.focus_mode = Control.FOCUS_NONE
  	btn_quit.pressed.connect(_on_quit_pressed)
  	background_panel.add_child(btn_quit)

  func _process(delta: float) -> void:
  	if not is_active:
  		return
  	animation_time += delta
  	scope_control.queue_redraw()

  func open_game() -> void:
  	is_active = true
  	current_state = GameState.MENU
  	menu_container.visible = true
  	label_score_info.text = "CHOISISSEZ UN MINI-JEU POUR COMMENCER A JOUER"
  	label_status.text = "🟢 PRÊT À AMUSER LE CHIEN"
  	label_status.add_theme_color_override("font_color", Color(0.24, 0.95, 0.79, 1.0))
  	visible = true
  	_play_bark(1.0)

  func close_game() -> void:
  	is_active = false
  	visible = false
  	_audio_player.stop()
  	game_finished.emit()

  func _on_play_morpion_pressed() -> void:
  	pass

  func _on_play_pong_pressed() -> void:
  	pass

  func _on_quit_pressed() -> void:
  	if current_state == GameState.MENU:
  		close_game()
  	else:
  		current_state = GameState.MENU
  		menu_container.visible = true
  		label_score_info.text = "CHOISISSEZ UN MINI-JEU POUR COMMENCER A JOUER"
  		label_status.text = "🟢 DE RETOUR AU MENU"
  		label_status.add_theme_color_override("font_color", Color(0.24, 0.95, 0.79, 1.0))

  func _play_bark(pitch: float) -> void:
  	if _bark_sounds.is_empty():
  		return
  	_audio_player.stream = _bark_sounds[_rng.randi_range(0, _bark_sounds.size() - 1)]
  	_audio_player.pitch_scale = pitch
  	_audio_player.volume_db = 0.0
  	_audio_player.play()

  func _on_scope_draw() -> void:
  	var w := 600.0
  	var h := 290.0
  	scope_control.draw_rect(Rect2(0, 0, w, h), Color(0.02, 0.01, 0.04, 1.0))
  	scope_control.draw_rect(Rect2(0, 0, w, h), Color(0.8, 0.5, 1.0, 0.35), false, 2.0)
  	
  	if current_state == GameState.MENU:
  		_draw_dog_menu(w, h)

  func _draw_dog_menu(w: float, h: float) -> void:
  		# Draw a simple cute procedural dog face at the left
  		var center := Vector2(80, h / 2.0)
  		# Head
  		scope_control.draw_circle(center, 40.0, Color(0.8, 0.5, 1.0, 0.4))
  		scope_control.draw_circle(center, 40.0, Color(0.8, 0.5, 1.0, 0.8), false, 2.0)
  		# Eyes
  		scope_control.draw_circle(center + Vector2(-15, -10), 4.0, Color.WHITE)
  		scope_control.draw_circle(center + Vector2(15, -10), 4.0, Color.WHITE)
  		scope_control.draw_circle(center + Vector2(-15, -10), 2.0, Color.BLACK)
  		scope_control.draw_circle(center + Vector2(15, -10), 2.0, Color.BLACK)
  		# Nose
  		scope_control.draw_circle(center + Vector2(0, 5), 6.0, Color.BLACK)
  		# Wagging Tail at the right
  		var tail_base := Vector2(500, h / 2.0 + 30)
  		var sway := sin(animation_time * 15.0) * 25.0
  		var tail_tip := tail_base + Vector2(cos(deg_to_rad(-45 + sway)), sin(deg_to_rad(-45 + sway))) * 60.0
  		
  		scope_control.draw_line(tail_base, tail_tip, Color(0.8, 0.5, 1.0, 0.3), 16.0)
  		scope_control.draw_line(tail_base, tail_tip, Color(0.8, 0.5, 1.0, 0.95), 6.0)

  func _on_scope_gui_input(event: InputEvent) -> void:
  	pass

  func _input(event: InputEvent) -> void:
  	if not is_active:
  		return
  	if event.is_action_pressed("ui_cancel"):
  		_on_quit_pressed()
  		get_viewport().set_input_as_handled()
  ```

- [ ] **Step 2: Verify headless syntax**
  Run: `/home/rimbaud/GODOT/godot --headless --check-only`
  Expected: Success without errors.

- [ ] **Step 3: Commit Hub core**
  ```bash
  git add "HUB Central/MiniJeuChien.gd"
  git commit -m "feat(dog-playroom): setup GameState machine, base UI and tail wagging animation"
  ```

---

### Task 2: Morpion Canin (Tic-Tac-Toe) Implementation

**Files:**
- Modify: `res://HUB Central/MiniJeuChien.gd`

- [ ] **Step 1: Write Tic-Tac-Toe state & drawing logic**
  Add the variable declarations and drawing logic for grid cells, ball (`🎾`) player symbols, bone (`🦴`) dog symbols, and the crying animation.

  Insert these variables into `MiniJeuChien.gd`:
  ```gdscript
  # Tic-Tac-Toe variables
  var morpion_grid: Array = [0, 0, 0, 0, 0, 0, 0, 0, 0] # 0: empty, 1: player (ball), 2: dog (bone)
  var is_player_turn: bool = true
  var is_morpion_game_over: bool = false
  var morpion_winner: int = 0 # 0: tie/none, 1: player, 2: dog
  var morpion_ai_timer: float = 0.0
  var is_morpion_ai_thinking: bool = false
  ```

  Modify `_on_play_morpion_pressed()` to start the game:
  ```gdscript
  func _on_play_morpion_pressed() -> void:
  	current_state = GameState.MORPION
  	menu_container.visible = false
  	morpion_grid = [0, 0, 0, 0, 0, 0, 0, 0, 0]
  	is_player_turn = true
  	is_morpion_game_over = false
  	morpion_winner = 0
  	is_morpion_ai_thinking = false
  	label_score_info.text = "CLIQUEZ SUR UNE CASE POUR POSER VOTRE BALLE 🎾"
  	label_status.text = "🟢 À VOUS DE JOUER !"
  	label_status.add_theme_color_override("font_color", Color(0.24, 0.95, 0.79, 1.0))
  	_play_bark(1.2)
  ```

  Update `_on_scope_draw()` to call the Morpion render:
  ```gdscript
  # Inside _on_scope_draw() replace check:
  	if current_state == GameState.MENU:
  		_draw_dog_menu(w, h)
  	elif current_state == GameState.MORPION:
  		_draw_morpion(w, h)
  ```

  Implement the `_draw_morpion` method:
  ```gdscript
  func _draw_morpion(w: float, h: float) -> void:
  	# Render 3x3 grid centered in the scope
  	var start_x := 180.0
  	var start_y := 25.0
  	var size := 240.0
  	var step := 80.0
  	
  	# Outer border
  	scope_control.draw_rect(Rect2(start_x, start_y, size, size), Color(0.8, 0.5, 1.0, 0.25), false, 2.0)
  	
  	# Grid Lines
  	scope_control.draw_line(Vector2(start_x + step, start_y), Vector2(start_x + step, start_y + size), Color(0.8, 0.5, 1.0, 0.6), 2.0)
  	scope_control.draw_line(Vector2(start_x + step * 2, start_y), Vector2(start_x + step * 2, start_y + size), Color(0.8, 0.5, 1.0, 0.6), 2.0)
  	scope_control.draw_line(Vector2(start_x, start_y + step), Vector2(start_x + size, start_y + step), Color(0.8, 0.5, 1.0, 0.6), 2.0)
  	scope_control.draw_line(Vector2(start_x, start_y + step * 2), Vector2(start_x + size, start_y + step * 2), Color(0.8, 0.5, 1.0, 0.6), 2.0)
  	
  	# Draw Symbols
  	for idx in range(9):
  		var gx := idx % 3
  		var gy := idx / 3
  		var cell_center := Vector2(start_x + gx * step + step / 2.0, start_y + gy * step + step / 2.0)
  		var val: int = morpion_grid[idx]
  		
  		if val == 1: # Player ball 🎾
  			scope_control.draw_circle(cell_center, 22.0, Color(0.24, 0.95, 0.79, 1.0))
  			scope_control.draw_circle(cell_center, 22.0, Color.WHITE, false, 1.5)
  		elif val == 2: # Dog bone 🦴
  			# Procedural Bone drawing: a line with circles at endpoints
  			var left := cell_center + Vector2(-15, -10)
  			var right := cell_center + Vector2(15, 10)
  			scope_control.draw_line(left, right, Color.WHITE, 6.0)
  			scope_control.draw_circle(left, 7.0, Color.WHITE)
  			scope_control.draw_circle(left + Vector2(0, 8), 5.0, Color.WHITE)
  			scope_control.draw_circle(right, 7.0, Color.WHITE)
  			scope_control.draw_circle(right - Vector2(0, 8), 5.0, Color.WHITE)
  			
  	# Cute animations for results
  	if is_morpion_game_over:
  		var info_center := Vector2(80, h / 2.0)
  		# Draw dog head expressing win or loss
  		scope_control.draw_circle(info_center, 35.0, Color(0.8, 0.5, 1.0, 0.4))
  		scope_control.draw_circle(info_center, 35.0, Color(0.8, 0.5, 1.0, 0.8), false, 2.0)
  		# Dog crying tears if lost
  		if morpion_winner == 1:
  			var tear_y := (sin(animation_time * 8.0) * 10.0) + 10.0
  			scope_control.draw_circle(info_center + Vector2(-10, tear_y), 3.0, Color(0.2, 0.6, 1.0, 0.85))
  			scope_control.draw_circle(info_center + Vector2(10, tear_y), 3.0, Color(0.2, 0.6, 1.0, 0.85))
  		# Dog happy tail wag if won
  		elif morpion_winner == 2:
  			var sway := sin(animation_time * 30.0) * 35.0
  			var tail_base := info_center + Vector2(30, 20)
  			var tail_tip := tail_base + Vector2(cos(deg_to_rad(sway)), sin(deg_to_rad(sway))) * 40.0
  			scope_control.draw_line(tail_base, tail_tip, Color(0.8, 0.5, 1.0, 0.9), 6.0)
  ```

- [ ] **Step 2: Add player clicks and AI thinking timers**
  Implement the user grid interaction inside `_on_scope_gui_input` and state machine updates in `_process`.

  Insert this into `_process()`:
  ```gdscript
  	# Inside _process() below not active check:
  	if current_state == GameState.MORPION and is_morpion_ai_thinking:
  		morpion_ai_timer -= delta
  		if morpion_ai_timer <= 0.0:
  			_make_morpion_dog_move()
  ```

  Insert this into `_on_scope_gui_input()`:
  ```gdscript
  	if not is_active:
  		return
  	if current_state == GameState.MORPION:
  		if is_morpion_game_over or not is_player_turn or is_morpion_ai_thinking:
  			# Click to restart if game over
  			if is_morpion_game_over and event is InputEventMouseButton and event.pressed:
  				_on_play_morpion_pressed()
  				get_viewport().set_input_as_handled()
  			return
  			
  		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
  			var start_x := 180.0
  			var start_y := 25.0
  			var step := 80.0
  			
  			var mpos := event.position
  			if mpos.x >= start_x and mpos.x < start_x + 240.0 and mpos.y >= start_y and mpos.y < start_y + 240.0:
  				var gx := int((mpos.x - start_x) / step)
  				var gy := int((mpos.y - start_y) / step)
  				var idx := gy * 3 + gx
  				
  				if morpion_grid[idx] == 0:
  					morpion_grid[idx] = 1 # Place tennis ball
  					_play_bark(1.4)
  					_check_morpion_game_state()
  					
  					if not is_morpion_game_over:
  						is_player_turn = false
  						is_morpion_ai_thinking = true
  						morpion_ai_timer = 0.7
  						label_score_info.text = "🐾 LE CHIEN FLAIRE LE PLATEAU..."
  						label_status.text = "🟡 AU CHIEN DE JOUER"
  						label_status.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
  					
  					get_viewport().set_input_as_handled()
  ```

- [ ] **Step 3: Implement Dog AI strategic moves**
  Write the AI decision-making algorithms and win/tie checking methods.

  Write these methods in `MiniJeuChien.gd`:
  ```gdscript
  func _make_morpion_dog_move() -> void:
  	is_morpion_ai_thinking = false
  	is_player_turn = true
  	
  	var chosen_cell := -1
  	
  	# 1. Attaque: Peut-on gagner ce tour ?
  	chosen_cell = _find_morpion_winning_cell(2)
  	
  	# 2. Défense: Bloquer le joueur s'il est prêt à gagner
  	if chosen_cell == -1:
  		chosen_cell = _find_morpion_winning_cell(1)
  		
  	# 3. Prendre le centre
  	if chosen_cell == -1 and morpion_grid[4] == 0:
  		chosen_cell = 4
  		
  	# 4. Prendre un coin disponible
  	if chosen_cell == -1:
  		var coins: Array[int] = [0, 2, 6, 8]
  		coins.shuffle()
  		for c in coins:
  			if morpion_grid[c] == 0:
  				chosen_cell = c
  				break
  				
  	# 5. Case aléatoire restante
  	if chosen_cell == -1:
  		var disponibles: Array[int] = []
  		for idx in range(9):
  			if morpion_grid[idx] == 0:
  				disponibles.append(idx)
  		if not disponibles.is_empty():
  			chosen_cell = disponibles[_rng.randi_range(0, disponibles.size() - 1)]
  			
  	if chosen_cell != -1:
  		morpion_grid[chosen_cell] = 2 # Place bone
  		_play_bark(0.95)
  		
  	_check_morpion_game_state()
  	if not is_morpion_game_over:
  		label_score_info.text = "A VOUS ! POSER LA BALLE 🎾"
  		label_status.text = "🟢 À VOUS DE JOUER !"
  		label_status.add_theme_color_override("font_color", Color(0.24, 0.95, 0.79, 1.0))

  func _find_morpion_winning_cell(side: int) -> int:
  	var wins: Array[Array] = [
  		[0, 1, 2], [3, 4, 5], [6, 7, 8], # lines
  		[0, 3, 6], [1, 4, 7], [2, 5, 8], # cols
  		[0, 4, 8], [2, 4, 6]             # diags
  	]
  	for combo in wins:
  		var c0: int = combo[0]
  		var c1: int = combo[1]
  		var c2: int = combo[2]
  		
  		if morpion_grid[c0] == side and morpion_grid[c1] == side and morpion_grid[c2] == 0:
  			return c2
  		if morpion_grid[c0] == side and morpion_grid[c2] == side and morpion_grid[c1] == 0:
  			return c1
  		if morpion_grid[c1] == side and morpion_grid[c2] == side and morpion_grid[c0] == 0:
  			return c0
  	return -1

  func _check_morpion_game_state() -> void:
  	var wins: Array[Array] = [
  		[0, 1, 2], [3, 4, 5], [6, 7, 8],
  		[0, 3, 6], [1, 4, 7], [2, 5, 8],
  		[0, 4, 8], [2, 4, 6]
  	]
  	
  	for combo in wins:
  		var c0: int = combo[0]
  		var c1: int = combo[1]
  		var c2: int = combo[2]
  		
  		if morpion_grid[c0] != 0 and morpion_grid[c0] == morpion_grid[c1] and morpion_grid[c0] == morpion_grid[c2]:
  			is_morpion_game_over = true
  			morpion_winner = morpion_grid[c0]
  			_announce_morpion_winner()
  			return
  			
  	# Check tie
  	if not morpion_grid.has(0):
  		is_morpion_game_over = true
  		morpion_winner = 0
  		_announce_morpion_winner()

  func _announce_morpion_winner() -> void:
  	if morpion_winner == 1:
  		label_score_info.text = "🏆 VICTOIRE ! LE CHIEN SECOUÉ ! (Cliquez pour relancer)"
  		label_status.text = "✨ VOUS AVEZ GAGNÉ CONTRE LE CHIEN ! ✨"
  		label_status.add_theme_color_override("font_color", Color(0.24, 0.95, 0.79, 1.0))
  		_play_bark(1.6)
  		# Trigger particles
  		var parent := get_parent()
  		if parent and parent.has_method("declencher_particles_victoire"):
  			parent.call("declencher_particles_victoire")
  	elif morpion_winner == 2:
  		label_score_info.text = "🐶 LE CHIEN GAGNE ! IL REMUE SA QUEUE ! (Cliquez pour relancer)"
  		label_status.text = "💥 LE CHIEN A REMPORTÉ LA PARTIE !"
  		label_status.add_theme_color_override("font_color", Color(1.0, 0.2, 0.4, 1.0))
  		_play_bark(0.5)
  	else:
  		label_score_info.text = "🤝 MATCH NUL ! BEAU COMBAT ! (Cliquez pour relancer)"
  		label_status.text = "⚪ EGALITÉ !"
  		label_status.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 1.0))
  		_play_bark(1.0)
  ```

- [ ] **Step 4: Verify headless syntax**
  Run: `/home/rimbaud/GODOT/godot --headless --check-only`
  Expected: Success without errors.

- [ ] **Step 5: Commit Morpion**
  ```bash
  git add "HUB Central/MiniJeuChien.gd"
  git commit -m "feat(dog-playroom): implement full Morpion Tic-Tac-Toe AI and rendering"
  ```

---

### Task 3: Chien-Pong Implementation

**Files:**
- Modify: `res://HUB Central/MiniJeuChien.gd`

- [ ] **Step 1: Write Pong parameters, controls, and physics loop**
  Define the Pong structures and insert the paddle/ball translations and collisions inside `_process` and `_on_scope_draw`.

  Insert variables into `MiniJeuChien.gd`:
  ```gdscript
  # Chien-Pong variables
  var p_paddle_y: float = 120.0
  var d_paddle_y: float = 120.0
  var paddle_h: float = 45.0
  var paddle_w: float = 8.0
  
  var ball_pos: Vector2 = Vector2.ZERO
  var ball_vel: Vector2 = Vector2.ZERO
  var ball_radius: float = 6.0
  var base_ball_speed: float = 240.0
  var ball_speed_multiplier: float = 1.0
  
  var player_score: int = 0
  var dog_score: int = 0
  var is_pong_game_over: bool = false
  var pong_winner: int = 0
  ```

  Modify `_on_play_pong_pressed()` to start Chien-Pong:
  ```gdscript
  func _on_play_pong_pressed() -> void:
  	current_state = GameState.PONG
  	menu_container.visible = false
  	player_score = 0
  	dog_score = 0
  	is_pong_game_over = false
  	pong_winner = 0
  	_reset_pong_ball(1.0)
  	_play_bark(1.1)
  ```

  Add `_reset_pong_ball()` helper method:
  ```gdscript
  func _reset_pong_ball(direction: float) -> void:
  	ball_pos = Vector2(300.0, 145.0)
  	ball_speed_multiplier = 1.0
  	var angle := _rng.randf_range(-0.4, 0.4)
  	ball_vel = Vector2(direction * base_ball_speed, sin(angle) * base_ball_speed)
  	p_paddle_y = 120.0
  	d_paddle_y = 120.0
  	
  	if not is_pong_game_over:
  		label_score_info.text = "SCORE - VOUS: " + str(player_score) + " | CHIEN: " + str(dog_score)
  		label_status.text = "🟢 TENEZ BON !"
  		label_status.add_theme_color_override("font_color", Color(0.24, 0.95, 0.79, 1.0))
  ```

  Update `_process()` to run the Pong physics steps:
  ```gdscript
  	# Inside _process() below not active check:
  	if current_state == GameState.PONG and not is_pong_game_over:
  		_process_pong(delta)
  ```

  Implement the physics and collision logic:
  ```gdscript
  func _process_pong(delta: float) -> void:
  	# 1. Keyboard controls for player paddle
  	if Input.is_action_pressed("marche_bas"):
  		p_paddle_y = clampf(p_paddle_y + 300.0 * delta, paddle_h / 2.0, 290.0 - paddle_h / 2.0)
  	elif Input.is_action_pressed("marche_haut"):
  		p_paddle_y = clampf(p_paddle_y - 300.0 * delta, paddle_h / 2.0, 290.0 - paddle_h / 2.0)
  		
  	# 2. Dog AI paddle tracking limit
  	var dog_speed := 185.0 + (float(player_score) * 12.0)
  	d_paddle_y = move_toward(d_paddle_y, ball_pos.y, dog_speed * delta)
  	d_paddle_y = clampf(d_paddle_y, paddle_h / 2.0, 290.0 - paddle_h / 2.0)
  	
  	# 3. Ball translation
  	ball_pos += ball_vel * ball_speed_multiplier * delta
  	
  	# Ceiling and Floor bounce
  	if ball_pos.y <= ball_radius:
  		ball_pos.y = ball_radius
  		ball_vel.y = -ball_vel.y
  	elif ball_pos.y >= 290.0 - ball_radius:
  		ball_pos.y = 290.0 - ball_radius
  		ball_vel.y = -ball_vel.y
  		
  	# 4. Paddle Collision check
  	# Left paddle (player)
  	if ball_pos.x <= 25.0 + paddle_w and ball_pos.x >= 25.0:
  		if ball_pos.y >= p_paddle_y - paddle_h / 2.0 and ball_pos.y <= p_paddle_y + paddle_h / 2.0:
  			ball_pos.x = 25.0 + paddle_w
  			ball_vel.x = -ball_vel.x
  			var offset := (ball_pos.y - p_paddle_y) / (paddle_h / 2.0)
  			ball_vel.y = offset * base_ball_speed * 0.9
  			ball_speed_multiplier = minf(2.4, ball_speed_multiplier + 0.1)
  			_play_bark(1.4)
  			
  	# Right paddle (dog's tail)
  	if ball_pos.x >= 575.0 - paddle_w and ball_pos.x <= 575.0:
  		if ball_pos.y >= d_paddle_y - paddle_h / 2.0 and ball_pos.y <= d_paddle_y + paddle_h / 2.0:
  			ball_pos.x = 575.0 - paddle_w
  			ball_vel.x = -ball_vel.x
  			var offset := (ball_pos.y - d_paddle_y) / (paddle_h / 2.0)
  			ball_vel.y = offset * base_ball_speed * 0.9
  			ball_speed_multiplier = minf(2.4, ball_speed_multiplier + 0.1)
  			_play_bark(0.95)
  			
  	# 5. Goal check
  	if ball_pos.x < 0.0:
  		dog_score += 1
  		_check_pong_score(1.0)
  	elif ball_pos.x > 600.0:
  		player_score += 1
  		var parent := get_parent()
  		if parent and parent.has_method("declencher_particles_victoire"):
  			parent.call("declencher_particles_victoire")
  		_check_pong_score(-1.0)
  ```

  Add Score Checking & Game Over triggers:
  ```gdscript
  func _check_pong_score(next_dir: float) -> void:
  	if player_score >= 5:
  		is_pong_game_over = true
  		pong_winner = 1
  		label_score_info.text = "🏆 VICTOIRE PONG ! SCORE : " + str(player_score) + " - " + str(dog_score) + " (Clic pour relancer)"
  		label_status.text = "✨ VOUS AVEZ REMPORTÉ LE CHIEN-PONG ! ✨"
  		label_status.add_theme_color_override("font_color", Color(0.24, 0.95, 0.79, 1.0))
  		_play_bark(1.6)
  	elif dog_score >= 5:
  		is_pong_game_over = true
  		pong_winner = 2
  		label_score_info.text = "🐶 LE CHIEN GAGNE ! SCORE : " + str(player_score) + " - " + str(dog_score) + " (Clic pour relancer)"
  		label_status.text = "💥 LE CHIEN A REMPORTÉ LE CHIEN-PONG !"
  		label_status.add_theme_color_override("font_color", Color(1.0, 0.2, 0.4, 1.0))
  		_play_bark(0.5)
  	else:
  		_reset_pong_ball(next_dir)
  ```

  Implement Pong mouse inputs in `_on_scope_gui_input()`:
  ```gdscript
  	# Inside _on_scope_gui_input() below GameState.MORPION check:
  	elif current_state == GameState.PONG:
  		if is_pong_game_over:
  			if event is InputEventMouseButton and event.pressed:
  				_on_play_pong_pressed()
  				get_viewport().set_input_as_handled()
  			return
  		if event is InputEventMouseMotion:
  			p_paddle_y = clampf(event.position.y, paddle_h / 2.0, 290.0 - paddle_h / 2.0)
  ```

  Update `_on_scope_draw()` to call the Pong draw routine:
  ```gdscript
  # Inside _on_scope_draw() replace check:
  	elif current_state == GameState.PONG:
  		_draw_pong(w, h)
  ```

  Implement `_draw_pong` method:
  ```gdscript
  func _draw_pong(w: float, h: float) -> void:
  	# Draw mid-line dotted grid
  	var start_y := 10.0
  	while start_y < h:
  		scope_control.draw_rect(Rect2(w / 2.0 - 2.0, start_y, 4.0, 10.0), Color(0.8, 0.5, 1.0, 0.15))
  		start_y += 20.0
  		
  	# Draw paddles
  	# Left (Player - cyan)
  	scope_control.draw_rect(Rect2(25.0, p_paddle_y - paddle_h / 2.0, paddle_w, paddle_h), Color(0.24, 0.95, 0.79, 1.0))
  	scope_control.draw_rect(Rect2(25.0, p_paddle_y - paddle_h / 2.0, paddle_w, paddle_h), Color(0.24, 0.95, 0.79, 0.35), false, 2.0)
  	
  	# Right (Dog's tail - pink)
  	scope_control.draw_rect(Rect2(575.0 - paddle_w, d_paddle_y - paddle_h / 2.0, paddle_w, paddle_h), Color(0.8, 0.5, 1.0, 1.0))
  	scope_control.draw_rect(Rect2(575.0 - paddle_w, d_paddle_y - paddle_h / 2.0, paddle_w, paddle_h), Color(0.8, 0.5, 1.0, 0.35), false, 2.0)
  	
  	# Draw dynamic wagging wag-lines next to dog's paddle to represent tail movements!
  	var tail_line_x := 585.0
  	var tail_sway := sin(animation_time * 24.0) * 10.0
  	scope_control.draw_line(Vector2(tail_line_x, d_paddle_y - 10), Vector2(tail_line_x + 8.0, d_paddle_y - 10 + tail_sway), Color(0.8, 0.5, 1.0, 0.7), 2.0)
  	scope_control.draw_line(Vector2(tail_line_x, d_paddle_y + 10), Vector2(tail_line_x + 8.0, d_paddle_y + 10 - tail_sway), Color(0.8, 0.5, 1.0, 0.7), 2.0)
  	
  	# Draw Ball
  	if not is_pong_game_over:
  		scope_control.draw_circle(ball_pos, ball_radius, Color(0.24, 0.95, 0.79, 1.0))
  		scope_control.draw_circle(ball_pos, ball_radius + 4.0, Color(0.24, 0.95, 0.79, 0.35), false, 1.5)
  ```

- [ ] **Step 2: Verify headless syntax**
  Run: `/home/rimbaud/GODOT/godot --headless --check-only`
  Expected: Success without errors.

- [ ] **Step 3: Commit Pong**
  ```bash
  git add "HUB Central/MiniJeuChien.gd"
  git commit -m "feat(dog-playroom): implement full Chien-Pong physics and rendering"
  ```

---

### Task 4: Complete Lifecycle Integration & Verification

**Files:**
- Modify: `res://HUB Central/MiniJeuChien.gd`
- Modify: `/home/rimbaud/.gemini/antigravity-cli/brain/a318c152-64d0-4206-ba6d-3178b23d4414/walkthrough.md`
- Modify: `/home/rimbaud/.gemini/antigravity-cli/brain/a318c152-64d0-4206-ba6d-3178b23d4414/task.md`

- [ ] **Step 1: Build robust navigation, restart handlers, and memory cleanup**
  Make sure `btn_quit` and `btn_play_morpion`/`btn_play_pong` buttons render and toggle correctly in all modes. Ensure that when a sub-game is active, the main menu container `menu_container` is fully hidden, and visible when we return.

  Add full menu hiding inside sub-game starts.
  Modify `_on_play_morpion_pressed()`:
  ```gdscript
  # verify menu_container.visible = false is present
  ```
  Modify `_on_play_pong_pressed()`:
  ```gdscript
  # verify menu_container.visible = false is present
  ```
  Modify `_on_quit_pressed()` to reset sub-game parameters completely:
  ```gdscript
  # Ensure all gameplay states are cleaned up
  ```

- [ ] **Step 2: Run final headless checks**
  Run: `/home/rimbaud/GODOT/godot --headless --check-only`
  Expected: Complete successful execution without compilation warnings or errors.

- [ ] **Step 3: Update walkthrough artifact**
  Rewrite `walkthrough.md` to document the completed playroom and sub-games.

- [ ] **Step 4: Update task artifact**
  Check the boxes inside `task.md` to finalize the tracking.

- [ ] **Step 5: Commit complete playroom**
  ```bash
  git add "HUB Central/MiniJeuChien.gd"
  git commit -m "feat(dog-playroom): finalize navigation integration and verify headless gameplay"
  ```
