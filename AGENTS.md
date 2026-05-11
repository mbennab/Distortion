# AGENTS.md — timeOnaute (Distortion)

## Project
- Godot 4.6+ standard (GDScript only — **not** .NET)
- 2D game, rendering method: mobile
- Main scene: `res://Main.tscn`
- `.godot/` is gitignored — never commit it
- `.env` is gitignored — contains `OPENROUTER_API_KEY`, never commit it

## Architecture
- `Main.tscn` → `Main.gd`: orchestrator — starts HUB, then switches to era on portal exit
- `Personnage/TimeAunote.tscn` — shared player character (`CharacterBody2D`), used by all scenes
- `HUB Central/` — hub world with 3 time-travel portals (jaune/bleue/rouge), side-room exits, PNJ Gardien, chien prankeur
- `MoyenAge/` — medieval era (portal **jaune**): roi PNJ, knights, prison sub-zone with lockpicking minigame
- `Present/` — present/nuclear era (portal **bleu**): no PNJ yet
- `Futur/` — future era (portal **rouge**): PNJ futuriste, SousSol sub-zone reachable via escalier
- Each era is a container scene (`Node2D`) that instances `Personnage/TimeAunote.tscn` as its player

## Physics layers
```
layer 1 = "player"          (bit 0, mask  1)
layer 2 = "hub_env"          (bit 1, mask  2)
layer 3 = "moyenage_env"     (bit 2, mask  4)
layer 4 = "present_env"      (bit 3, mask  8)
layer 5 = "futur_env"        (bit 4, mask 16)
```
Each era sets `collision_mask` to its own layer (e.g. HUB→2, MoyenAge→4).

## Scene lifecycle
- `Main._process` polls `sceneHUB.started/stopped` — when HUB sets `started = false`, Main reads `sceneHUB.next_scene` ("MoyenAge"/"Present"/"Futur") and starts the matching era
- Era containers manage movement via `_handle_movement(delta)` using `marche_*` inputs, same as HUB
- `can_move` flag prevents input during spawn animation; collision is disabled until animation ends

## HUB Central
- `TimeAunoteDansHUBCentral.gd` manages the hub: character, PNJ, chien, portals, side doors, particles, and collision limits
- `start()` shows the hub, places character/PNJ/chien at their markers, enables collisions, loads `dimension_hub.json`
- `stop()` hides the hub, disables all collisions (limits, side doors, portal monitoring, PNJ dialogue zone), closes dialogue UI
- Portal bodies: `zonePorteJaune/Bleue/Rouge` — Area2D nodes with `body_entered` signals
- Side doors (`porteGauche`/`porteDroite`): teleport player to opposite side markers
- `_set_collisions_enabled(bool)`: toggles `collision_layer` for limits/doors and `monitoring` for portal zones
- `timerSortie` (1.5s one-shot): triggers fade-out + particles → transition

## MoyenAge specific
- `MoyenAge.gd` starts with spawn animation, loads `dimension_moyenage.json`
- Listens to `DialogueSystem.action_triggered` — when `roi_adieu` triggers, plays the king's death cinematic (knights spawn, accusation label, fade to prison)
- `prison_moyen_age.gd`: lockpicking minigame (press E near door), zone de sortie (locked, "accès futur")
- `pnj_roi.gd`: standard PNJ pattern with `ZoneDialogue`, `show_bubble/hide_bubble`, `add_to_group("npc_dialogue")`

## Futur specific
- `Futur.gd`: escalier zone → `_go_to_basement()` fades out fondFutur, shows SousSol sub-zone
- `pnj_futur.gd`: visual only, no dialogue

## Dialogue System

### Architecture
- **Autoloads**: `DialogueSystem` (logic) + `DialogueUI` (overlay) — `DialogueSystem` loads first (alphabetical), `DialogueUI` connects to its signals in `_ready()`
- **AI model**: `mistralai/ministral-3b-2512` via OpenRouter, temp 0.7, 256 tokens max
- **Format**: AI returns `{"text": "...", "action": null|{"type":"X","id":"Y"}}`
- **Signals**: `action_triggered(action: Dictionary)` replaces the old `reply_resolved(reply_id: String)`

### Flow
```
Player walks near PNJ → ZoneDialogue (Area2D) → "Appuyez sur E" prompt
Press E → DialogueSystem.start_dialogue(npc_id) → dialogue panel opens
Player types message → send_message() → filter_intentions() → build rich system prompt
  → POST OpenRouter → parse {"text","action"} → validate action against NPC intentions
  → emit dialogue_response + action_triggered
  → UI shows bubble + chat history
```

### JSON format (`dimension_*.json`)
```json
"npcs": [{
  "id": "npc_roi_moyenage",
  "name": "Le Roi du Château",
  "personality": {
    "tone": "...",
    "backstory": "...",
    "emotional_state": "mourant, affaibli...",
    "speech": {
      "vouvoiement": true,
      "vocatif": "voyageur",
      "phrases": "très courtes, 1-2 phrases haletantes",
      "expressions": ["tousse entre les mots", "sa voix faiblit"],
	  "interdits": ["ne connais PAS l'assassin"]
    },
	"knowledge": ["il est poignardé", "son royaume se meurt"],
	"goals": ["trouver de l'aide", "appeler ses gardes avant de mourir"],
    "conversation_arc": [
      {"phase": 1, "until_message": 2, "focus": "expliquer ce qui arrive"},
	  {"phase": 2, "until_message": 4, "focus": "chercher de l'aide"},
	  {"phase": 3, "until_message": 5, "focus": "agonie, appeler les gardes"}
    ]
  },
  "intentions": [
    {
	  "id": "roi_adieu",
	  "condition": null,
	  "trigger": "le joueur dit au revoir",
	  "example": "GARDES ! Venez m'aider...",
      "action": {"type": "trigger", "id": "roi_adieu", "description": "Le roi meurt, les gardes arrivent."}
    }
  ],
  "fallbacks": {
    "off_topic": "...",
    "insult": "...",
    "timeout": "...",
    "unknown": "...",
    "default_template": "..."
  }
}]
```

### Key behaviors
- **Historique**: `conversation_history` stores last 15 messages (player+PNJ), sent in each prompt
- **Compteur**: `_message_count` increments per player message, guides `conversation_arc` phases
- **Forçage action**: after 5 messages, if the NPC has a `trigger`-type action but the AI hasn't emitted it, the code forces `action_triggered`
- **Validation**: actions not matching an entry in `intentions[].action` are silently ignored
- **Conversation arc**: phases drive the AI's focus (accueil → questions → conclusion)
- **Filters**: `filter_intentions()` gates replies by `condition.{quest_id,quest_status,quest_step}` matching `game_state`

### PNJ pattern
All PNJs follow the same pattern:
```gdscript
extends Node2D
@export var npc_id: String
@export var npc_name: String
var zone_dialogue: Area2D    # $ZoneDialogue — CircleShape2D, radius 120px
# body_entered → DialogueUI.show_prompt(npc_id, npc_name)
# body_exited → DialogueUI.hide_prompt()
# add_to_group("npc_dialogue") in _ready()
# show_bubble(text) / hide_bubble() with 5s auto-hide timer
# apparition(position) — shows and positions the PNJ
```
DialogueUI finds the active PNJ via `get_tree().get_nodes_in_group("npc_dialogue")`.

## Input
- `marche_haut/bas/gauche/droite` — ZQSD/WASD + arrow keys
- `interagir` — **E** key (physical keycode 69), triggers dialogue or minigames
- `ui_cancel` — Escape, closes dialogue panel

## Key gotchas
- Migrated from Godot.NET in `e817e44`. **Never add `.cs` or `.csproj` files.**
- `clamp()` returns `Variant` → parse errors with `:=`. Use `clampf()` for float, `clampi()` for int.
- Fake `uid://` strings in `.tscn` cause warnings. Omit or let Godot auto-generate.
- Scene scripts need explicit `ext_resource type="GDScript"` in `.tscn`.
- Signal connections in `.tscn` use snake_case (GDScript convention).
- Animation tracks: `find_track(".:property", 0)`.
- `DialogueSystem` autoload must be alphabetically before `DialogueUI`.
- Submodule `Distortion` was removed (orphaned .NET relic) — don't recreate it.

## Commands
- Open: launch Godot standard (non-.NET), import `project.godot`
- Run: F5 or ▶️ in Godot editor
- No build/test/lint steps — purely a Godot editor project
- Validate JSON dimensions: `python3 -c "import json; json.load(open('HUB Central/dimension_hub.json'))"`

## Generateur JSON (`GenerateurJson/`)

Python tools to create, edit, and test dimension JSONs — independent from Godot.

### CLI dialogue tester
```bash
cd GenerateurJson
pip install requests
python distortion_dialogue.py                          # menu interactif
python distortion_dialogue.py dimensions/dimension_nuclear.json  # tester une dimension
python distortion_dialogue.py --new mon_nom            # wizard manuel
python distortion_dialogue.py --ai                     # wizard IA conversationnel
```
- Reads `OPENROUTER_API_KEY` from `../.env` (project root) automatically
- `/npc <id>` select NPC, `/list`, `/state`, `/step <qid> <sid>`, `/history`, `/help`
- Works offline (simulation mode) without API key

### Web editor + AI Studio
```bash
cd GenerateurJson
pip install -r requirements.txt
python app.py                     # → http://localhost:8000
```
- `http://localhost:8000` — dimension editor (CRUD, validation, tree visualization)
- `http://localhost:8000/ai-builder` — AI Studio with 3 tabs:
  - **🧠 Créer** — era quick-start buttons (HUB/MoyenAge/Présent/Futur/Libre) or free description; AI knows the full Distortion lore (4 eras, existing NPCs, trigger mechanics)
  - **📝 Modifier** — load from game folders or workshop, AI edits surgically with full JSON context
  - **🧪 Tester** — NPC dialogue identical to the game; debug bar shows msg count, forced-action countdown, active intentions; quest state pills are clickable to test different branches
- **AI model**: `mistralai/mistral-small-3.2-24b-instruct` via OpenRouter (override with `MODEL` env var)
- **🚀 Déployer** button — saves to `dimensions/` AND copies to the matching Godot folder (hub→`HUB Central/`, moyenage→`MoyenAge/`, nuclear→`Present/`, futur→`Futur/`)
- **Fiches view** — toggle JSON ↔ visual NPC cards + quest list in the preview panel
- **Autosave** — create-mode draft persisted in `localStorage`; Ctrl+S saves to server

### API endpoints (app.py)
- `GET  /api/dimensions` — list workshop dimensions
- `GET  /api/game-dimensions` — list dimensions found in the Godot era folders
- `GET  /api/game-dimensions/{era_key}` — load a game dimension (`hub`, `moyenage`, `nuclear`, `futur`)
- `POST /api/dimensions/{id}/deploy` — atomic save to workshop + copy to Godot folder if era known
- `POST /api/ai-build` — create mode (DISTORTION_LORE + SYSTEM_CREATE, max_tokens 2048)
- `POST /api/ai-modify` — modify mode (DISTORTION_LORE + SYSTEM_MODIFY + full JSON context)
- `POST /api/ai-test` — test mode; accepts `game_state` override `{quest_id:{status,current_step}}`; returns `active_intentions`

### JSON validation
- Server-side: `app.py` `_validate_json()` — checks snake_case IDs, required fields, fallback rules, quest refs
- Live badge in AI Studio preview — click to expand error/warning list
- CLI: `python3 -c "import json; json.load(open('dimensions/dimension_X.json'))"`
- `dimensions/` dir stores workshop `dimension_*.json` files; game files live in their era folders
- `app.py` all saves use atomic write (temp file + rename)
