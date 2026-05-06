# AGENTS.md — timeOnaute (Distortion)

## Project
- Godot 4.6+ standard (GDScript only — **not** .NET)
- 2D game, rendering method: mobile
- Main scene: `res://Main.tscn`
- `.godot/` is gitignored — never commit it

## Architecture
- `Main.tscn` → `Main.gd`: orchestrator — starts HUB, then switches to era on portal exit
- `Personnage/TimeAunote.tscn` — shared player character (`CharacterBody2D`), used by all scenes
- `HUB Central/` — hub world with 3 time-travel portals (jaune/bleue/rouge) and side-room exits
- `MoyenAge/` — medieval era (portal **jaune**)
- `Present/` — present/nuclear era (portal **bleu**)
- `Futur/` — future era (portal **rouge**)
- Each era is a container scene (`Node2D`) that instances `Personnage/TimeAunote.tscn` as its player

## Scene lifecycle
- `Main._process` polls `sceneHUB.started/stopped` — when HUB sets `started = false`, Main reads `sceneHUB.next_scene` ("MoyenAge"/"Present"/"Futur") and starts the matching era
- Era containers manage movement via `_handle_movement(delta)` using `marche_*` inputs, same as HUB
- `can_move` flag prevents input during spawn animation; collision is disabled until animation ends

## Input
- `marche_haut/bas/gauche/droite` — WASD (ZQSD), used everywhere (HUB + eras)
- `ui_up/down/left/right` — arrow keys (built-in, not used in current code)

## Key gotchas
- This project was migrated from Godot.NET (C#) in commit `e817e44`. Never add `.cs` or `.csproj` files.
- `clamp()` returns `Variant` in GDScript — using `:=` for type inference triggers a parse error (warnings as errors). Use `clampf()` for float, `clampi()` for int, or explicit typing `var x: float = clamp(...)`.
- Fake `uid://` strings in `.tscn` `ext_resource` lines cause warnings. Either omit the UID (path-only) or let Godot auto-generate it.
- Scene scripts must use explicit `ext_resource type="GDScript"` in `.tscn` — they were auto-attached in the .NET version.
- Signal connections in `.tscn` use snake_case method names (GDScript convention), not PascalCase.
- Animation track paths in GDScript use `".:property"` format (e.g. `find_track(".:position", 0)`).

## Commands
- Open the project: launch Godot standard (non-.NET), import `project.godot`
- No build/test/lint steps — this is purely a Godot editor project
