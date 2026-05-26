# 🟠 HAUTE / 🟡 MOYENNE — Mini-Jeux : Bugs divers

---

## H13 — MiniJeuCablage : StyleBoxFlat partagé muté

**Fichier :** `Scripts/MiniJeuCablage.gd:616-627`
**Sévérité :** 🟠 HAUTE

### Le Bug
```gdscript
var ps: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
ps.bg_color = ...  # MUTE le style SUR le panel !
```

`get_theme_stylebox("panel")` retourne le même objet StyleBoxFlat qui a été créé dans `_draw_one_node()`. Le modifier modifie **tous les panels** qui utilisent ce style.

### Correction
```gdscript
var ps := (panel.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
ps.bg_color = ...
panel.add_theme_stylebox_override("panel", ps)
```

---

## H14 — MiniJeuTuyau : Tweens concurrents sur rotation

**Fichier :** `Scripts/MiniJeuTuyau.gd:598-615`
**Sévérité :** 🟠 HAUTE

### Le Bug
```gdscript
# Chaque clic crée un NOUVEAU tween sur le même sprite
var tween := create_tween()
tween.tween_property(sprite, "rotation_degrees", target_rot, 0.12)
```

Si le joueur clique plus vite que 0.12s, **plusieurs tweens modifient `rotation_degrees` simultanément** sur le même sprite. Résultat : rotation saccadée, imprévisible. La valeur lue pour `current_rot` est instable (mid-animation).

### Correction
```gdscript
if sprite.has_meta(&"pipe_tween"):
    sprite.get_meta(&"pipe_tween").kill()
var tween := create_tween()
sprite.set_meta(&"pipe_tween", tween)
tween.tween_property(sprite, "rotation_degrees", target_rot, 0.12)
```

---

## H15 — MiniJeuTuyau : Callback rotation corrompt puzzle après reset

**Fichier :** `Scripts/MiniJeuTuyau.gd:613-615`
**Sévérité :** 🟠 HAUTE

### Le Bug
```gdscript
tween.tween_callback(_reset_rotation.bind(row, col))
```

Les valeurs `row, col` sont capturées au moment du clic. Si le joueur reset le puzzle (ESC → `_init_round()` → nouveau grid + nouveau `_pipe_sprites`) pendant que la rotation est en cours (0.12s), le callback s'exécute sur le **NOUVEAU** sprite à la position `[row][col]` et le force à l'**ANCIENNE** valeur de rotation → puzzle corrompu.

### Correction
```gdscript
tween.tween_callback(func():
    if _phase != Phase.PLAYING:
        return
    _reset_rotation(row, col)
)
```

---

## H16 — MiniJeuTourelles : Signal `finished` émis multiple fois

**Fichier :** `Scripts/MiniJeuTourelles.gd:92-97`
**Sévérité :** 🟠 HAUTE

### Le Bug
```gdscript
func _on_game_over() -> void:
    game_active = false
    finished.emit(false)   # Peut être appelé MULTIPLE FOIS dans le même frame
```

Si plusieurs orbes touchent le joueur dans le même frame, `_on_game_over()` est appelée à chaque fois. Le parent reçoit `finished` plusieurs fois → comportement indéfini.

### Correction
```gdscript
var _done := false
func _on_game_over() -> void:
    if _done:
        return
    _done = true
    game_active = false
    finished.emit(false)
```

---

## H17 — OrbeTourelle : Auto-delete compétition avec parent

**Fichier :** `Scripts/OrbeTourelle.gd:5-15`
**Sévérité :** 🟠 HAUTE

### Le Bug
```gdscript
# Chaque orbe a son propre autodestruct
timer.timeout.connect(queue_free)

# Le parent fait aussi le ménage
func stop_game() -> void:
    get_tree().get_nodes_in_group("tourelle_orbs").map(func(n): n.queue_free())
```

### Correction
Supprimer l'autodestruct dans `OrbeTourelle` et laisser le parent gérer.

---

## M8 — MiniJeuCrochetage : Condition tick audio toujours vraie

**Fichier :** `Scripts/MiniJeuCrochetage.gd:299-301`
**Sévérité :** 🟡 MOYENNE

### Le Bug
```gdscript
if angle_diff >= 0.25 or (_indicator_angle + TAU - _last_tick_angle) >= 0.25:
```

Quand `_indicator_angle > _last_tick_angle`, `_indicator_angle + TAU - _last_tick_angle > TAU` qui est toujours > 0.25. La deuxième condition est **toujours vraie** → le tick audio devient temporel, pas basé sur le mouvement.

### Correction
```gdscript
var angle_diff := absf(wrapf(_indicator_angle - _last_tick_angle, -PI, PI))
if angle_diff >= 0.25:
    # tick
```

---

## M9 — MiniJeuDisjoncteur : Null access sur `_switch_nodes[i]`

**Fichier :** `Scripts/MiniJeuDisjoncteur.gd:264-285`
**Sévérité :** 🟡 MOYENNE

### Le Bug
```gdscript
var bg: ColorRect = _switch_nodes[index]   # Peut être null
bg.color = Color(...)                       # CRASH
```

Si `_switch_nodes` n'est pas correctement initialisé (appel avant `_build_ui()`), l'accès à l'élément `index` retourne `null`. `null.color` crash.

### Correction
```gdscript
var bg := _switch_nodes[index] as ColorRect
if not bg:
    return
bg.color = Color(...)
```

---

## M10 — MiniJeuEcouteTables : Pas de gestion ESC

**Fichier :** `Scripts/MiniJeuEcouteTables.gd:389-393`
**Sévérité :** 🟡 MOYENNE

Tous les autres mini-jeux gèrent `ui_cancel` (ESC) pour quitter. Celui-ci ne le fait pas → le joueur est **piégé** jusqu'à la victoire ou la défaite.

### Correction
```gdscript
if event.is_action_pressed("ui_cancel"):
    get_viewport().set_input_as_handled()
    _finish_game(false)
    return
```

---

## M12 — MiniJeuMarchandage : Emoji non rendus dans Label

**Fichier :** `Scripts/MiniJeuMarchandage.gd:328`
**Sévérité :** 🟡 MOYENNE

### Le Bug
```gdscript
_obj_lbl.text = "🎯 %s  ·  ⚠ %s" % [catches_txt, decoys_txt]
```

La police par défaut de Godot (`ThemeDB.fallback_font`) n'inclut **pas** les emoji. `🎯` et `⚠` s'affichent comme des carrés vides.

### Correction
```gdscript
_obj_lbl.text = "[*] %s  ·  [!] %s" % [catches_txt, decoys_txt]
```

---

## M13 — MiniJeuSoleil : Handler resize incomplet

**Fichier :** `Scripts/MiniJeuSoleil.gd:142-145`
**Sévérité :** 🟡 MOYENNE

### Le Bug
```gdscript
func _on_viewport_resized() -> void:
    _bg.size = vp
    _hint.position = ...     # Seulement bg et hint mis à jour
    # NPC sprite Y, player sprite Y, _start_x, _status, _strikes_lbl,
    # _progress_lbl, _title → PAS MIS À JOUR
```

Un redimensionnement de fenêtre pendant le jeu brise tout le positionnement visuel.

### Correction
```gdscript
func _on_viewport_resized() -> void:
    _build_ui()   # Reconstruire toute l'interface
```
