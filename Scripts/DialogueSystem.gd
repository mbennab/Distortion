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
signal player_message_submitted(message: String)
signal friendship_response_received(text: String, affinity_change: int, feeling: String)

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
var should_load_save: bool = false
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
var _current_filtered_intentions: Array = []


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
	
	# Apply debug overrides from WarpSystem if available
	if has_node("/root/WarpSystem"):
		var ws = get_node("/root/WarpSystem")
		if ws and "minigames_status" in ws:
			_apply_warp_system_overrides(ws)


func _apply_warp_system_overrides(ws: Node) -> void:
	var status_dict: Dictionary = ws.minigames_status
	
	# Crochetage -> quete_evasion, etape_crocheter
	if status_dict.get("crochetage", false):
		_force_complete_step("quete_evasion", "etape_crocheter")
		
	# Marchandage -> quete_deguisement, etape_marchander
	if status_dict.get("marchandage", false):
		_force_complete_step("quete_deguisement", "etape_parler_marchand")
		_force_complete_step("quete_deguisement", "etape_marchander")
		
	# Écoute Tables -> quete_piste_assassin, etape_enqueter_foret
	if status_dict.get("ecoute_tables", false):
		_force_complete_step("quete_piste_assassin", "etape_enqueter_foret")
		
	# Combat Assassin -> quete_piste_assassin, etape_trouver_assassin
	if status_dict.get("combat_assassin", false):
		_force_complete_step("quete_piste_assassin", "etape_enqueter_foret")
		_force_complete_step("quete_piste_assassin", "etape_trouver_assassin")
		
	# Infiltration -> quete_acces_centrale, etape_chercher_carte
	if status_dict.get("infiltration", false):
		_force_complete_step("quete_acces_centrale", "etape_parler_gardien")
		_force_complete_step("quete_acces_centrale", "etape_chercher_carte")
		
	# Tuyaux -> quete_preparation, etape_reparer_machines
	if status_dict.get("tuyaux", false):
		_force_complete_step("quete_preparation", "etape_parler_secretaire")
		_force_complete_step("quete_preparation", "etape_aller_vestiaires")
		_force_complete_step("quete_preparation", "etape_reparer_machines")
		
	# Câblage -> quete_preparation, etape_reparer_electricite
	if status_dict.get("cablage", false):
		_force_complete_step("quete_preparation", "etape_parler_secretaire")
		_force_complete_step("quete_preparation", "etape_aller_vestiaires")
		_force_complete_step("quete_preparation", "etape_reparer_machines")
		_force_complete_step("quete_preparation", "etape_reparer_electricite")


func _force_complete_step(quest_id: String, step_id: String) -> void:
	var qs = game_state.get(quest_id)
	if qs == null:
		return
	var completed: Array = qs.get("completed_steps", [])
	if step_id not in completed:
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
	else:
		qs["status"] = "active"


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

	var first_msg = ""
	if npc.has("first_message") and npc.first_message is String and npc.first_message != "":
		first_msg = npc.first_message

	if npc.has("first_message_after"):
		var fma_entries: Array = []
		if npc.first_message_after is Dictionary:
			fma_entries = [npc.first_message_after]
		elif npc.first_message_after is Array:
			fma_entries = npc.first_message_after
		for entry in fma_entries:
			if not entry is Dictionary:
				continue
			var fma_qid = entry.get("quest_id", "")
			var fma_qs = entry.get("quest_status", "")
			var fma_qstep = entry.get("quest_step", "")
			if fma_qid != "":
				var gs = game_state.get(fma_qid, {})
				var status_match = (fma_qs == "" or gs.get("status", "") == fma_qs)
				var step_match = (fma_qstep == "" or gs.get("current_step", "") == fma_qstep)
				if status_match and step_match:
					first_msg = entry.get("message", first_msg)

	if first_msg != "" and not was_spoken_before:
		_current_first_message = first_msg
	elif first_msg != "" and was_spoken_before:
		# Accroche contextuelle pour conversation suivante si le message diffère du first_message de base
		var base_msg = npc.get("first_message", "")
		if first_msg != base_msg:
			_current_first_message = first_msg
		else:
			_current_first_message = ""
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
	# Émettre AVANT de vider l'état pour que les listeners puissent lire current_npc_id
	dialogue_ended.emit()
	current_npc = {}
	current_npc_id = ""
	conversation_history.clear()
	_current_first_message = ""
	_has_repeat_conversation = false


func send_message(player_message: String) -> void:
	if not is_active:
		return
	if current_npc.is_empty():
		return

	print("[DialogueSystem] send_message: '%s' (msg #%d)" % [player_message, _message_count + 1])
	_message_count += 1

	player_message_submitted.emit(player_message)

	var intentions = filter_intentions(current_npc_id)
	_current_filtered_intentions = intentions
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

	if current_npc_id == "npc_femme_parc":
		var affinity_change := 0
		var feeling := "neutral"
		
		if ai_data.has("affinity_change"):
			affinity_change = clampi(int(ai_data.get("affinity_change")), -20, 20)
		else:
			var player_msg := ""
			if conversation_history.size() >= 2:
				player_msg = conversation_history[conversation_history.size() - 2].get("text", "")
			affinity_change = _fallback_keyword_evaluation(player_msg)
			
		if ai_data.has("feeling"):
			feeling = String(ai_data.get("feeling")).to_lower()
			if not feeling in ["happy", "sad", "angry", "neutral"]:
				feeling = "neutral"
		else:
			if affinity_change > 0:
				feeling = "happy"
			elif affinity_change < -5:
				feeling = "angry"
			elif affinity_change < 0:
				feeling = "sad"
			else:
				feeling = "neutral"
				
		print("[DialogueSystem] Friendship response: change=%d, feeling=%s" % [affinity_change, feeling])
		friendship_response_received.emit(text, affinity_change, feeling)

	# Valider et émettre l'action
	var action_emitted = false
	var action = ai_data.get("action")
	if action != null and action is Dictionary:
		var valid_action = _validate_action(action, _current_filtered_intentions)
		if not valid_action.is_empty():
			print("[DialogueSystem] Action validée: %s/%s" % [valid_action.type, valid_action.id])
			action_triggered.emit(valid_action)
			action_emitted = true
		else:
			print("[DialogueSystem] Action rejetée (invalide): %s" % str(action))

	if not action_emitted and _message_count >= 1:
		var active_intentions = filter_intentions(current_npc_id)
		for intent in active_intentions:
			var forced_action = intent.get("action")
			if forced_action != null and forced_action is Dictionary and forced_action.get("type") == "trigger":
				print("[DialogueSystem] Forçage action après %d messages: %s/%s" % [_message_count, forced_action.type, forced_action.id])
				action_triggered.emit({"type": forced_action.type, "id": forced_action.id})
				break


func _validate_action(action: Dictionary, filtered_intentions: Array = []) -> Dictionary:
	if not action.has("type") or not action.has("id"):
		return {}

	var action_type = action.get("type", "")
	var action_id = action.get("id", "")

	# Validation stricte : l'action doit correspondre à une intention ACTIVEMENT filtrée
	# (c-à-d dont la condition de quête est remplie), pas n'importe quelle intention du JSON
	var check_list = filtered_intentions if not filtered_intentions.is_empty() else current_npc.get("intentions", [])
	for intent in check_list:
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
	lines.append("## RÈGLES IMPÉRATIVES")
	if current_npc_id == "npc_femme_parc":
		lines.append('- Format de réponse IMPÉRATIF : Tu dois obligatoirement renvoyer un objet JSON contenant les clés supplémentaires "affinity_change" (un entier entre -20 et +20 mesurant l\'impact poli/sincère du message du joueur sur toi) et "feeling" ("happy", "sad", "angry", "neutral" selon ton ressenti actuel).')
		lines.append('- Exemple : {"text": "ta réponse", "action": null, "affinity_change": 10, "feeling": "happy"}')
	else:
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
	save_game_state()


func mark_quest_done(quest_id: String) -> void:
	var qs = game_state.get(quest_id)
	if qs == null:
		push_error("DialogueSystem: quest '%s' not found" % quest_id)
		return
	qs["status"] = "done"
	qs["current_step"] = ""
	quest_updated.emit(quest_id, "done", "")
	save_game_state()


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
	save_game_state()


func _find_npc(npc_id: String) -> Dictionary:
	for npc in dimension.get("npcs", []):
		if npc.get("id") == npc_id:
			return npc
	
	# Try auto-correcting/loading the correct dimension based on NPC ID
	var correct_dim := ""
	if npc_id in ["npc_marchand_moyenage", "npc_roi_moyenage", "npc_aubergiste_moyenage", "npc_femme_parc", "npc_assassin"]:
		correct_dim = "res://MoyenAge/dimension_moyenage.json"
	elif npc_id in ["npc_securite_present", "npc_securite_present_retour", "npc_secretaire_present"]:
		correct_dim = "res://Present/dimension_present.json"
	elif npc_id in ["npc_punk_futur", "npc_cheffe_futur", "npc_koiai2_futur", "npc_vukovi_futur", "npc_boss_futur"]:
		correct_dim = "res://Futur/dimension_futur.json"
	elif npc_id in ["npc_guide_hub"]:
		correct_dim = "res://HUB Central/dimension_hub.json"
	
	if correct_dim != "":
		print("[DialogueSystem] PNJ '%s' not in current dimension. Auto-loading %s..." % [npc_id, correct_dim])
		load_dimension(correct_dim)
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


func _fallback_keyword_evaluation(text: String) -> int:
	var lower := text.to_lower()
	var pos_count := 0
	var neg_count := 0
	var polite := false
	var has_question := "?" in text
	var words := text.split(" ", false)
	var word_count := words.size()

	var pos_mots = [
		"bonjour", "salut", "merci", "enchanté", "ravi", "gentil",
		"aimable", "sympa", "charmant", "joli", "super", "génial",
		"cool", "ami", "amitié", "j'aime", "adore", "plaisir",
		"content", "heureux", "sourire", "comprend", "écoute",
		"parler", "confiance", "aide", "aider", "magnifique",
		"passionnant", "intéressant", "agréable", "douce", "doux",
		"chaleureux", "merveilleux", "formidable", "excellent",
		"parfait", "bravo", "stp", "svp", "pardon", "excuse", "désolé"
	]

	var neg_mots = [
		"va-t'en", "dégage", "nul", "nulle", "moche", "stupide",
		"idiot", "idiote", "bête", "méchant", "méchante", "horrible",
		"laid", "laide", "tais-toi", "ferme-la", "ennuyeux",
		"ennuyeuse", "fatigant", "déteste", "hais", "haine",
		"ignoble", "vulgaire"
	]

	for mot in pos_mots:
		if mot in lower:
			pos_count += 1

	for mot in neg_mots:
		if mot in lower:
			neg_count += 1

	var polite_mots := ["s'il te plaît", "s'il vous plaît", "merci", "bonjour",
		"bonsoir", "salut", "pardon", "excuse", "désolé", "stp", "svp"]
	for mot in polite_mots:
		if mot in lower:
			polite = true
			break

	if neg_count >= 2:
		return -20
	elif neg_count == 1:
		return -10
	elif pos_count >= 3 and polite and has_question and word_count >= 4:
		return 20
	elif pos_count >= 2 or (pos_count >= 1 and polite):
		return 10
	elif pos_count == 1:
		return 5
	elif pos_count == 0 and neg_count == 0:
		if word_count <= 2:
			return -5
		else:
			return 0
	else:
		return -5


func save_game_state() -> void:
	var current_zone := "hub"
	var main: Node = get_tree().current_scene
	if main and "current_zone" in main:
		current_zone = main.current_zone

	var sub_zone: String = "entree"
	if main:
		if current_zone == "moyenage":
			var ma: Node = main.get_node_or_null("MoyenAge")
			if ma:
				if ma.get_node_or_null("prison_moyen_age") and ma.get_node("prison_moyen_age").is_visible_in_tree():
					sub_zone = "prison"
				elif ma.get_node_or_null("magasin_moyen_age") and ma.get_node("magasin_moyen_age").is_visible_in_tree():
					sub_zone = "magasin"
				elif ma.get_node_or_null("ville_moyen_age") and ma.get_node("ville_moyen_age").is_visible_in_tree():
					sub_zone = "ville"
				elif ma.get_node_or_null("auberge_moyen_age") and ma.get_node("auberge_moyen_age").is_visible_in_tree():
					sub_zone = "auberge"
				elif ma.get_node_or_null("parc_moyen_age") and ma.get_node("parc_moyen_age").is_visible_in_tree():
					sub_zone = "parc"
				elif ma.get_node_or_null("foret") and ma.get_node("foret").is_visible_in_tree():
					sub_zone = "foret"
				elif ma.get_node_or_null("campement") and ma.get_node("campement").is_visible_in_tree():
					sub_zone = "campement"
		elif current_zone == "present":
			var pr: Node = main.get_node_or_null("Present")
			if pr:
				if pr.get_node_or_null("Parking") and pr.get_node("Parking").is_visible_in_tree():
					sub_zone = "parking"
				elif pr.get_node_or_null("Hall") and pr.get_node("Hall").is_visible_in_tree():
					sub_zone = "hall"
				elif pr.get_node_or_null("Couloir") and pr.get_node("Couloir").is_visible_in_tree():
					sub_zone = "couloir"
				elif pr.get_node_or_null("Vestiaire") and pr.get_node("Vestiaire").is_visible_in_tree():
					sub_zone = "vestiaire"
				elif pr.get_node_or_null("SalleMachine") and pr.get_node("SalleMachine").is_visible_in_tree():
					sub_zone = "salle_machine"
				elif pr.get_node_or_null("SalleElectricite") and pr.get_node("SalleElectricite").is_visible_in_tree():
					sub_zone = "salle_electricite"
				elif pr.get_node_or_null("PcControle") and pr.get_node("PcControle").is_visible_in_tree():
					sub_zone = "pc_controle"
		elif current_zone == "futur":
			var fu: Node = main.get_node_or_null("Futur")
			if fu:
				if fu.get_node_or_null("FondSuperette") and fu.get_node("FondSuperette").is_visible_in_tree():
					sub_zone = "superette"
				elif fu.get_node_or_null("SousSol") and fu.get_node("SousSol").is_visible_in_tree():
					sub_zone = "soussol"
				elif fu.get_node_or_null("FondMetro") and fu.get_node("FondMetro").is_visible_in_tree():
					sub_zone = "metro"
				elif fu.get_node_or_null("FondTour") and fu.get_node("FondTour").is_visible_in_tree():
					sub_zone = "tour"
				elif fu.get_node_or_null("FondBureau") and fu.get_node("FondBureau").is_visible_in_tree():
					sub_zone = "bureau"

	var time_aunote_class = load("res://Personnage/TimeAunote.gd")
	var disguised_state := false
	if time_aunote_class:
		disguised_state = time_aunote_class.disguised

	var save_data := {
		"current_zone": current_zone,
		"sub_zone": sub_zone,
		"game_state": game_state,
		"disguised": disguised_state
	}

	var file = FileAccess.open("user://save_game.json", FileAccess.WRITE)
	if file:
		var json_str = JSON.stringify(save_data)
		file.store_string(json_str)
		file.close()
		print("[DialogueSystem] Game successfully saved to user://save_game.json (sub_zone: " + sub_zone + ")")


func load_game_state() -> bool:
	if not FileAccess.file_exists("user://save_game.json"):
		print("[DialogueSystem] No save file found.")
		return false

	var file = FileAccess.open("user://save_game.json", FileAccess.READ)
	if not file:
		return false

	var json_str = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_err = json.parse(json_str)
	if parse_err != OK:
		push_error("[DialogueSystem] JSON Parse Error in save file")
		return false

	var data = json.get_data()
	if not data is Dictionary:
		return false

	# Restore game_state
	var loaded_state = data.get("game_state", {})
	for qid in loaded_state:
		if qid in game_state:
			var loaded_q: Dictionary = loaded_state[qid] as Dictionary
			var current_q: Dictionary = game_state[qid] as Dictionary
			current_q["status"] = loaded_q.get("status", "not_started")
			current_q["current_step"] = loaded_q.get("current_step", "")
			current_q["completed_steps"] = loaded_q.get("completed_steps", [])
			quest_updated.emit(qid, current_q["status"], current_q["current_step"])

	# Restore disguise
	var disguised = data.get("disguised", false)
	var time_aunote_class = load("res://Personnage/TimeAunote.gd")
	if time_aunote_class:
		time_aunote_class.disguised = disguised

	# Transition/Warp to the saved era
	var saved_zone: String = data.get("current_zone", "hub")
	var saved_sub_zone: String = data.get("sub_zone", "")
	var saved_spawn_id: String = "entree"

	if saved_sub_zone != "":
		saved_spawn_id = saved_sub_zone
	else:
		# Fallback logic based on quest states
		if saved_zone == "moyenage":
			var q_piste: Dictionary = game_state.get("quete_piste_assassin", {}) as Dictionary
			var q_deg: Dictionary = game_state.get("quete_deguisement", {}) as Dictionary
			var q_evasion: Dictionary = game_state.get("quete_evasion", {}) as Dictionary
			var q_enquete: Dictionary = game_state.get("quete_enquete_roi", {}) as Dictionary
			
			if q_piste.get("status") == "active" or q_piste.get("status") == "done":
				saved_spawn_id = "ville"
			elif q_deg.get("status") == "active" or q_deg.get("status") == "done":
				saved_spawn_id = "ville"
			elif q_evasion.get("status") == "active":
				saved_spawn_id = "prison"
			elif q_evasion.get("status") == "done":
				saved_spawn_id = "ville"
			elif q_enquete.get("status") == "done":
				saved_spawn_id = "prison"
			else:
				saved_spawn_id = "entree"

		elif saved_zone == "present":
			var q_prep: Dictionary = game_state.get("quete_preparation", {}) as Dictionary
			var q_acc: Dictionary = game_state.get("quete_acces_centrale", {}) as Dictionary
			
			if q_prep.get("status") == "active" or q_prep.get("status") == "done":
				var current_step: String = q_prep.get("current_step", "")
				var completed: Array = q_prep.get("completed_steps", []) as Array
				if current_step == "etape_reparer_electricite" or "etape_reparer_electricite" in completed:
					saved_spawn_id = "salle_electricite"
				elif current_step == "etape_reparer_machines" or "etape_reparer_machines" in completed:
					saved_spawn_id = "salle_machine"
				elif current_step == "etape_aller_vestiaires" or "etape_aller_vestiaires" in completed:
					saved_spawn_id = "vestiaire"
				else:
					saved_spawn_id = "hall"
			elif q_acc.get("status") == "active":
				var current_step: String = q_acc.get("current_step", "")
				if current_step == "etape_chercher_carte" or current_step == "etape_retour_gardien":
					saved_spawn_id = "parking"
				else:
					saved_spawn_id = "entree"
			elif q_acc.get("status") == "done":
				saved_spawn_id = "hall"
			else:
				saved_spawn_id = "entree"

	var main: Node = get_tree().current_scene
	if main and main.has_method("warp_to_era"):
		# Warp to the saved era with resolved spawn ID
		main.warp_to_era(saved_zone, saved_spawn_id)

		# Synchronize active nodes or minigames
		if has_node("/root/WarpSystem"):
			var ws: Node = get_node("/root/WarpSystem")
			if ws:
				ws.update_minigames_status_from_game()
				if ws.has_method("_apply_active_scene_reactions"):
					for key in ws.minigames_status:
						var completed: bool = ws.minigames_status[key] as bool
						ws._apply_active_scene_reactions(key, completed)

	print("[DialogueSystem] Game successfully loaded from user://save_game.json (spawn: " + saved_spawn_id + ")")
	return true
