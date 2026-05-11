# Système de dialogue IA libre — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remplacer le `dialogue_bank` (IA choisit un `reply_id` parmi des répliques pré-écrites) par un système où l'IA génère du texte libre à partir du contexte JSON du PNJ, avec actions structurées pour les events de jeu.

**Architecture:** Refonte de `DialogueSystem.gd` — nouveaux signaux, nouveau prompt IA riche (fiche PNJ + intentions + historique), parsing `{text, action}`, validation des actions. Les JSON de dimension passent de `dialogue_bank` à `intentions` avec `personality` enrichi. `MoyenAge.gd` migre son signal de `reply_resolved` vers `action_triggered`.

**Tech Stack:** Godot 4.6+ GDScript, OpenRouter API (mistralai/ministral-3b-2512)

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `Scripts/DialogueSystem.gd` | Modify | Core refactoring: signaux, prompt IA, parsing, validation |
| `MoyenAge/MoyenAge.gd` | Modify | Signal migration `reply_resolved` → `action_triggered` |
| `MoyenAge/dimension_moyenage.json` | Modify | Nouveau format `intentions` + `personality` enrichi |
| `HUB Central/dimension_hub.json` | Modify | Nouveau format `intentions` + `personality` enrichi |

**Inchangés:** `Scripts/DialogueUI.gd`, `HUB Central/TimeAunoteDansHubCentral.gd`, `pnj_roi.gd`, `pnj_hub.gd`

---

### Task 1: DialogueSystem — signaux, constantes, variables d'état

**Files:**
- Modify: `Scripts/DialogueSystem.gd:7-28`

- [ ] **Step 1: Remplacer le signal `reply_resolved` par `action_triggered`**

Ligne 12, remplacer :
```gdscript
signal reply_resolved(reply_id: String)
```
par :
```gdscript
signal action_triggered(action: Dictionary)
```

- [ ] **Step 2: Remplacer les constantes**

Lignes 14-19, remplacer :
```gdscript
const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
const MODEL = "mistralai/ministral-3b-2512"
const REQUEST_TIMEOUT = 15.0
const SITE_URL = "http://localhost:8000"
const SITE_NAME = "Distortion"
const AI_SPECIAL_IDS = ["off_topic", "insult"]
```
par :
```gdscript
const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
const MODEL = "mistralai/ministral-3b-2512"
const REQUEST_TIMEOUT = 15.0
const SITE_URL = "http://localhost:8000"
const SITE_NAME = "Distortion"
const MAX_TOKENS = 256
const TEMPERATURE = 0.7
const MAX_HISTORY = 15
```

- [ ] **Step 3: Ajouter `conversation_history`**

Ligne 28, après `var pending: bool = false`, ajouter :
```gdscript
var conversation_history: Array[Dictionary] = []
```

- [ ] **Step 4: Vérifier que le fichier est syntaxiquement correct**

Ouvrir le projet dans Godot, vérifier qu'il n'y a pas d'erreur de parsing.

- [ ] **Step 5: Commit**

```bash
git add Scripts/DialogueSystem.gd
git commit -m "feat(dialogue): nouveau signal action_triggered, constantes IA libre, conversation_history"
```

---

### Task 2: DialogueSystem — ajouter `filter_intentions()` et `_build_system_prompt()`

**Files:**
- Modify: `Scripts/DialogueSystem.gd` (après `filter_dialogue_bank`, avant `build_user_prompt`)

- [ ] **Step 1: Remplacer `filter_dialogue_bank` par `filter_intentions`**

Supprimer `filter_dialogue_bank(npc_id: String)` (lignes 205-236) et écrire à la place :

```gdscript
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
```

- [ ] **Step 2: Ajouter `_build_system_prompt()` juste après `filter_intentions`**

```gdscript
func _build_system_prompt(filtered_intentions: Array) -> String:
	var lines: Array[String] = []
	var npc = current_npc
	var pers = npc.get("personality", {})

	lines.append("Tu incarnes un PNJ dans un jeu vidéo. Voici ta fiche :")
	lines.append("")
	lines.append("NOM : %s" % npc.get("name", npc.get("id", "?")))

	var tone = pers.get("tone", "")
	if tone != "":
		lines.append("TON : %s" % tone)

	var backstory = pers.get("backstory", "")
	if backstory != "":
		lines.append("HISTOIRE : %s" % backstory)

	var knowledge = pers.get("knowledge", [])
	if not knowledge.is_empty():
		lines.append("CONNAISSANCES :")
		for k in knowledge:
			lines.append("- %s" % k)

	var style = pers.get("style", "")
	if style != "":
		lines.append("STYLE D'ÉCRITURE : %s" % style)

	lines.append("")
	lines.append("Sujets typiques et exemples de réponse (utilise-les comme guide, pas comme texte à copier) :")
	for intent in filtered_intentions:
		var iid = intent.get("id", "?")
		var trigger = intent.get("trigger", "")
		var example = intent.get("example", "")
		var action = intent.get("action")
		var action_note = "→ AUCUNE action"
		if action != null and action is Dictionary:
			var action_desc = action.get("description", "")
			action_note = "→ ACTION requise : %s" % action_desc
		lines.append("- [%s] %s : \"%s\" %s" % [iid, trigger, example, action_note])

	lines.append("")
	lines.append("RÈGLES IMPÉRATIVES :")
	lines.append('- Tu réponds UNIQUEMENT avec un objet JSON : {"text": "ta réponse en français", "action": null}')
	lines.append('- Si la situation du joueur correspond EXACTEMENT au déclencheur d\'une action marquée "ACTION requise", inclus l\'action : {"text": "...", "action": {"type": "X", "id": "Y"}}')
	lines.append("- Ne parle QUE de ce que le PNJ connaît (voir CONNAISSANCES). N'invente PAS de faits, lieux ou personnages.")
	lines.append("- Si le joueur est hors-sujet ou insultant, réponds en restant dans le personnage.")
	lines.append("- N'utilise PAS d'astérisques, de narration ou de description d'action. Parle UNIQUEMENT comme le personnage.")
	lines.append("- Maximum 3-4 phrases par réponse.")
	lines.append("- Reste cohérent avec l'historique de la conversation.")

	return "\n".join(lines)
```

- [ ] **Step 3: Vérifier la syntaxe**

Pas d'erreur de parsing dans Godot.

- [ ] **Step 4: Commit**

```bash
git add Scripts/DialogueSystem.gd
git commit -m "feat(dialogue): filter_intentions et _build_system_prompt avec contexte PNJ riche"
```

---

### Task 3: DialogueSystem — réécrire `send_message()` et `_build_user_prompt()`

**Files:**
- Modify: `Scripts/DialogueSystem.gd:112-132` et `239-253`

- [ ] **Step 1: Remplacer `send_message()` (lignes 112-132)**

Supprimer l'ancien `send_message` et écrire :

```gdscript
func send_message(player_message: String) -> void:
	if not is_active:
		return
	if current_npc.is_empty():
		return

	print("[DialogueSystem] send_message: '%s'" % player_message)

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
```

- [ ] **Step 2: Remplacer `build_user_prompt()` (lignes 239-253)**

Supprimer l'ancien `build_user_prompt` et écrire :

```gdscript
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
```

- [ ] **Step 3: Vérifier la syntaxe**

- [ ] **Step 4: Commit**

```bash
git add Scripts/DialogueSystem.gd
git commit -m "feat(dialogue): nouveau send_message avec intentions filtrées et historique de conversation"
```

---

### Task 4: DialogueSystem — mettre à jour `_send_api_request()`

**Files:**
- Modify: `Scripts/DialogueSystem.gd` (fonction `_send_api_request`)

- [ ] **Step 1: Remplacer `_send_api_request`**

Supprimer l'ancienne fonction (lignes 135-166) et écrire :

```gdscript
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
```

- [ ] **Step 2: Vérifier la syntaxe**

- [ ] **Step 3: Commit**

```bash
git add Scripts/DialogueSystem.gd
git commit -m "feat(dialogue): _send_api_request avec temperature 0.7 et 256 tokens"
```

---

### Task 5: DialogueSystem — réécrire `_on_request_completed()` + ajouter `_validate_action()`

**Files:**
- Modify: `Scripts/DialogueSystem.gd` (fonction `_on_request_completed`)

- [ ] **Step 1: Remplacer `_on_request_completed()` (lignes 169-202)**

```gdscript
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

	# Parse the AI's JSON response
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
	var action = ai_data.get("action")
	if action != null and action is Dictionary:
		var valid_action = _validate_action(action)
		if not valid_action.is_empty():
			print("[DialogueSystem] Action validée: %s/%s" % [valid_action.type, valid_action.id])
			action_triggered.emit(valid_action)
		else:
			print("[DialogueSystem] Action rejetée (invalide): %s" % str(action))
```

- [ ] **Step 2: Ajouter `_validate_action()` juste après `_on_request_completed`**

```gdscript
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
```

- [ ] **Step 3: Mettre à jour `stop_dialogue()` pour vider l'historique**

Ligne 105-109, remplacer :
```gdscript
func stop_dialogue() -> void:
	is_active = false
	current_npc = {}
	current_npc_id = ""
	dialogue_ended.emit()
```
par :
```gdscript
func stop_dialogue() -> void:
	is_active = false
	current_npc = {}
	current_npc_id = ""
	conversation_history.clear()
	dialogue_ended.emit()
```

- [ ] **Step 4: Vérifier la syntaxe**

- [ ] **Step 5: Commit**

```bash
git add Scripts/DialogueSystem.gd
git commit -m "feat(dialogue): parsing {text, action}, validation actions, historique conversation"
```

---

### Task 6: DialogueSystem — supprimer les fonctions obsolètes

**Files:**
- Modify: `Scripts/DialogueSystem.gd`

- [ ] **Step 1: Supprimer `extract_reply_id()` et `resolve_reply()`**

Supprimer les fonctions `extract_reply_id` (lignes 256-274) et `resolve_reply` (lignes 277-295).

- [ ] **Step 2: Vérifier la syntaxe finale du fichier complet**

Ouvrir dans Godot, vérifier zéro erreur.

- [ ] **Step 3: Commit**

```bash
git add Scripts/DialogueSystem.gd
git commit -m "feat(dialogue): suppression extract_reply_id et resolve_reply obsolètes"
```

---

### Task 7: Mettre à jour `dimension_hub.json`

**Files:**
- Modify: `HUB Central/dimension_hub.json`

- [ ] **Step 1: Remplacer tout le contenu**

```json
{
  "meta": {
    "id": "hub",
    "name": "Hub Central",
    "era": "Hors du temps",
    "description": "Le Nexus temporel, point de convergence de toutes les époques. Trois portails se dressent devant vous.",
    "completed": false
  },
  "npcs": [
    {
      "id": "npc_guide_hub",
      "name": "Le Gardien du Nexus",
      "personality": {
        "tone": "énigmatique, bienveillant. Parle par énigmes et métaphores temporelles. Sait tout sur les portails.",
        "backstory": "Une entité intemporelle qui veille sur les portails du Hub Central depuis que le temps a commencé à se distordre. Ni vivant, ni mort, ni passé, ni futur. Il a vu défiler d'innombrables voyageurs avant le joueur.",
        "knowledge": [
          "les trois portails mènent au Moyen Âge (jaune), au Présent nucléaire (bleu) et au Futur (rouge)",
          "le Moyen Âge est une époque de chevaliers, de peste et de cathédrales",
          "le Présent est un monde ravagé par l'énergie nucléaire",
          "le Futur est un monde de machines et de merveilles technologiques",
          "la Distorsion est une fracture dans le tissu de la réalité, personne n'en connaît la cause exacte",
          "chaque époque contient des PNJ qui peuvent confier des quêtes au joueur",
          "le joueur doit accomplir des quêtes pour lever le voile du temps"
        ],
        "style": "Phrases poétiques, métaphores temporelles. Vouvoie le joueur en l'appelant 'voyageur'. Ton calme et mystérieux."
      },
      "intentions": [
        {
          "id": "guide_presentation",
          "condition": null,
          "trigger": "le joueur se présente ou demande qui est cet étrange personnage",
          "example": "Je suis le Gardien. Ni vivant, ni mort, ni passé, ni futur. Je veille sur ce nexus depuis que le temps a commencé à se distordre. Tu n'es pas le premier voyageur... et tu ne seras pas le dernier.",
          "action": null
        },
        {
          "id": "guide_portails",
          "condition": null,
          "trigger": "le joueur demande ce que sont les portails ou comment voyager dans le temps",
          "example": "Trois portails, trois époques. Le jaune mène au Moyen Âge, là où la foi déplaçait des montagnes. Le bleu te ramènera à ton présent — ou ce qu'il en reste. Le rouge... le rouge est un pari sur l'avenir. Choisis bien, voyageur.",
          "action": null
        },
        {
          "id": "guide_portail_jaune",
          "condition": null,
          "trigger": "le joueur s'intéresse au portail jaune ou au Moyen Âge",
          "example": "Le Moyen Âge. Une époque de chevaliers, de peste et de cathédrales. Le passé a ses propres dangers, mais aussi ses trésors. La connaissance des anciens s'y cache encore.",
          "action": null
        },
        {
          "id": "guide_portail_bleu",
          "condition": null,
          "trigger": "le joueur s'intéresse au portail bleu ou au présent",
          "example": "Le Présent. Ton époque, ou presque. Un monde au bord du gouffre, déchiré par ses propres créations. L'énergie nucléaire a tout ravagé... mais certains disent qu'un remède existe encore.",
          "action": null
        },
        {
          "id": "guide_portail_rouge",
          "condition": null,
          "trigger": "le joueur s'intéresse au portail rouge ou au futur",
          "example": "Le Futur. Un monde de machines et de merveilles technologiques. Mais la technologie n'est pas toujours une alliée. Méfie-toi de ce que tu pourrais y réveiller.",
          "action": null
        },
        {
          "id": "guide_conseil",
          "condition": null,
          "trigger": "le joueur demande un conseil ou de l'aide",
          "example": "Un conseil ? Dans chaque époque, cherche ceux qui savent. Les PNJ que tu rencontreras ont des quêtes à te confier. Accomplis-les, et le voile du temps se lèvera un peu plus.",
          "action": null
        },
        {
          "id": "guide_merci",
          "condition": null,
          "trigger": "le joueur remercie le Gardien",
          "example": "Ne me remercie pas encore, voyageur. Le chemin est long et les distorsions temporelles sont imprévisibles. Reviens me voir quand tu auras besoin de réponses.",
          "action": null
        },
        {
          "id": "guide_mystere",
          "condition": null,
          "trigger": "le joueur demande pourquoi le temps se distord ou pose des questions sur l'histoire du monde",
          "example": "La Distorsion... Personne ne sait vraiment ce qui l'a causée. Certains parlent d'une expérience qui a mal tourné, d'autres d'une fracture dans le tissu même de la réalité. Peut-être que la réponse se trouve à la croisée des trois époques.",
          "action": null
        }
      ],
      "fallbacks": {
        "off_topic": "Le temps est une rivière, pas un étang. Concentre-toi sur ce qui compte vraiment, voyageur.",
        "insult": "Les mots acérés ne blessent pas celui qui a vu défiler les siècles. Calme-toi, et parle-moi de ce qui te préoccupe vraiment.",
        "timeout": "La connexion temporelle s'est rompue. Le flux du temps reprendra bientôt...",
        "unknown": "Tes paroles se perdent dans le vortex temporel. Peut-être peux-tu reformuler ?",
        "default_template": "Je te regarde, voyageur, et je vois un être perdu entre les époques. Que cherches-tu vraiment ?"
      }
    }
  ],
  "quests": [],
  "mini_games": [],
  "items": [],
  "global_fallbacks": {
    "off_topic": "Les couloirs du temps résonnent de questions bien plus importantes. Concentre-toi sur ta quête.",
    "insult": "Le Nexus ignore tes insultes. Ici, seules les actions résonnent à travers les époques.",
    "timeout": "La connexion temporelle est rompue. Le flux du temps reprendra bientôt.",
    "unknown": "Tes paroles se perdent dans le vortex temporel. Essaie de t'exprimer autrement.",
    "default_template": "Le Gardien du Nexus te regarde sans comprendre. Voyageur, tes mots n'ont pas de sens ici."
  }
}
```

- [ ] **Step 2: Vérifier que le JSON est valide**

```bash
python3 -c "import json; json.load(open('HUB Central/dimension_hub.json'))" && echo "JSON valide"
```

- [ ] **Step 3: Commit**

```bash
git add "HUB Central/dimension_hub.json"
git commit -m "feat(dialogue): hub JSON migré vers intentions + personality enrichi"
```

---

### Task 8: Mettre à jour `dimension_moyenage.json`

**Files:**
- Modify: `MoyenAge/dimension_moyenage.json`

- [ ] **Step 1: Remplacer tout le contenu**

```json
{
  "meta": {
    "id": "moyenage",
    "name": "Moyen Âge",
    "era": "Médiévale",
    "description": "Un château fort du Moyen Âge, entre ombres et lumières.",
    "completed": false
  },
  "npcs": [
    {
      "id": "npc_roi_moyenage",
      "name": "Le Roi du Château",
      "personality": {
        "tone": "noble, solennel, mourant. Parle avec lenteur et difficulté, la voix brisée par la douleur.",
        "backstory": "Souverain médiéval usé par les guerres et le poids de la couronne. Il vient de se faire poignarder par un assassin inconnu dans sa propre salle du trône. Il sent la vie le quitter et cherche désespérément de l'aide.",
        "knowledge": [
          "il est en train de mourir, poignardé par un assassin inconnu",
          "son royaume se meurt : récoltes qui pourrissent, bêtes malades, conseillers qui complotent",
          "il a vu des lueurs jaunes étranges dans la chapelle, des murmures sans origine",
          "il soupçonne que le passé et le futur se mélangent",
          "il ignore l'identité de son assassin",
          "son assassin s'est enfui après l'attaque"
        ],
        "style": "Phrases courtes et hachées, entrecoupées de respirations difficiles. Vouvoie le joueur. Ton brisé mais digne. Parfois il tousse ou perd le fil."
      },
      "intentions": [
        {
          "id": "roi_accueil",
          "condition": null,
          "trigger": "le joueur salue le roi ou se présente",
          "example": "Approche... Je n'ai pas le temps de parler, je me vide de mon sang. On m'a poignardé...",
          "action": null
        },
        {
          "id": "roi_etat",
          "condition": null,
          "trigger": "le joueur demande ce qui arrive au roi ou s'il y a un problème",
          "example": "Mon royaume se meurt à petit feu. Les récoltes pourrissent, les bêtes tombent malades, et mes conseillers parlent de sorcellerie. Et voilà qu'on attente à ma vie... Je sens la vie me quitter.",
          "action": null
        },
        {
          "id": "roi_aide",
          "condition": null,
          "trigger": "le joueur propose son aide ou demande une quête",
          "example": "Tu veux m'aider ? Vraiment ? Alors trouve mon assassin ! Il a dû s'enfuir après m'avoir frappé. Fais vite... avant qu'il ne soit trop tard.",
          "action": null
        },
        {
          "id": "roi_portails",
          "condition": null,
          "trigger": "le joueur demande si le roi connaît les portails temporels ou la distorsion",
          "example": "Les portails... J'ai vu des lueurs jaunes dans la chapelle, des murmures qui viennent de nulle part. Peut-être que le passé et le futur se mélangent. Tu viens d'ailleurs, n'est-ce pas ?",
          "action": null
        },
        {
          "id": "roi_adieu",
          "condition": null,
          "trigger": "le joueur dit au revoir ou s'apprête à partir",
          "example": "Je me sens mourir... Je vois la lumière au bout du tunnel. GARDES ! Venez m'aider... J'ai besoin de soutien dans mes derniers instants...",
          "action": {
            "type": "trigger",
            "id": "roi_adieu",
            "description": "Le roi, dans un dernier souffle, appelle ses gardes à l'aide avant de s'éteindre."
          }
        }
      ],
      "fallbacks": {
        "off_topic": "Par la couronne ! Je n'ai plus beaucoup de temps... parle-moi de choses qui comptent.",
        "insult": "Garde ta langue, insolent ! Même mourant, je reste ton roi. Un peu de respect.",
        "timeout": "Le temps... s'arrête... Je ne sens plus rien...",
        "unknown": "Je... je ne comprends pas tes paroles. Ma vision se trouble...",
        "default_template": "Écoute, voyageur, je ne suis pas d'humeur à jouer aux devinettes. Que veux-tu vraiment ?"
      }
    }
  ],
  "quests": [],
  "mini_games": [],
  "items": [],
  "global_fallbacks": {
    "off_topic": "Les murs du château résonnent de questions plus urgentes.",
    "insult": "Le roi ignore tes insultes.",
    "timeout": "La connexion temporelle est rompue.",
    "unknown": "Tes paroles se perdent dans les couloirs du château.",
    "default_template": "Le Roi te regarde sans comprendre. Voyageur, que dis-tu ?"
  }
}
```

- [ ] **Step 2: Vérifier que le JSON est valide**

```bash
python3 -c "import json; json.load(open('MoyenAge/dimension_moyenage.json'))" && echo "JSON valide"
```

- [ ] **Step 3: Commit**

```bash
git add "MoyenAge/dimension_moyenage.json"
git commit -m "feat(dialogue): moyenage JSON migré vers intentions + action roi_adieu"
```

---

### Task 9: Mettre à jour `MoyenAge.gd` — migration du signal

**Files:**
- Modify: `MoyenAge/MoyenAge.gd:27,165-169`

- [ ] **Step 1: Remplacer la connexion de signal dans `_ready()`**

Ligne 27, remplacer :
```gdscript
	DialogueSystem.reply_resolved.connect(_on_reply_resolved)
```
par :
```gdscript
	DialogueSystem.action_triggered.connect(_on_action_triggered)
```

- [ ] **Step 2: Remplacer le handler de signal**

Lignes 165-169, remplacer :
```gdscript
func _on_reply_resolved(reply_id: String) -> void:
	if not started or _roi_adieu_triggered:
		return
	if reply_id == "roi_adieu":
		_trigger_roi_adieu_sequence()
```
par :
```gdscript
func _on_action_triggered(action: Dictionary) -> void:
	if not started or _roi_adieu_triggered:
		return
	if action.get("type") == "trigger" and action.get("id") == "roi_adieu":
		_trigger_roi_adieu_sequence()
```

- [ ] **Step 3: Vérifier la syntaxe dans Godot**

- [ ] **Step 4: Commit**

```bash
git add "MoyenAge/MoyenAge.gd"
git commit -m "feat(dialogue): MoyenAge migré de reply_resolved vers action_triggered"
```

---

### Task 10: Vérification finale — lancer le projet

- [ ] **Step 1: Ouvrir le projet dans Godot et lancer (F5)**

Vérifier :
1. Le HUB charge sans erreur
2. Parler au Gardien : le prompt "Appuyez sur E" apparaît
3. Envoyer un message : l'IA répond avec du texte libre (pas juste un ID)
4. Aller au Moyen Âge (portail jaune)
5. Parler au Roi, dire au revoir → la séquence prison doit se déclencher
6. Vérifier qu'il n'y a pas d'erreurs dans la console Godot

- [ ] **Step 2: Commit final si tout fonctionne**

```bash
git status
git add -A
git commit -m "feat(dialogue): vérification finale du système IA libre"
```
