# 🔴 CRITIQUE / 🟠 HAUTE — Futur : Bugs bloquants

**Sévérité :** 3 CRITIQUES, 4 HAUTE

---

## C15 — Division par zéro si textures obstacle absentes

**Fichier :** `Futur/route.gd:147`
**Sévérité :** 🔴 CRITIQUE

### Le Bug
```gdscript
var tex_index = randi() % obstacle_textures.size()
```

Si les 3 fichiers `res://art/Futur/obstacle1.png`, `obstacle2.png`, `obstacle3.png` sont absents, `obstacle_textures` est une liste vide (`[]`). `randi() % 0` = **division par zéro** = crash runtime.

### Correction
```gdscript
if obstacle_textures.is_empty():
    return
var tex_index = randi() % obstacle_textures.size()
```

---

## C16 — `texture.get_size()` sur null dans GardeEtage

**Fichier :** `Scripts/GardeEtage.gd:77`
**Sévérité :** 🔴 CRITIQUE

### Le Bug
```gdscript
var tex := load("res://art/Futur/gardeGauche.png") as Texture2D
_sprite.texture = tex
var tex_size := tex.get_size()     # CRASH si tex == null
```

`load()` retourne `null` si le fichier n'existe pas. `tex.get_size()` sur null → **crash immédiat** dès qu'un garde apparaît.

### Correction
```gdscript
var tex := load("res://art/Futur/gardeGauche.png") as Texture2D
if not tex:
    push_error("Texture garde manquante")
    return
_sprite.texture = tex
var tex_size := tex.get_size()
```

---

## C17 — `texture.get_size()` sur null dans CombatBossFutur (×3)

**Fichier :** `Scripts/CombatBossFutur.gd:1004,1053,1131`
**Sévérité :** 🔴 CRITIQUE

### Le Bug
```gdscript
victory_sprite.texture = load("res://art/Futur/victoire_futur1.png")
var tex_size := victory_sprite.texture.get_size()  # CRASH si texture manquante
```

Même pattern qu'en C16. Si les assets de victoire (`victoire_futur1.png`, `victoire_futur2.png`, `victoire_futur3.png`) sont absents, **le combat du boss final plante** → progression perdue.

### Correction
```gdscript
var tex := load("res://art/Futur/victoire_futur1.png") as Texture2D
if not tex:
    push_error("Texture victoire manquante")
    return
victory_sprite.texture = tex
var tex_size := tex.get_size()
```

---

## H19 — `get_node("collision")` sans `_or_null` dans `stop()`

**Fichier :** `Futur/Futur.gd:1364-1366`
**Sévérité :** 🟠 HAUTE

### Le Bug
```gdscript
var collision_node := time_aunote.get_node("collision") as CollisionShape2D
collision_node.disabled = true   # CRASH si pas de nœud "collision"
```

Toutes les autres occurrences dans `Futur.gd` utilisent `get_node_or_null()` SAUF celle-ci dans `stop()`. Incohérence dangereuse.

### Correction
```gdscript
var collision_node := time_aunote.get_node_or_null("collision") as CollisionShape2D
if collision_node:
    collision_node.disabled = true
```

---

## H20 — `_car_prompt.visible` sur null si joueur va au sous-sol trop vite

**Fichier :** `Futur/Futur.gd:135`
**Sévérité :** 🟠 HAUTE

### Le Bug
```gdscript
func _go_to_basement() -> void:
    _car_prompt.visible = false     # _car_prompt n'existe pas encore !
```

`_car_prompt` est créé dans `_setup_car_prompt()` qui est appelé dans `_play_spawn_animation()`. Si le joueur marche dans la zone escalier AVANT que l'animation de spawn ne crée le prompt → **crash**.

### Correction
```gdscript
if _car_prompt:
    _car_prompt.visible = false
```

---

## H21 — Durée du jeu de voiture : 30s au lieu de 40s

**Fichier :** `Futur/route.gd:19`
**Sévérité :** 🟠 HAUTE

### Le Bug
```gdscript
const GAME_DURATION: float = 30.0    # Code
```

La scène `route.tscn` a `wait_time = 40.0` et le AGENTS.md spécifie 40 secondes. Mais la constante GDScript dit 30. Le jeu est 25% plus court qu'attendu.

### Correction
```gdscript
const GAME_DURATION: float = 40.0    # Match spec
```
