# AGENTS.md — timeOnaute (Distortion)

## Project
- Godot 4.6+ standard (GDScript only — **not** .NET)
- 2D game, rendering method: mobile
- Main scene: `res://Main.tscn`
- `.godot/` is gitignored — never commit it

## Architecture
- `Main.tscn` → `Main.gd`: orchestrator — starts HUB, then Prehistory on exit
- `HUB Central/` — hub world with doors (jaune/bleue/rouge) and side exits
- `PorteJaune/` — prehistoric era level (work in progress)
- Each level is a container scene (`Node2D`) that manages a `CharacterBody2D` player

## Input
- `ui_up/down/left/right` — arrow keys (built-in)
- `marche_haut/bas/gauche/droite` — WASD (custom actions in project.godot)
- Both sets are used; code only checks `ui_*` actions

## Key gotchas
- This project was migrated from Godot.NET (C#) in commit `e817e44`. Never add `.cs` or `.csproj` files.
- Animation track paths in GDScript use `".:property"` format (e.g. `find_track(".:position", 0)`)
- Scene scripts must be explicit `ext_resource type="GDScript"` in `.tscn` — they were auto-attached in the .NET version
- Signal connections in `.tscn` use snake_case method names (GDScript convention), not PascalCase

## Commands
- Open the project: launch Godot standard (non-.NET), import `project.godot`
- No build/test/lint steps — this is purely a Godot editor project
