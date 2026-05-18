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
- `HUB Central/` — hub world with 3 time-travel portals (jaune/bleue/rouge internally, visualized as green/purple/orange left-to-right), PNJ Gardien, chien interactif
- `MoyenAge/` — medieval era (portal **jaune**): roi PNJ, knights, prison sub-zone with lockpicking minigame, marchand PNJ in magasin
- `Present/` — present/nuclear era (portal **bleu**): no PNJ yet
- `Futur/` — future era (portal **rouge**): 2 PNJs (pnj-futur, pnj-cheffe), SousSol sub-zone reachable via escalier
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
- `TimeAunoteDansHUBCentral.gd` manages the hub: character, PNJ, chien, portals, particles, ambient audio, and collision limits
- `start()` shows the hub, places character/PNJ/chien at their markers, enables collisions, loads `dimension_hub.json`, starts portal glow tweens and ambient audio
- `stop()` hides the hub, disables all collisions, stops portal glows + ambient audio, calls `chienHub.stop_idle()` and `pnjHub.stop_idle()` to kill timers/audio, closes dialogue UI
- **Portals**: `zonePorteJaune/Bleue/Rouge` — Area2D nodes with `body_entered` signals. Visual glow is procedural (radial gradient sprites with breathing tween). Internal names are jaune/bleue/rouge but visual colors are **orange/purple/green** left‑to‑right.
- **Ambient audio**: `_setup_ambient_audio()` scans `audio/hub/` for `.mp3`/`.ogg`/`.wav`, picks one at random on `start()`, loops it. Volume -8dB. No file → silent skip.
- `_set_collisions_enabled(bool)`: toggles `collision_layer` for limits and `monitoring` for portal zones + chien Area2D + PNJ ZoneDialogue
- `timerSortie` (1.5s one-shot): triggers fade-out + particles → transition
- **Chien**: `chien_hub.gd` — E key shows bark bubble (random "Wouf !" variations), speed_scale 7.0 during bark / 2.0 normal. Auto-loads audio from `audio/chien/` (any `.mp3`/`.ogg`/`.wav` files played randomly on bark). Spontaneous idle barks every 10-30s when not nearby and no bubble visible.
- **Gardien** (`pnj_hub.gd`): standard PNJ pattern + idle murmurs every 15-35s (10 enigmatic phrases). Murmur bubble matches chien style (font 28, offset next to sprite). Guarded: skips if player nearby, bubble visible, or dialogue active.

## MoyenAge specific
- `MoyenAge.gd` starts with spawn animation, loads `dimension_moyenage.json`
- **Quest HUD**: `DialogueSystem.quest_updated` connected to `_update_objective()` — step descriptions drive the top-right objective display
- **4 quests**: `quete_enquete_roi` (talk to king) → `quete_evasion` (escape prison) → `quete_deguisement` (get disguise from merchant) → `quete_piste_assassin` (follow assassin's trail). Quest progression gates NPC intentions (e.g. Marchand switches from wardrobe talk to tavern directions post-disguise)
- Listens to `DialogueSystem.action_triggered` — when `roi_adieu` triggers, plays the king's death cinematic (knights spawn, accusation label, fade to prison)
- `prison_moyen_age.gd`: lockpicking minigame (press E near door), zone de sortie (locked, "accès futur")
  - **Lockpicking gated**: `ZonePorte.monitoring` disabled in `_ready()`, only enabled after king death cinematic (`_trigger_roi_adieu_sequence`)
  - **Minigame cleanup**: `stop_minigame()` frees the CanvasLayer instance; `MoyenAge.stop()` calls it on era exit
  - `MiniJeuCrochetage.gd`: guards `_input()` with `is_inside_tree()` to prevent stray input capture
- `pnj_marchand.gd`: standard PNJ pattern in `magasin_moyen_age` sub-zone (reachable after escaping prison)
- `magasin_moyen_age.gd`: shop sub-zone — manages `zoneHabits` Area2D, prompts "E pour marchander", instantiates `MiniJeuMarchandage`
  - **Quest integration**: `_on_dialogue_started` calls `DialogueSystem.complete_step("etape_parler_marchand")`; on minigame success calls `complete_step("etape_marchander")` + `mark_quest_done("quete_deguisement")` — this transitions quest status from `not_started` to `done`, which makes `filter_intentions()` swap the Marchand's active intentions from wardrobe-focused to tavern-focused
  - **MiniJeuMarchandage** (`Scripts/MiniJeuMarchandage.gd`, ~660 lines): CanvasLayer-based catching minigame (single phase)
    - **8 rounds** total: 5 good items to catch + 3 decoys (red, ⚠) to dodge
    - Win condition: `good_catches >= 4 AND decoy_caught <= 1` → `done(true)`
    - **Difficulty curve**: fall duration 2.0s → 0.62s, catch radius constant 55px across rounds
    - **Parabolic trajectory** with random arc height (clamped to viewport) and lateral wobble that grows with round index
    - **Merchant moves** between 4 horizontal positions each round; throw originates from merchant position
    - **Player sprites**: `perso_idle_face.png` / `perso_marche_face1/2.png` (hframes=2, frame=0), animated on move
    - **Merchant sprite**: `art/MoyenAge/marchand.png` (hframes=2, frame=0), bobs vertically, tilts during wind-up
    - No landing-zone indicator — player must track item visually
    - FX: screen shake, golden flash on catch, red flash on decoy hit, dust particles, torch ambiance
    - Persistent `_obj_lbl` shows `🎯 X/4 vêtements · ⚠ Y/2 piège(s)` updated each round
    - 3-second intro screen shows objectives before first throw
    - `ROUND_PARAMS` const array drives per-round `[fall_duration, catch_radius, anticip_time]`
    - Emits `done(success: bool)` — interface unchanged, `magasin_moyen_age.gd` requires no edits
	- **Known calibration**: `PLAYER_SPEED = 720`, landing zone margins 110px — worst-case distance (402px) always reachable in every round's fall duration
- `pnj_roi.gd`: standard PNJ pattern with `ZoneDialogue`, `show_bubble/hide_bubble`, `add_to_group("npc_dialogue")`

## Futur specific
- `Futur.gd`: escalier zone → `_go_to_basement()` fades out fondFutur, shows SousSol sub-zone
- `pnj_futur.gd`: visual only, no dialogue

## Debug tools
- **WarpSystem** (`Scripts/WarpSystem.gd`): press **F2** to open teleport menu — warp to any zone/spawn point. Added as a child of `Main` node (not in Main.tscn by default — instantiate manually in debug builds). Calls `Main.warp_to_era(zone, spawn_id)`.

## Dialogue System

### Architecture
- **Autoloads**: `DialogueSystem` (logic) + `DialogueUI` (overlay) — `DialogueSystem` loads first (alphabetical), `DialogueUI` connects to its signals in `_ready()`
- **AI model**: `mistralai/ministral-3b-2512` via OpenRouter, temp 0.7, 256 tokens max
- **Format**: AI returns `{"text": "...", "action": null|{"type":"X","id":"Y"}}`
- **Signals**: `action_triggered(action: Dictionary)` replaces the old `reply_resolved(reply_id: String)`

### Flow
```
Player walks near PNJ → ZoneDialogue (Area2D) → "Appuyez sur E" prompt
Press E → DialogueSystem.start_dialogue(npc_id) → dialogue panel opens (retro UI, bottom of screen)
  → if first_time AND npc has first_message → typewriter accroche → then focus input
  → else focus input directly
Player presses Enter → typewriter animates "> message" → send_message() → filter_intentions() → build rich system prompt
  → POST OpenRouter → parse {"text","action"} → validate action against NPC intentions
  → emit dialogue_response + action_triggered
  → UI shows PNJ reply with typewriter effect (monospace, portrait on left, no scrollable history)
```

### Phrase d'accroche (`first_message`)
- Each NPC can have an optional `"first_message"` (string) in the dimension JSON
- `first_message_after` (object `{quest_id, quest_status, message}`) overrides it when the quest condition is met
- On first-ever dialogue with that NPC, the message is displayed via typewriter immediately after opening
- Input is disabled during the accroche; player can skip with Enter
- On subsequent dialogues, `_has_repeat_conversation` flag injects a recall instruction into the AI prompt so the AI generates a contextual greeting based on conversation history
- Tracking is session-only via `_spoken_to: Dictionary` (cleared on `load_dimension()`)
- If `first_message` is absent or empty, no accroche is shown (backward-compatible)

### Dialogue UI (universal retro mode)
- All zones use the same retro-style interface (previously Futur-only): bottom panel, monospace "Courier New" font, double-border bezel
- NPC portrait displayed on the left side of the panel
- Single message at a time with typewriter animation (0.025s/char), skippable via Enter
- Player input: transparent LineEdit, Enter to submit (no "Envoyer" button)

### Portraits
- Each PNJ has `@export var portrait_path: String = ""` — set in the `.gd` script or via Godot inspector on the `.tscn` instance
- If `portrait_path` is a valid `res://` path to a PNG, that image loads as the portrait
- If empty or file missing, a programmatic generic silhouette is generated
- Convention: place portraits in `art/<Era>/pnj-<name>-HD.png`, ~370x640 PNG

### JSON format (`dimension_*.json`)
```json
{
  "meta": { "id": "moyenage", "name": "Moyen Âge", "era": "...", "description": "...", "completed": false },
  "npcs": [{
    "id": "npc_roi_moyenage",
    "name": "Le Roi du Château",
	"first_message": "Approche… on m'a poignardé…",
	"personality": {
	  "tone": "...",
	  "backstory": "...",
	  "emotional_state": "mourant...",
	  "speech": { "vouvoiement": true, "vocatif": "voyageur", "phrases": "...", "expressions": [...], "interdits": [...] },
	  "knowledge": ["il est poignardé", "son royaume se meurt"],
	  "goals": ["trouver de l'aide", "appeler ses gardes avant de mourir"],
      "conversation_arc": [
        {"phase": 1, "until_message": 2, "focus": "expliquer ce qui arrive"},
		{"phase": 2, "until_message": 4, "focus": "chercher de l'aide"},
		{"phase": 3, "until_message": 5, "focus": "agonie, appeler les gardes"}
      ]
    },
	"intentions": [{
	  "id": "roi_adieu",
	  "condition": {"quest_id": "quete_x", "quest_status": "active", "quest_step": "etape_y"},
	  "trigger": "le joueur dit au revoir",
	  "example": "GARDES ! Venez m'aider...",
      "action": {"type": "trigger", "id": "roi_adieu", "description": "Le roi meurt."}
    }],
    "fallbacks": { "off_topic": "...", "insult": "...", "timeout": "...", "unknown": "...", "default_template": "..." },
	"first_message_after": { "quest_id": "quete_x", "quest_status": "done", "message": "..." },
	"fallbacks_after": { "quest_id": "quete_x", "quest_status": "done", "fallbacks": { "off_topic": "..." } },
	"knowledge_after_quest": { "quest_id": "quete_x", "quest_status": "done", "knowledge": ["..."] },
	"goals_after_quest": { "quest_id": "quete_x", "quest_status": "done", "goals": ["..."] }
  }],
  "quests": [{
    "id": "quete_enquete_roi",
	"title": "Enquêter sur l'assassinat du roi",
	"status": "not_started",
	"requires_quests": [],
	"steps": [
	  {"id": "etape_parler_roi", "description": "Parler au roi mourant", "completed": false},
	  {"id": "etape_indices", "description": "Recueillir des indices", "completed": false}
    ]
  }],
  "mini_games": [],
  "items": [],
  "global_fallbacks": { "off_topic": "...", "insult": "...", "timeout": "...", "unknown": "...", "default_template": "..." }
}
```
- `first_message` : optional string — displayed as a typewriter accroche on first-ever dialogue with the NPC
- `first_message_after` : optional object `{quest_id, quest_status, message}` — overrides `first_message` when the specified quest has the given status
- `fallbacks_after` : optional object `{quest_id, quest_status, fallbacks: {...}}` — overrides `fallbacks` when the specified quest has the given status
- `knowledge_after_quest` : optional object `{quest_id, quest_status, knowledge: [...]}` — replaces `knowledge` in the AI prompt when the quest has the given status
- `goals_after_quest` : optional object `{quest_id, quest_status, goals: [...]}` — replaces `goals` in the AI prompt when the quest has the given status
- `intentions[].condition` : optional gate `{quest_id, quest_status, quest_step}` — all three are optional; null → always active. Used for quest-conditional dialogue (e.g. Marchand talks about wardrobe until quete_deguisement is done, then talks about tavern)
- `quests[]` : drive the objective HUD via `quest_updated` signal. `DialogueSystem.complete_step(quest_id, step_id)` advances steps; `mark_quest_done()` closes the quest
- All `condition` fields must match `game_state` for the intention to appear in the AI prompt

### Key behaviors
- **Historique**: `conversation_history` stores last 15 messages (player+PNJ), sent in each prompt
- **Compteur**: `_message_count` increments per player message, guides `conversation_arc` phases
- **Forçage action**: after 5 messages, if the NPC has a `trigger`-type action but the AI hasn't emitted it, the code forces `action_triggered`
- **Validation**: actions not matching an entry in `intentions[].action` are silently ignored
- **Conversation arc**: phases drive the AI's focus (accueil → questions → conclusion)
- **Filters**: `filter_intentions()` gates replies by `condition.{quest_id,quest_status,quest_step}` matching `game_state`
- **Accroche**: `first_message` shown on first dialogue; subsequent dialogues use AI-generated hook via `_has_repeat_conversation` prompt injection
- **Conditional fields**: `fallbacks_after`, `knowledge_after_quest`, `goals_after_quest` override NPC defaults when a quest condition is met
- **Quest state injection**: `_build_system_prompt()` injects `## ÉTAT ACTUEL DU JEU (RÉALITÉ)` section so the AI can verify player claims against actual quest status
- **Quest HUD**: `quest_updated` signal connected to era's `_update_objective()` — step descriptions appear in top-right HUD. Quest states in `game_state` drive intention filtering for context-aware dialogue (e.g. post-disguise Marchand switches from wardrobe to tavern)

### PNJ pattern
All PNJs follow the same pattern:
```gdscript
extends Node2D
@export var npc_id: String
@export var npc_name: String
@export var portrait_path: String = ""
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
- Dictionary access (`arr[i]` with `arr` untyped) returns `Variant` → `:=` inference fails. Use explicit type: `var p: Dictionary = arr[i]`.
- Fake `uid://` strings in `.tscn` cause warnings. Omit or let Godot auto-generate.
- Scene scripts need explicit `ext_resource type="GDScript"` in `.tscn`.
- Signal connections in `.tscn` use snake_case (GDScript convention).
- Animation tracks: `find_track(".:property", 0)`.
- `DialogueSystem` autoload must be alphabetically before `DialogueUI`.
- Submodule `Distortion` was removed (orphaned .NET relic) — don't recreate it.
- ContextScout subagent is BANNED — it causes systematic bugs. Never use it.

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
