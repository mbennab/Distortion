# Phrase d'accroche PNJ — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Each PNJ speaks a guiding "phrase d'accroche" (hook message) when first talked to, defined per-NPC in the dimension JSON. Repeat conversations use AI-generated hooks based on conversation history.

**Architecture:** `DialogueSystem` tracks first-contact per NPC via a `_spoken_to` dictionary. When `start_dialogue()` finds a `first_message` field in the NPC JSON and the NPC hasn't been spoken to yet, it stores the message and sets `_spoken_to[npc_id] = true`. `DialogueUI` fetches the message via `get_first_message()` after receiving `dialogue_started`, and displays it with the existing typewriter system. Repeat conversations inject a recall instruction into the AI prompt.

**Tech Stack:** Godot 4 GDScript, JSON-based dimension files

---

### Task 1: DialogueSystem — tracking and first_message logic

**Files:**
- Modify: `Scripts/DialogueSystem.gd:1-115`

- [ ] **Step 1: Add `_spoken_to` and `_current_first_message` fields**

After line 32 (`var _message_count: int = 0`), add:

```gdscript
var _spoken_to: Dictionary = {}
var _current_first_message: String = ""
```

- [ ] **Step 2: Modify `start_dialogue()` to read `first_message`**

Replace the existing `start_dialogue()` method (lines 97-107) with:

```gdscript
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

	if npc.has("first_message") and npc.first_message is String and npc.first_message != "" and not _spoken_to.has(npc.id):
		_current_first_message = npc.first_message
		_spoken_to[npc.id] = true
	else:
		_current_first_message = ""

	dialogue_started.emit(npc_id, npc.get("name", npc_id))
```

- [ ] **Step 3: Add `get_first_message()` method**

After `start_dialogue()`, add:

```gdscript
func get_first_message() -> String:
	var msg = _current_first_message
	_current_first_message = ""
	return msg
```

- [ ] **Step 4: Modify `stop_dialogue()` to reset `_current_first_message`**

Replace line 110-115 with:

```gdscript
func stop_dialogue() -> void:
	is_active = false
	current_npc = {}
	current_npc_id = ""
	conversation_history.clear()
	_current_first_message = ""
	dialogue_ended.emit()
```

- [ ] **Step 5: Modify `_build_system_prompt()` to add recall instruction for repeat conversations**

In `_build_system_prompt()`, after the "RÈGLES" section (after line 410, before the "FORÇAGE TERMINAISON" block), add:

```gdscript
	# --- RAPPEL CONVERSATION ANTÉRIEURE ---
	if _spoken_to.has(current_npc_id):
		lines.append("")
		lines.append("## RAPPEL CONVERSATION ANTÉRIEURE")
		lines.append("Le joueur te reparle après une conversation précédente.")
		lines.append("Commence par une phrase d'accroche naturelle et courte, en rapport avec vos échanges précédents et ce que tu attends de lui.")
		lines.append("Ne répète PAS les sujets déjà abordés.")
```

- [ ] **Step 6: Commit**

```bash
git add Scripts/DialogueSystem.gd
git commit -m "feat: add first_message tracking to DialogueSystem"
```

---

### Task 2: DialogueUI — display accroche with typewriter

**Files:**
- Modify: `Scripts/DialogueUI.gd:361-391` (`_on_dialogue_started`)

- [ ] **Step 1: Add `_display_accroche()` and `_on_accroche_finished()` methods**

After line 391 (after `_set_portrait_size_from_container()`), add:

```gdscript
func _display_accroche(message: String) -> void:
	retro_input_line.editable = false
	retro_message_label.text = ""
	_start_typewriter(message, _on_accroche_finished)


func _on_accroche_finished() -> void:
	retro_input_line.editable = true
	retro_input_line.grab_focus()
```

- [ ] **Step 2: Modify `_on_dialogue_started()` to check for accroche**

Replace the current `_on_dialogue_started()` method (lines 361-391) with:

```gdscript
func _on_dialogue_started(npc_id: String, npc_name: String) -> void:
	current_state = State.ACTIVE
	current_npc_name = npc_name
	prompt_label.visible = false

	for node in get_tree().get_nodes_in_group("npc_dialogue"):
		if node.npc_id == npc_id:
			current_pnj_node = node
			break

	retro_mode = true

	normal_panel.visible = false
	retro_container.visible = true
	retro_name_label.text = npc_name
	retro_message_label.text = ""
	retro_input_line.text = ""
	retro_input_line.editable = true

	var portrait_loaded := false
	if current_pnj_node != null:
		var pp: String = current_pnj_node.get("portrait_path") if current_pnj_node.get("portrait_path") != null else ""
		if pp != "" and ResourceLoader.exists(pp):
			retro_portrait.texture = load(pp)
			portrait_loaded = true
	if not portrait_loaded:
		retro_portrait.texture = _generic_portrait

	_set_portrait_size_from_container()

	var accroche: String = DialogueSystem.get_first_message()
	if accroche != "":
		_display_accroche(accroche)
	else:
		retro_input_line.grab_focus()
```

- [ ] **Step 3: Commit**

```bash
git add Scripts/DialogueUI.gd
git commit -m "feat: display accroche message in retro dialogue UI"
```

---

### Task 3: Add `first_message` to HUB — Gardien du Nexus

**Files:**
- Modify: `HUB Central/dimension_hub.json`

- [ ] **Step 1: Add `first_message` field**

In `HUB Central/dimension_hub.json`, after line 12 (`"name": "Le Gardien du Nexus"`), add:

```json
"first_message": "Bienvenue, voyageur. Trois portails s'offrent à toi : le passé ruisselle encore de sang et de foi, le présent n'est que cendres, et le futur... le futur est un pari. Choisis avec le cœur, mais sache que chaque voie a son prix.",
```

- [ ] **Step 2: Validate the JSON**

Run: `python3 -c "import json; json.load(open('HUB Central/dimension_hub.json')); print('OK')"`
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add HUB\ Central/dimension_hub.json
git commit -m "feat: add first_message to Gardien du Nexus"
```

---

### Task 4: Add `first_message` to MoyenAge — Roi et Marchand

**Files:**
- Modify: `MoyenAge/dimension_moyenage.json`

- [ ] **Step 1: Add `first_message` to Le Roi du Château**

In `MoyenAge/dimension_moyenage.json`, after the line `"name": "Le Roi du Château"` (around line 12 in the Roi section — look for `"id": "npc_roi_moyenage"` and its `"name"`), add:

```json
"first_message": "Approche, étranger… Je suis poignardé, le royaume se meurt. Trouve mes gardes avant qu'il ne soit trop tard… Je t'en supplie…",
```

- [ ] **Step 2: Add `first_message` to Le Marchand**

In `MoyenAge/dimension_moyenage.json`, after the line `"name": "Le Marchand"` (around line 12 — look for `"id": "npc_marchand_moyenage"` and its `"name"`), add:

```json
"first_message": "Ah, un nouveau client ! J'ai des vêtements de première qualité, mais faudra les mériter. Si t'es prêt à marchander, tu sais où me trouver.",
```

- [ ] **Step 3: Validate the JSON**

Run: `python3 -c "import json; json.load(open('MoyenAge/dimension_moyenage.json')); print('OK')"`
Expected: `OK`

- [ ] **Step 4: Commit**

```bash
git add MoyenAge/dimension_moyenage.json
git commit -m "feat: add first_message to Roi and Marchand"
```

---

### Task 5: Add `first_message` to Futur — all 4 PNJs

**Files:**
- Modify: `Futur/dimension_futur.json`

- [ ] **Step 1: Add `first_message` to La mécano (npc_punk_futur)**

In `Futur/dimension_futur.json`, after line 12 (`"name": "La mécano"`), add:

```json
"first_message": "Salut, je suis Nero. J'ai pas trop le temps là, je bricole ma caisse. Si tu veux savoir ce qui se trame, va parler à la Cheffe ou aux autres en bas.",
```

- [ ] **Step 2: Add `first_message` to La Cheffe (npc_cheffe_futur)**

In `Futur/dimension_futur.json`, after line 80 (`"name": "La Cheffe"`), add:

```json
"first_message": "T'es nouveau. Je suis Billie, la Cheffe ici. On prépare un plan pour rentrer dans Kadath et dégager Alfredo. Parle aux autres, on verra après si t'es utile.",
```

- [ ] **Step 3: Add `first_message` to Koiai (npc_koiai2_futur)**

In `Futur/dimension_futur.json`, after line 153 (`"name": "Koiai"`), add:

```json
"first_message": "Enfin un nouveau visage ! Je suis Koiai. On monte un plan pour libérer Kadath du dictateur. La mécano prépare la voiture. Tu veux nous aider ?",
```

- [ ] **Step 4: Add `first_message` to Vukovi (npc_vukovi_futur)**

In `Futur/dimension_futur.json`, after line 229 (`"name": "Vukovi"`), add:

```json
"first_message": "Salut brochacho. Je suis Vukovi, médecin du groupe. Si t'as des blessures, je peux t'aider. Pour le plan, vois la Cheffe — moi je suis juste là pour recoudre.",
```

- [ ] **Step 5: Validate the JSON**

Run: `python3 -c "import json; json.load(open('Futur/dimension_futur.json')); print('OK')"`
Expected: `OK`

- [ ] **Step 6: Commit**

```bash
git add Futur/dimension_futur.json
git commit -m "feat: add first_message to all Futur PNJs"
```
