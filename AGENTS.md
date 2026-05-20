# AGENTS.md — Distortion (timeOnaute)

## Project
- Godot 4.6+ standard, **GDScript only** — never `.cs` / `.csproj`
- Main scene: `res://Main.tscn` (check `project.godot`)
- Window: 1024×682, stretch mode `canvas_items`
- `.godot/` and `.env` are gitignored; `.env` holds `OPENROUTER_API_KEY`

## Architecture
- `Main.gd` orchestrates era switching: calls `sceneEra.start()` then `sceneHUB.stop()` (polled via `_process` once `sceneHUB.started` becomes false)
- `warp_to_era(zone, spawn_id)` on `Main` stops current era and starts target
- Eras are `Node2D` containers; each has `start(spawn_id)` and `stop()`
- Player is instanced via `Personaggio/TimeAunote.tscn` inside each era
- `TimeAunote.gd` has `static var disguised` — sprites use `_MA` suffix when disguised
- Physics layers: 1=player, 2=hub_env, 3=moyenage_env, 4=present_env, 5=futur_env

## Autoloads (order in `project.godot`)
- `DialogueSystem` (script), `DialogueUI` (scene), `WarpSystem` (script) — all autoloaded
- `DialogueSystem` loads `dimension_hub.json` in `_ready`; era scenes must call `load_dimension()` on switch
- `WarpSystem` (F2) — always available, not debug-only. Has built-in debug buttons for disguise toggle and badge state

## GDScript Gotchas
- `clamp()` returns `Variant` → parse errors with `:=`. Use `clampf()` / `clampi()`.
- Untyped `Array` access (`arr[i]`) returns `Variant` → `:=` fails. Cast: `var p: Dictionary = arr[i]`.
- Scene scripts need explicit `ext_resource type="GSDcript"` in `.tscn`. Omit fake `uid://` strings.

## Dialogue System
- AI model: `mistralai/mistral-small-3.2-24b-instruct` via OpenRouter (temp 0.7, 256 tokens)
- Response format: `{"response_format": {"type": "json_object"}}` — AI must return `{"text": "...", "action": null|{"type":"...","id":"..."}}`
- **`action_triggered(action: Dictionary)`** signal (not `reply_resolved`). Actions are **validated against actively filtered intentions** only, via `_validate_action()`.
- After **2 messages** (`_message_count >= 2`), if no action was emitted and current intentions have a `"type": "trigger"` action, the system forces it.
- `dialogue_ended` signal is emitted **before** state is cleared (listeners can still read `current_npc_id`)
- Autoloads `DialogueUI` (scene script `DialogueUI.gd`) — always uses `retro_mode = true` (monospace, portrait, typewriter). The non-retro panel is dead code.
- Typewriter: 0.025s per char, skippable on input.
- `dialogue_started` → `get_first_message()` (typewriter accroche) → input enabled

### JSON Format (`dimension_*.json`)
- `npcs[].intentions[].condition` gates dialogue by `quest_id` / `quest_status` / `quest_step` via `filter_intentions()`
- Conditional overrides: `first_message_after`, `fallbacks_after`, `knowledge_after_quest`, `goals_after_quest`
- `quests[]` drive HUD via `quest_updated` signal; `game_state` is rebuilt from JSON on each `load_dimension()`
- `conversation_history` stores last 15 messages

### PNJ Pattern
```gdscript
extends Node2D
@export var npc_id: String       # matches dimension JSON
@export var npc_name: String
@export var portrait_path: String = "res://path/to/portrait.png"
# $ZoneDialogue (CircleShape2D, r=120)
# add_to_group("npc_dialogue") in _ready()
# body_entered → DialogueUI.show_prompt(); body_exited → DialogueUI.hide_prompt()
```

`show_bubble("text")` / `hide_bubble()` optional — used by most PNJs (5s auto-hide timer with white rounded bubble).

## Era notes

### HUB Central
- `start()` → ambient audio from `audio/hub/` (random .mp3/.ogg/.wav); `stop()` → calls `chienHub.stop_idle()` and `pnjHub.stop_idle()`
- Internal portal names: jaune / bleue / rouge. Visual colors (left→right): orange / purple / green.

### MoyenAge
- Quest flow: `quete_enquete_roi` → `quete_evasion` → `quete_deguisement` → `quete_piste_assassin`
- King death (`roi_adieu` action) enables prison ZonePorte monitoring
- `magasin_moyen_age.gd` bug: `_show_disguise_message()` creates a Label with 4.5s fade tween. If `stop()` called before timer fires, the tween freezes (PROCESS_MODE_DISABLED) — must `queue_free()` `_disguise_label` in `stop()`

### Mini-jeux
- **Marchandage** (`MiniJeuMarchandage`): 8 rounds, 5 good + 3 trap items. ← → movement. Fall duration 2.0→0.62s.
- **Écoute aux tables** (`MiniJeuEcouteTables`): Hold/release E to keep cursor in green zone. 3 tables, difficulty increases. Reset all on fail.
- **Crochetage** (`MiniJeuCrochetage`): Press E when indicator in green zone, 5 steps.

## Generateur JSON (`GenerateurJson/`)
- Python web app: `cd GenerateurJson && pip install -r requirements.txt && python app.py` → localhost:8000
- CLI tester: `python distortion_dialogue.py dimensions/dimension_nuclear.json`
- Deploy saves to `dimensions/` AND copies to matching Godot era folder

## Commands
- No build/lint/test pipeline — open `project.godot` in Godot 4.6+ and run with F5
- Validate JSON: `python3 -c "import json; json.load(open('HUB Central/dimension_hub.json'))"`
