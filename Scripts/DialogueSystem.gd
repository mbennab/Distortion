extends Node

# ========================
# Autoload : DialogueSystem
# ========================

signal dialogue_started(npc_id: String, npc_name: String)
signal dialogue_ended
signal dialogue_response(npc_name: String, text: String)
signal dialogue_error(message: String)
signal quest_updated(quest_id: String, status: String, current_step: String)

const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
const MODEL = "mistralai/ministral-3b-2512"
const REQUEST_TIMEOUT = 15.0
const SITE_URL = "http://localhost:8000"
const SITE_NAME = "Distortion"
const AI_SPECIAL_IDS = ["off_topic", "insult"]

var http_request: HTTPRequest
var dimension: Dictionary = {}
var game_state: Dictionary = {}
var current_npc: Dictionary = {}
var current_npc_id: String = ""
var api_key: String = ""
var is_active: bool = false
var pending: bool = false


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
	dimension = json.data
	print("[DialogueSystem] Dimension loaded: %d NPCs, %d quests" % [dimension.get("npcs", []).size(), dimension.get("quests", []).size()])
	init_game_state()


func load_dimension_from_dict(data: Dictionary) -> void:
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
	is_active = true
	dialogue_started.emit(npc_id, npc.get("name", npc_id))


func stop_dialogue() -> void:
	is_active = false
	current_npc = {}
	current_npc_id = ""
	dialogue_ended.emit()


func send_message(player_message: String) -> void:
	if not is_active:
		return
	if current_npc.is_empty():
		return

	var replies = filter_dialogue_bank(current_npc_id)
	print("[DialogueSystem] send_message: '%s' → %d replies" % [player_message, replies.size()])
	if replies.is_empty():
		var fallback = get_fallback(current_npc_id, "default_template")
		dialogue_response.emit(current_npc.get("name", "?"), fallback)
		return

	if api_key == "":
		print("[DialogueSystem] ERROR: no API key")
		dialogue_error.emit("OPENROUTER_API_KEY not set. Set the environment variable or .env file to use dialogue.")
		return

	var system_prompt = current_npc.get("personality", {}).get("prompt_context", "")
	var user_prompt = build_user_prompt(replies, player_message)
	_send_api_request(system_prompt, user_prompt, replies)


func _send_api_request(system_prompt: String, user_prompt: String, replies: Array) -> void:
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
		"temperature": 0.1,
		"max_tokens": 128,
		"response_format": {"type": "json_object"},
	}

	var json_string = JSON.stringify(body)
	print("[DialogueSystem] Sending API request to OpenRouter...")
	var err = http_request.request(OPENROUTER_URL, headers, HTTPClient.METHOD_POST, json_string)
	if err != OK:
		pending = false
		print("[DialogueSystem] ERROR: request() returned %d" % err)
		dialogue_error.emit("Failed to send request: %d" % err)
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
		dialogue_error.emit("API error %d: %s" % [response_code, err_body.left(200)])
		return

	var reply_body = body.get_string_from_utf8()
	print("[DialogueSystem] Response body: %s" % reply_body.left(300))
	var replies = filter_dialogue_bank(current_npc_id)
	var api_response: Dictionary = {}
	var json = JSON.new()
	if json.parse(reply_body) == OK:
		api_response = json.data

	var reply_id = extract_reply_id(api_response)
	print("[DialogueSystem] Extracted reply_id: '%s'" % reply_id)
	var final_text = resolve_reply(reply_id, replies)
	print("[DialogueSystem] Resolved text: '%s'" % final_text.left(100))
	var npc_name = current_npc.get("name", current_npc.get("id", "?"))
	dialogue_response.emit(npc_name, final_text)


func filter_dialogue_bank(npc_id: String) -> Array:
	var npc = _find_npc(npc_id)
	if npc.is_empty():
		return []

	var matches: Array = []
	for reply in npc.get("dialogue_bank", []):
		var cond = reply.get("condition")
		if cond == null or not cond is Dictionary:
			matches.append(reply)
			continue

		var qid = cond.get("quest_id")
		if qid == null or qid == "":
			matches.append(reply)
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

		matches.append(reply)

	return matches


func build_user_prompt(replies: Array, player_message: String) -> String:
	var lines: Array[String] = []
	lines.append('Message du joueur : "%s"' % player_message)
	lines.append("")
	lines.append("Répliques disponibles :")
	for r in replies:
		var rid = r.get("id", "?")
		var intention = r.get("intention", "")
		lines.append("- %s : %s" % [rid, intention])
	lines.append("")
	lines.append('IMPORTANT : réponds UNIQUEMENT avec un objet JSON au format {"id": "<id_replique>"}.')
	lines.append('Si le message du joueur est hors-sujet, réponds {"id": "off_topic"}.')
	lines.append('Si le joueur est insultant ou agressif, réponds {"id": "insult"}.')
	lines.append("N'ajoute AUCUN autre texte avant ou après le JSON.")
	return "\n".join(lines)


func extract_reply_id(api_response: Dictionary) -> String:
	var choices = api_response.get("choices", [])
	if choices.is_empty():
		return ""
	var content = choices[0].get("message", {}).get("content", "").strip_edges()

	var json = JSON.new()
	if json.parse(content) == OK:
		var data = json.data
		if data is Dictionary and "id" in data:
			return data["id"]

	var regex = RegEx.new()
	regex.compile('"id"\\s*:\\s*"([^"]+)"')
	var m = regex.search(content)
	if m:
		return m.get_string(1)

	return ""


func resolve_reply(reply_id: String, filtered_replies: Array) -> String:
	if reply_id == "":
		return get_fallback(current_npc_id, "unknown")

	if reply_id == "off_topic":
		return get_fallback(current_npc_id, "off_topic")

	if reply_id == "insult":
		return get_fallback(current_npc_id, "insult")

	for r in filtered_replies:
		if r.get("id") == reply_id:
			return r.get("text", "[Texte manquant]")

	for r in current_npc.get("dialogue_bank", []):
		if r.get("id") == reply_id:
			return r.get("text", "[Texte manquant]")

	return get_fallback(current_npc_id, "unknown")


func get_fallback(npc_id: String, key: String) -> String:
	var npc = _find_npc(npc_id)
	var npc_fb = npc.get("fallbacks", {})
	var global_fb = dimension.get("global_fallbacks", {})

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
