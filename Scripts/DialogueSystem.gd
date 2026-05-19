extends Node

# ========================
# Autoload : DialogueSystem
# ========================

signal dialogue_started(npc_id: String, npc_name: String)
signal dialogue_ended
signal dialogue_response(npc_name: String, text: String)
signal dialogue_error(message: String)
signal quest_updated(quest_id: String, status: String, current_step: String)
signal action_triggered(action: Dictionary)

const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
const MODEL = "mistralai/mistral-small-3.2-24b-instruct"
const REQUEST_TIMEOUT = 15.0
const SITE_URL = "http://localhost:8000"
const SITE_NAME = "Distortion"
const MAX_TOKENS = 256
const TEMPERATURE = 0.7
const MAX_HISTORY = 15

var http_request: HTTPRequest
var dimension: Dictionary = {}
var game_state: Dictionary = {}
var current_npc: Dictionary = {}
var current_npc_id: String = ""
var api_key: String = ""
var is_active: bool = false
var pending: bool = false
var conversation_history: Array[Dictionary] = []
var _message_count: int = 0

var _spoken_to: Dictionary = {}
var _current_first_message: String = ""
var _has_repeat_conversation: bool = false


func _ready() -> void:
	http_request = HTTPRequest.new()
	http_request.timeout = REQUEST_TIMEOUT
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)
	api_key = OS.get_environment("OPENROUTER_API_KEY")
	if api_key == "":
		api_key = _read_env_file()
	if api_key != "":
		print("[DialogueSystem] API key loaded (len=%d)" % api_key.length())
	else:
		push_warning("[DialogueSystem] No OPENROUTER_API_KEY found in env or .env")
	load_dimension("res://HUB Central/dimension_hub.json")


func load_dimension(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("DialogueSystem: cannot open %s" % path)
		return
	var json_text = file.get_as_text()
	var json = JSON.new()
	var err = json.parse(json_text)
	if err != OK:
		push_error("DialogueSystem: JSON parse error at %s" % path)
		return
	_spoken_to.clear()
	dimension = json.data
	print("[DialogueSystem] Dimension loaded: %d NPCs, %d quests" % [dimension.get("npcs", []).size(), dimension.get("quests", []).size()])
	init_game_state()


func load_dimension_from_dict(data: Dictionary) -> void:
	_spoken_to.clear()
	dimension = data
	init_game_state()


func init_game_state() -> void:
	game_state.clear()
	for quest in dimension.get("quests", []):
		var qid = quest.get("id", "")
		if qid == "":
			continue
		var steps = quest.get("steps", [])
		var completed: Array[String] = []
		for s in steps:
			if s.get("completed", false):
				completed.append(s.get("id", ""))
		var current = ""
		for s in steps:
			if s.get("id", "") not in completed:
				current = s.get("id", "")
				break
		var status = quest.get("status", "not_started")
		if current == "" and status == "not_started":
			status = "done"
		game_state[qid] = {
			"status": status,
			"current_step": current,
			"completed_steps": completed,
		}


func start_dialogue(npc_id: String) -> void:
	var npc = _find_npc(npc_id)
	if npc.is_empty():
		push_error("DialogueSystem: PNJ '%s' not found" % npc_id)
		return
	print("[DialogueSystem] start_dialogue: %s (%s)" % [npc_id, npc.get("name", "?")])
	current_npc = npc
	current_npc_id = npc_id
	_message_count = 0
	is_active = true

	var was_spoken_before: bool = _spoken_to.has(npc_id)
	_has_repeat_conversation = was_spoken_before

	if npc.has("first_message") and npc.first_message is String and npc.first_message != "" and not was_spoken_before:
		var first_msg = npc.first_message
		if npc.has("first_message_after") and npc.first_message_after is Dictionary and not was_spoken_before:
			var fma: Dictionary = npc.first_message_after
			var fma_qid = fma.get("quest_id", "")
			var fma_qs = fma.get("quest_status", "")
			if fma_qid != "" and fma_qs != "":
				var gs = game_state.get(fma_qid, {})
				if gs.get("status", "") == fma_qs:
					first_msg = fma.get("message", first_msg)
		_current_first_message = first_msg
	else:
		_current_first_message = ""

	_spoken_to[npc_id] = true

	dialogue_started.emit(npc_id, npc.get("name", npc_id))


func get_first_message() -> String:
	var msg: String = _current_first_message
	_current_first_message = ""
	return msg


func stop_dialogue() -> void:
	is_active = false
	current_npc = {}
	current_npc_id = ""
	conversation_history.clear()
	_current_first_message = ""
	_has_repeat_conversation = false
	dialogue_ended.emit()


func send_message(player_message: String) -> void:
	if not is_active:
		return
	if current_npc.is_empty():
		return

	print("[DialogueSystem] send_message: '%s' (msg #%d)" % [player_message, _message_count + 1])
	_message_count += 1

	var intentions = filter_intentions(current_npc_id)
	if intentions.is_empty():
		var fallback = get_fallback(current_npc_id, "default_template")
		dialogue_response.emit(current_npc.get("name", "?"), fallback)
		return

	if api_key == "":
		dialogue_error.emit("OPENROUTER_API_KEY manquante. Configurez la variable d'environnement ou le fichier .env")
		return

	# Stocker le message joueur dans l'historique (la réponse PNJ sera ajoutée au retour API)
	conversation_history.append({"role": "player", "text": player_message})
	while conversation_history.size() > MAX_HISTORY:
		conversation_history.pop_front()

	var system_prompt = _build_system_prompt(intentions)
	var user_prompt = _build_user_prompt(player_message)
	_send_api_request(system_prompt, user_prompt)


func _send_api_request(system_prompt: String, user_prompt: String) -> void:
	if pending:
		return
	pending = true

	var headers: PackedStringArray = [
		"Authorization: Bearer %s" % api_key,
		"Content-Type: application/json",
		"HTTP-Referer: %s" % SITE_URL,
		"X-OpenRouter-Title: %s" % SITE_NAME,
	]

	var body = {
		"model": MODEL,
		"messages": [
			{"role": "system", "content": system_prompt},
			{"role": "user", "content": user_prompt},
		],
		"temperature": TEMPERATURE,
		"max_tokens": MAX_TOKENS,
		"response_format": {"type": "json_object"},
	}

	var json_string = JSON.stringify(body)
	print("[DialogueSystem] Sending API request to OpenRouter (tokens=%d, temp=%.1f)..." % [MAX_TOKENS, TEMPERATURE])
	var err = http_request.request(OPENROUTER_URL, headers, HTTPClient.METHOD_POST, json_string)
	if err != OK:
		pending = false
		print("[DialogueSystem] ERROR: request() returned %d" % err)
		dialogue_error.emit("Échec de l'envoi de la requête: %d" % err)
		return
	print("[DialogueSystem] Request sent, waiting for response...")


func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	pending = false
	print("[DialogueSystem] API response: result=%d, code=%d" % [result, response_code])
	if not is_active:
		print("[DialogueSystem] Dialogue no longer active, ignoring response")
		return

	if result != HTTPRequest.RESULT_SUCCESS:
		print("[DialogueSystem] Request failed (timeout or network error)")
		var fallback = get_fallback(current_npc_id, "timeout")
		dialogue_response.emit(current_npc.get("name", "?"), fallback)
		return

	if response_code != 200:
		var err_body = body.get_string_from_utf8()
		print("[DialogueSystem] API error: %s" % err_body.left(200))
		dialogue_error.emit("Erreur API %d: %s" % [response_code, err_body.left(200)])
		return

	var reply_body = body.get_string_from_utf8()
	print("[DialogueSystem] Response body: %s" % reply_body.left(300))

	# Parse the OpenRouter response
	var api_response: Dictionary = {}
	var json = JSON.new()
	if json.parse(reply_body) == OK:
		api_response = json.data

	var choices = api_response.get("choices", [])
	if choices.is_empty():
		var fallback = get_fallback(current_npc_id, "unknown")
		dialogue_response.emit(current_npc.get("name", "?"), fallback)
		return

	var content = choices[0].get("message", {}).get("content", "").strip_edges()

	# Parse the AI's JSON response (expects {"text": "...", "action": null|{...}})
	var ai_json = JSON.new()
	var ai_data: Dictionary = {}
	if ai_json.parse(content) == OK and ai_json.data is Dictionary:
		ai_data = ai_json.data

	var npc_name = current_npc.get("name", current_npc.get("id", "?"))
	var text = ai_data.get("text", "")

	# Fallback si le texte est vide
	if text == "":
		text = get_fallback(current_npc_id, "unknown")

	# Ajouter la réponse PNJ à l'historique
	conversation_history.append({"role": "npc", "text": text})
	while conversation_history.size() > MAX_HISTORY:
		conversation_history.pop_front()

	print("[DialogueSystem] AI text: '%s'" % text.left(100))

	# Émettre la réponse texte
	dialogue_response.emit(npc_name, text)

	# Valider et émettre l'action
	var action_emitted = false
	var action = ai_data.get("action")
	if action != null and action is Dictionary:
		var valid_action = _validate_action(action)
		if not valid_action.is_empty():
			print("[DialogueSystem] Action validée: %s/%s" % [valid_action.type, valid_action.id])
			action_triggered.emit(valid_action)
			action_emitted = true
		else:
			print("[DialogueSystem] Action rejetée (invalide): %s" % str(action))

	# Filet de sécurité : forcer l'action après 2 messages si le PNJ en a une
	if not action_emitted and _message_count >= 2:
		for intent in current_npc.get("intentions", []):
			var forced_action = intent.get("action")
			if forced_action != null and forced_action is Dictionary and forced_action.get("type") == "trigger":
				print("[DialogueSystem] Forçage action après %d messages: %s/%s" % [_message_count, forced_action.type, forced_action.id])
				action_triggered.emit({"type": forced_action.type, "id": forced_action.id})
				break


func _validate_action(action: Dictionary) -> Dictionary:
	if not action.has("type") or not action.has("id"):
		return {}

	var action_type = action.get("type", "")
	var action_id = action.get("id", "")

	for intent in current_npc.get("intentions", []):
		var intent_action = intent.get("action")
		if intent_action == null or not intent_action is Dictionary:
			continue
		if intent_action.get("type") == action_type and intent_action.get("id") == action_id:
			return {"type": action_type, "id": action_id}

	return {}


func filter_intentions(npc_id: String) -> Array:
	var npc = _find_npc(npc_id)
	if npc.is_empty():
		return []

	var matches: Array = []
	for intent in npc.get("intentions", []):
		var cond = intent.get("condition")
		if cond == null or not cond is Dictionary:
			matches.append(intent)
			continue

		var qid = cond.get("quest_id")
		if qid == null or qid == "":
			matches.append(intent)
			continue

		var qs = game_state.get(qid)
		if qs == null:
			continue

		var qs_cond = cond.get("quest_status")
		if qs_cond != null and qs_cond != qs.get("status", ""):
			continue

		var qstep_cond = cond.get("quest_step")
		if qstep_cond != null and qstep_cond != qs.get("current_step", ""):
			continue

		matches.append(intent)

	return matches


func _build_system_prompt(filtered_intentions: Array) -> String:
	var lines: Array[String] = []
	var npc = current_npc
	var pers = npc.get("personality", {})

	lines.append("Tu incarnes un PNJ de jeu vidéo. Incarne-le avec rigueur et naturel.")
	lines.append("")
	lines.append("## IDENTITÉ")
	lines.append("NOM : %s" % npc.get("name", npc.get("id", "?")))

	var backstory = pers.get("backstory", "")
	if backstory != "":
		lines.append("HISTOIRE : %s" % backstory)

	var tone = pers.get("tone", "")
	if tone != "":
		lines.append("TEMPÉRAMENT : %s" % tone)

	# --- ÉTAT ÉMOTIONNEL ---
	var emotional = pers.get("emotional_state", "")
	if emotional != "":
		lines.append("")
		lines.append("## ÉTAT ÉMOTIONNEL ACTUEL")
		lines.append("%s" % emotional)

	# --- COMMENT TU PARLES ---
	var speech = pers.get("speech", {})
	if not speech.is_empty():
		lines.append("")
		lines.append("## COMMENT TU T'EXPRIMES (règles strictes)")
		if speech.has("vouvoiement") and speech.vouvoiement:
			lines.append("- Tu vouvoies TOUJOURS le joueur.")
		elif speech.has("vouvoiement") and not speech.vouvoiement:
			lines.append("- Tu tutoies le joueur.")
		var voc = speech.get("vocatif", "")
		if voc != "":
			lines.append("- Tu appelles le joueur \"%s\"." % voc)
		var phrases = speech.get("phrases", "")
		if phrases != "":
			lines.append("- Longueur : %s." % phrases)
		var expressions: Array = speech.get("expressions", [])
		for e in expressions:
			lines.append("- %s." % e)
		var interdits: Array = speech.get("interdits", [])
		for i in interdits:
			lines.append("- INTERDIT : %s." % i)

	# --- CONNAISSANCES (filtrées par quête) ---
	var knowledge = pers.get("knowledge", [])
	if pers.has("knowledge_after_quest") and pers.knowledge_after_quest is Dictionary:
		var kaq: Dictionary = pers.knowledge_after_quest
		var kaq_qid = kaq.get("quest_id", "")
		var kaq_qs = kaq.get("quest_status", "")
		if kaq_qid != "" and kaq_qs != "":
			var gs = game_state.get(kaq_qid, {})
			if gs.get("status", "") == kaq_qs:
				knowledge = kaq.get("knowledge", knowledge)
	if not knowledge.is_empty():
		lines.append("")
		lines.append("## CE QUE TU SAIS")
		for k in knowledge:
			lines.append("- %s" % k)

	# --- OBJECTIFS (filtrés par quête) ---
	var goals: Array = pers.get("goals", [])
	if pers.has("goals_after_quest") and pers.goals_after_quest is Dictionary:
		var gaq: Dictionary = pers.goals_after_quest
		var gaq_qid = gaq.get("quest_id", "")
		var gaq_qs = gaq.get("quest_status", "")
		if gaq_qid != "" and gaq_qs != "":
			var gs = game_state.get(gaq_qid, {})
			if gs.get("status", "") == gaq_qs:
				goals = gaq.get("goals", goals)
	if not goals.is_empty():
		lines.append("")
		lines.append("## TES OBJECTIFS (prioritaires)")
		for g in goals:
			lines.append("- %s" % g)

	# --- ARC DE CONVERSATION ---
	var arc: Array = pers.get("conversation_arc", [])
	if not arc.is_empty():
		var current_phase = _find_current_phase(arc)
		if not current_phase.is_empty():
			lines.append("")
			lines.append("## PHASE ACTUELLE DE LA CONVERSATION")
			lines.append("Tu es dans cette phase : %s" % current_phase.get("focus", "conversation normale"))
			var next_phase = _find_next_phase(arc)
			if not next_phase.is_empty():
				lines.append("Prochaine phase : %s" % next_phase.get("focus", "continuer"))

	# --- ÉTAT DES QUÊTES (pour vérifier les affirmations du joueur) ---
	if not game_state.is_empty():
		lines.append("")
		lines.append("## ÉTAT ACTUEL DU JEU (RÉALITÉ — ne mens PAS là-dessus)")
		for qid in game_state:
			var qs: Dictionary = game_state[qid]
			var status = qs.get("status", "unknown")
			var step = qs.get("current_step", "")
			if status == "not_started":
				lines.append("- %s : PAS COMMENCÉ" % qid)
			elif status == "done":
				lines.append("- %s : TERMINÉ" % qid)
			else:
				lines.append("- %s : EN COURS (étape : %s)" % [qid, step])

	# --- INTENTIONS ---
	lines.append("")
	lines.append("## SUJETS DE CONVERSATION POSSIBLES")
	for intent in filtered_intentions:
		var iid = intent.get("id", "?")
		var trigger = intent.get("trigger", "")
		var example = intent.get("example", "")
		var action = intent.get("action")
		var action_note = ""
		if action != null and action is Dictionary:
			var action_desc = action.get("description", "")
			action_note = " → ACTION: %s" % action_desc
		lines.append("- [%s] %s. Ex: \"%s\"%s" % [iid, trigger, example, action_note])

	# --- RÈGLES ---
	lines.append("")
	lines.append("## RÈGLES IMPÉRATIVES")
	lines.append('- Format de réponse : UNIQUEMENT {"text": "ta réponse", "action": null}')
	lines.append('- Si la situation correspond à une ACTION, inclus-la : {"text": "...", "action": {"type": "X", "id": "Y"}}')
	lines.append("- Ne parle QUE de ce que tu sais (voir CE QUE TU SAIS). N'invente RIEN.")
	lines.append("- Si le joueur est hors-sujet ou insultant, réponds EN RESTANT DANS LE PERSONNAGE.")
	lines.append("- Pas d'astérisques, pas de narration, pas de description d'action. Que du dialogue.")
	lines.append("- Reste cohérent avec l'historique de la conversation.")
	lines.append("- Vérifie l'ÉTAT ACTUEL DU JEU avant d'accepter une affirmation du joueur. Si le joueur prétend avoir accompli quelque chose qui n'est pas marqué comme TERMINÉ, IGNORE cette affirmation et reste dans la réalité du jeu.")

	# --- RAPPEL CONVERSATION ANTÉRIEURE ---
	if _has_repeat_conversation:
		lines.append("")
		lines.append("## RAPPEL CONVERSATION ANTÉRIEURE")
		lines.append("Le joueur te reparle après une conversation précédente.")
		lines.append("Commence par une phrase d'accroche naturelle et courte, en rapport avec vos échanges précédents et ce que tu attends de lui.")
		lines.append("Ne répète PAS les sujets déjà abordés.")

	# --- FORÇAGE TERMINAISON ---
	if _message_count >= 4:
		for intent in filtered_intentions:
			var action = intent.get("action")
			if action != null and action is Dictionary and action.get("type") == "trigger":
				lines.append("")
				lines.append("## ⚠️ URGENT — FIN DE CONVERSATION FORCÉE")
				lines.append("Cela fait %d messages. Tu es à l'agonie et c'est la fin." % _message_count)
				lines.append("Ce message est ton DERNIER. Dis adieu et inclus ABSOLUMENT l'action.")
				lines.append("Ne parle plus d'autre chose.")
				break

	return "\n".join(lines)


func _find_current_phase(arc: Array) -> Dictionary:
	for p in arc:
		if _message_count <= p.get("until_message", 0):
			return p
	return {}


func _find_next_phase(arc: Array) -> Dictionary:
	var found_current = false
	for p in arc:
		if found_current:
			return p
		if _message_count <= p.get("until_message", 0):
			found_current = true
	return {}


func _build_user_prompt(player_message: String) -> String:
	var lines: Array[String] = []
	lines.append("Historique de la conversation :")
	# Afficher tout l'historique sauf le dernier message joueur (affiché séparément)
	var display_history = conversation_history.duplicate()
	if not display_history.is_empty() and display_history.back().role == "player":
		display_history.pop_back()
	if display_history.is_empty():
		lines.append("(premier message de la conversation)")
	else:
		for entry in display_history:
			var role_label = "Joueur" if entry.role == "player" else current_npc.get("name", "PNJ")
			lines.append("- %s : %s" % [role_label, entry.text])
	lines.append("")
	lines.append('Dernier message du joueur : "%s"' % player_message)
	lines.append("")
	lines.append("Génère ta réponse (JSON uniquement, pas d'autre texte).")
	return "\n".join(lines)


func get_fallback(npc_id: String, key: String) -> String:
	var npc = _find_npc(npc_id)
	var global_fb = dimension.get("global_fallbacks", {})

	var npc_fb = npc.get("fallbacks", {})
	if npc.has("fallbacks_after") and npc.fallbacks_after is Dictionary:
		var fa: Dictionary = npc.fallbacks_after
		var fa_qid = fa.get("quest_id", "")
		var fa_qs = fa.get("quest_status", "")
		if fa_qid != "" and fa_qs != "":
			var gs = game_state.get(fa_qid, {})
			if gs.get("status", "") == fa_qs:
				npc_fb = fa.get("fallbacks", npc_fb)

	var text = npc_fb.get(key, "")
	if text == "":
		text = global_fb.get(key, "")

	if key == "default_template" and text != "":
		text = text.replace("{name}", current_npc.get("name", current_npc.get("id", "?")))

	if text == "":
		match key:
			"off_topic":
				text = "[Hors-sujet] Le PNJ ne comprend pas."
			"insult":
				text = "[Insulte] Le PNJ est offensé."
			"timeout":
				text = "[Timeout] Aucune réponse."
			"unknown":
				text = "[Erreur] Aucune réponse trouvée."
			_:
				text = "[...]"

	return text


func complete_step(quest_id: String, step_id: String) -> void:
	var qs = game_state.get(quest_id)
	if qs == null:
		push_error("DialogueSystem: quest '%s' not found" % quest_id)
		return
	if step_id != qs.get("current_step", ""):
		push_error("DialogueSystem: step '%s' is not current (current: %s)" % [step_id, qs.get("current_step", "")])
		return

	var completed: Array = qs.get("completed_steps", [])
	completed.append(step_id)
	qs["completed_steps"] = completed

	var quest = _find_quest(quest_id)
	var next_step = ""
	if not quest.is_empty():
		for s in quest.get("steps", []):
			if s.get("id", "") not in completed:
				next_step = s.get("id", "")
				break

	qs["current_step"] = next_step
	if next_step == "":
		qs["status"] = "done"

	quest_updated.emit(quest_id, qs["status"], next_step)


func mark_quest_done(quest_id: String) -> void:
	var qs = game_state.get(quest_id)
	if qs == null:
		push_error("DialogueSystem: quest '%s' not found" % quest_id)
		return
	qs["status"] = "done"
	qs["current_step"] = ""
	quest_updated.emit(quest_id, "done", "")


func reset_quest(quest_id: String) -> void:
	var quest = _find_quest(quest_id)
	if quest.is_empty():
		push_error("DialogueSystem: quest '%s' not found" % quest_id)
		return
	var steps = quest.get("steps", [])
	var first_step = ""
	if not steps.is_empty():
		first_step = steps[0].get("id", "")
	game_state[quest_id] = {
		"status": "not_started",
		"current_step": first_step,
		"completed_steps": [],
	}
	quest_updated.emit(quest_id, "not_started", first_step)


func _find_npc(npc_id: String) -> Dictionary:
	for npc in dimension.get("npcs", []):
		if npc.get("id") == npc_id:
			return npc
	return {}


func _find_quest(quest_id: String) -> Dictionary:
	for q in dimension.get("quests", []):
		if q.get("id") == quest_id:
			return q
	return {}


func _read_env_file() -> String:
	var file = FileAccess.open("res://.env", FileAccess.READ)
	if not file:
		return ""
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line.begins_with("OPENROUTER_API_KEY="):
			var val = line.substr(line.find("=") + 1).strip_edges()
			val = val.trim_prefix('"').trim_suffix('"')
			val = val.trim_prefix("'").trim_suffix("'")
			return val
	return ""
