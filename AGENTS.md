# AGENTS.md — timeOnaute (Distortion)

## Project
- Godot 4.6+ standard (GDScript only — **never** .NET / `.cs`)
- Main scene: `res://Main.tscn`
- `.godot/` and `.env` are gitignored — never commit

## Architecture
- `Main.gd` orchestrates HUB → era switching via `sceneHUB.next_scene`
- Eras are `Node2D` containers instancing `Personnage/TimeAunote.tscn`
- `can_move` disables input during spawn; collision disabled until animation ends
- Physics layers: 1=player, 2=hub_env, 3=moyenage_env, 4=present_env, 5=futur_env. Each era masks to its own layer.

## Autoloads (alphabetical order matters)
- `DialogueSystem` must load **before** `DialogueUI` (alphabetical in `project.godot`)
- `WarpSystem` — debug teleport (F2), add as child of `Main` manually in debug builds

## Input
- `marche_haut/bas/gauche/droite` — ZQSD/WASD + arrows
- `interagir` — physical keycode 69 (E)

## GDScript Gotchas
- `clamp()` returns `Variant` → parse errors with `:=`. Use `clampf()` / `clampi()`.
- Untyped `Array` access (`arr[i]`) returns `Variant` → `:=` fails. Use `var p: Dictionary = arr[i]`.
- Fake `uid://` strings in `.tscn` cause warnings. Omit or let Godot auto-generate.
- Scene scripts need explicit `ext_resource type="GDScript"` in `.tscn`.
- Signal connections in `.tscn` use `snake_case`.
- Animation tracks: `find_track(".:property", 0)`.

## Dialogue System
- Autoloads `DialogueSystem` (logic) + `DialogueUI` (overlay)
- AI model: `mistralai/ministral-3b-2512` via OpenRouter (temp 0.7, 256 tokens)
- NPC data lives in `dimension_*.json` inside each era folder
- Signals: `action_triggered(action: Dictionary)` (not `reply_resolved`)

### JSON Format (`dimension_*.json`)
- `npcs[].intentions[].condition` gates dialogue by `quest_id` / `quest_status` / `quest_step`
- Conditional fields override defaults when quest state matches:
  - `first_message_after`, `fallbacks_after`, `knowledge_after_quest`, `goals_after_quest`
- `quests[]` drive the HUD via `quest_updated` signal
- `conversation_history` stores last 15 messages
- After 5 messages, if NPC has a `trigger`-type action, the code forces `action_triggered`
- Actions not matching an entry in `intentions[].action` are silently ignored

### PNJ Pattern
All PNJs follow this boilerplate:
```gdscript
extends Node2D
@export var npc_id: String
@export var npc_name: String
@export var portrait_path: String = ""
# $ZoneDialogue (CircleShape2D, r=120)
# add_to_group("npc_dialogue") in _ready()
# body_entered → DialogueUI.show_prompt(); body_exited → DialogueUI.hide_prompt()
```

## Era-specific notes

### HUB Central
- Internal portal names: jaune / bleue / rouge. Visual colors left-to-right: **orange / purple / green**.
- `stop()` must call `chienHub.stop_idle()` and `pnjHub.stop_idle()` to kill timers/audio.
- Ambient audio scans `audio/hub/` for `.mp3/.ogg/.wav` at random on `start()`.

### MoyenAge
- Quest flow gates NPC intentions: `quete_enquete_roi` → `quete_evasion` → `quete_deguisement` → `quete_piste_assassin`
- King death cinematic (`roi_adieu` action) enables prison lockpicking zone (`ZonePorte.monitoring`)
- `magasin_moyen_age.gd` bug: `_show_disguise_message()` creates a Label with a 4.5s fade timer. If `stop()` is called before timer fires, `_disguise_label` must be `queue_free()`d or it persists forever because `PROCESS_MODE_DISABLED` freezes the tween.

## Generateur JSON (`GenerateurJson/`)
- Python tools independent from Godot
- Web editor: `cd GenerateurJson && pip install -r requirements.txt && python app.py` → `localhost:8000`
- AI Studio: `localhost:8000/ai-builder` (create / modify / test dimensions)
- Deploy button saves to `dimensions/` AND copies to the matching Godot era folder
- CLI tester: `python distortion_dialogue.py dimensions/dimension_nuclear.json`

## Commands
- Open: launch Godot standard, import `project.godot`
- Run: F5 or ▶️ in editor
- No build/test/lint steps
- Validate JSON: `python3 -c "import json; json.load(open('HUB Central/dimension_hub.json'))"`

## Hard constraints
- Never add `.cs` or `.csproj` files
- Never recreate the old `Distortion` submodule (orphaned .NET relic)
- ContextScout subagent is **BANNED** — causes systematic bugs
