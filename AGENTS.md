# AGENTS.md — timeOnaute (Distortion)

## Project
- Godot 4.6+ standard (GDScript only — **not** .NET)
- 2D game, rendering method: mobile
- Main scene: `res://Main.tscn`
- `.godot/` is gitignored — never commit it

## Architecture
- `Main.tscn` → `Main.gd`: orchestrator — starts HUB, then switches to era on portal exit
- `Personnage/TimeAunote.tscn` — shared player character (`CharacterBody2D`), used by all scenes
- `HUB Central/` — hub world with 3 time-travel portals (jaune/bleue/rouge), side-room exits, PNJ, and chien prankeur
- `MoyenAge/` — medieval era (portal **jaune**)
- `Present/` — present/nuclear era (portal **bleu**)
- `Futur/` — future era (portal **rouge**)
- Each era is a container scene (`Node2D`) that instances `Personnage/TimeAunote.tscn` as its player

## Scene lifecycle
- `Main._process` polls `sceneHUB.started/stopped` — when HUB sets `started = false`, Main reads `sceneHUB.next_scene` ("MoyenAge"/"Present"/"Futur") and starts the matching era
- Era containers manage movement via `_handle_movement(delta)` using `marche_*` inputs, same as HUB
- `can_move` flag prevents input during spawn animation; collision is disabled until animation ends

## HUB Central details
- `TimeAunoteDansHUBCentral.gd` manages the hub: character, PNJ, chien, portals, side doors, particles, and collision limits
- `start()` shows the hub, places character/PNJ/chien at their markers, enables collisions
- `stop()` hides the hub and disables all collisions (limits, side doors, portal monitoring) — prevents interference when an era is active
- Portal bodies: `zonePorteJaune/Bleue/Rouge` — Area2D nodes with `body_entered` signals connected in `_connect_portal_signals()`
- Side doors (`porteGauche`/`porteDroite`): teleport player to opposite side markers on collision
- `_set_collisions_enabled(bool)`: toggles `collision_layer` for limits/doors and `monitoring` for portal zones
- `timerSortie` (1.5s one-shot): triggers fade-out + transition; timeout calls `_on_timer_sortie_timeout()`

## Entities in HUB
- **pnj-hub**: `Node2D` with `AnimatedSprite2D`, idle animation. Hidden by default, shown via `apparition(position)` called from `start()`
- **chien-hub**: `Node2D` with `AnimatedSprite2D` (sprite sheet, 2-frame atlas textures), idle-dog animation. Same apparition pattern
- Both are instanced in `TimeAunoteDansHubCentral.tscn`, positions set from `fondHubCentral/Markers2D/pnjPos` and `chienPos`

## Input
- `marche_haut/bas/gauche/droite` — WASD (ZQSD), used everywhere (HUB + eras)
- `ui_up/down/left/right` — arrow keys (built-in, not used in current code)

## Key gotchas
- This project was migrated from Godot.NET (C#) in commit `e817e44`. Never add `.cs` or `.csproj` files.
- `clamp()` returns `Variant` in GDScript — using `:=` for type inference triggers a parse error (warnings as errors). Use `clampf()` for float, `clampi()` for int, or explicit typing `var x: float = clamp(...)`.
- Fake `uid://` strings in `.tscn` `ext_resource` lines cause warnings. Either omit the UID (path-only) or let Godot auto-generate it.
- Scene scripts must use explicit `ext_resource type="GDScript"` in `.tscn` — they were auto-attached in the .NET version.
- Signal connections in `.tscn` use snake_case method names (GDScript convention), not PascalCase.
- Animation track paths in GDScript use `".:property"` format (e.g. `find_track(".:property", 0)`).

## Commands
- Open the project: launch Godot standard (non-.NET), import `project.godot`
- No build/test/lint steps — this is purely a Godot editor project
