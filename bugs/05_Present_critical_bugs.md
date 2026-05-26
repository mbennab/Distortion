# 🔴 CRITIQUE / 🟠 HAUTE — Present Era : Bugs bloquants

**Sévérité :** 3 CRITIQUES, 5 HAUTE

---

## C6 — `modulate.a = X` ne fonctionne pas en Godot 4

**Fichier :** `Present.gd:120,1490,1520,1563,1593,1622,1659,1699,1718`
**Sévérité :** 🔴 CRITIQUE

### Le Bug
```gdscript
fade_rect.modulate.a = 0.0        # NE MARCHE PAS
time_aunote.modulate.a = 1.0       # NE MARCHE PAS
_darkness_rect.color.a = 0.0       # NE MARCHE PAS (ColorRect)
```

### Pourquoi c'est cassé
En Godot 4 GDScript, `obj.property.submember = value` **ne passe pas par le setter** de la propriété. L'opérateur `.` retourne une **copie** de la struct Color, modifie la copie, puis jette la copie — la valeur originale reste inchangée.

**tween_property(obj, "modulate:a", ...)** fonctionne car le tween utilise le chemin de propriété en chaîne, pas l'accès `obj.modulate.a`.

### Impact
- Les transitions de fondu (entrée/sortie) sont cassées
- Le voile d'obscurité ne se comporte pas correctement
- Tous les effets visuels utilisant `modulate.a` sont brisés dans Present

### Correction
```gdscript
fade_rect.modulate = Color(fade_rect.modulate.r, fade_rect.modulate.g, fade_rect.modulate.b, 0.0)
# Ou directement :
fade_rect.modulate = Color(0, 0, 0, 0)
time_aunote.modulate = Color(1, 1, 1, 1)
_darkness_rect.color = Color(0, 0, 0, 0)
```

---

## C7 — Tween de pulsation jamais tué → conflit avec fade-out

**Fichier :** `Present.gd:152-167`
**Sévérité :** 🔴 CRITIQUE

### Le Bug
```gdscript
func _start_darkness_pulse() -> void:
    var tween := create_tween()
    tween.set_loops()  # Boucle INFINIE
    tween.tween_property(_darkness_rect, "color", ...)

func _remove_darkness_overlay() -> void:
    var tween := create_tween()  # NOUVEAU tween
    tween.tween_property(_darkness_rect, "color", Color(0, 0, 0, 0), 2.0)
    # ← Le tween de pulsation est toujours ACTIF !
```

### Pourquoi c'est un problème
Deux tweens modifient `_darkness_rect.color` simultanément :
- Le tween de pulsation (boucle infinie) le fait osciller entre rouge et sombre
- Le tween de fade-out tente de le mettre à transparent

Résultat : **le voile d'obscurité scintille/glitch** au lieu de disparaître proprement.

### Correction
```gdscript
var _darkness_pulse_tween: Tween

func _remove_darkness_overlay() -> void:
    if _darkness_pulse_tween and _darkness_pulse_tween.is_valid():
        _darkness_pulse_tween.kill()
    var tween := create_tween()
    tween.tween_property(_darkness_rect, "color", Color(0, 0, 0, 0), 2.0)
```

---

## C8 — `_salle_machine_done = true` même en cas d'échec → softlock

**Fichier :** `Present.gd:1820-1832`
**Sévérité :** 🔴 CRITIQUE

### Le Bug
```gdscript
func _on_salle_machine_minigame_done(success: bool) -> void:
    _salle_machine_minigame = null
    _salle_machine_done = true       # ← TOUJOURS true, même si success == false !
    if success:
        DialogueSystem.complete_step(...)
```

### Pourquoi c'est un softlock
Si le mini-jeu de la salle machine échoue (`success = false`) :
1. `_salle_machine_done = true` → la zone est marquée comme "faite"
2. `DialogueSystem.complete_step()` n'est **pas appelé** → la quête n'avance pas
3. Le voile d'obscurité ne s'affiche **pas**
4. Le joueur ne peut **plus jamais** retenter le mini-jeu (le prompt est bloqué)

**Progression bloquée définitivement.**

### Correction
```gdscript
func _on_salle_machine_minigame_done(success: bool) -> void:
    _salle_machine_minigame = null
    if not success:
        can_move = true
        return                    # ← Rejoue le jeu
    _salle_machine_done = true
    ...
```

---

## H1 — `_darkness_active` jamais reset

**Fichier :** `Present.gd:1413,1942`
**Sévérité :** 🟠 HAUTE

### Le Bug
```gdscript
func start(spawn_id: String = "entree") -> void:
    # Rien sur _darkness_active

func stop() -> void:
    _darkness_layer.hide()      # Cache le voile
    # _darkness_active = ???    # PAS RESET !
```

Si l'ère est arrêtée pendant que le voile d'obscurité est actif, `_darkness_active` reste `true`. Au prochain `start()`, `_show_darkness_overlay()` vérifie `if _darkness_active: return` → le voile ne s'affiche **jamais**.

### Correction
```gdscript
func start(spawn_id: String) -> void:
    _darkness_active = false
    if _darkness_layer:
        _darkness_layer.hide()
```

---

## H2 — `started` pas reset → joueur bloqué au restart

**Fichier :** `Present.gd:1413`
**Sévérité :** 🟠 HAUTE

### Le Bug
```gdscript
func start(...) -> void:
    process_mode = PROCESS_MODE_INHERIT
    _hall_transition_started = false
    # started = false    ← MANQUANT !
```

`started` est seulement mis à `true` dans `_play_spawn_animation()`. Si `stop()` est appelé PENDANT l'animation de spawn (avant `started = true`), `started` reste `false` **définitivement**. Les gardes `if not started: return` dans `_input()` et `_process()` bloquent toute interaction.

### Correction
```gdscript
func start(...) -> void:
    started = false
    process_mode = PROCESS_MODE_INHERIT
```

---

## H3 — `await tween.finished` crée des coroutines zombies

**Fichier :** `Present.gd:255,285,578,599,624,650,667,690,706,727,744,759,773,789,810,826,841,857,872,888,906,922,1032,1050,1062,1081,1102,1132,1789`
**Sévérité :** 🟠 HAUTE

### Le Bug
```gdscript
var tween_fade := create_tween()
tween_fade.tween_property(fade_rect, "modulate:a", 1.0, 0.8)
await tween_fade.finished
```

Quand `stop()` est appelé : `process_mode = PROCESS_MODE_DISABLED` → **tous les tweens liés à ce nœud sont en pause**. Le `finished` n'est **jamais** émis. L'`await` ne se résout **jamais**. C'est une fuite de coroutine.

Si `start()` est rappelé, l'ancienne coroutine (maintenant résumée) compétitionne avec la nouvelle → **double tween sur les mêmes propriétés**.

### Correction
```gdscript
await get_tree().create_timer(1.0).timeout  # Timeout de sécurité
if not is_inside_tree(): return
```

Ou dans `stop()` :
```gdscript
func stop() -> void:
    get_tree().create_tween().kill()  # Pas possible → il faut tuer chaque tween individuellement
```

---

## H4 — `pnj_securité.gd` : Manque `z_index = 10` et `play()`

**Fichier :** `Present/pnj_securité.gd:83-86`
**Sévérité :** 🟠 HAUTE

### Le Bug
```gdscript
func apparition(position: Vector2) -> void:
    animation_securite.animation = "default"
    self.position = position
    show()
    # ← z_index = 10 manquant !
    # ← animation_securite.play() manquant !
```

Comparé à `pnj_pc_controle.gd:86-88` :
```gdscript
func apparition(pos: Vector2) -> void:
    self.position = pos
    z_index = 10              # ✅ PRESENT
    animated_sprite.play()    # ✅ PRESENT
    show()
```

### Impact
- L'agent de sécurité s'affiche derrière les décors (`z_index = 0` par défaut)
- L'animationsprite ne redémarre pas après `show()` si l'état était arrêté

### Correction
```gdscript
func apparition(position: Vector2) -> void:
    animation_securite.animation = "default"
    animation_securite.play()
    self.position = position
    z_index = 10
    show()
```
