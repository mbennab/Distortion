# 🔴 CRITIQUE / 🟠 HAUTE — MoyenÂge : Bugs bloquants

**Sévérité :** 3 CRITIQUES, 4 HAUTE

---

## C9 — Conflit victoire/défaite dans le même frame

**Fichier :** `MoyenAge/campement.gd:175,196,276,288`
**Sévérité :** 🔴 CRITIQUE

### Le Bug
```gdscript
# _process(delta) dans campement.gd :
_perform_attack()               # Peut appeler _victory()
_handle_assassin_logic(delta)   # Peut appeler _defeat()
```

Si le joueur et l'assassin meurent dans le **même frame** :
1. `_victory()` construit une cinématique (crée des nœuds, tweens, etc.)
2. `_defeat()` crée un label "sauvé par la distorsion", await 3s, puis `start_combat()`
3. `start_combat()` **réinitialise tout** → mais la cinématique de victoire tourne encore
4. La cinématique tente d'accéder à des nœuds qui ont été libérés → **crash mémoire**

### Correction
```gdscript
func _damage_player() -> void:
    if not is_combat_active:
        return  # Combat déjà terminé ce frame
    player_hp -= 1
    ...
```

---

## C10 — `get_parent()` null sans vérification

**Fichier :** `MoyenAge/prison_moyen_age.gd:85-87,107-109`
**Sévérité :** 🔴 CRITIQUE

### Le Bug
```gdscript
var parent = get_parent()
if parent.has_method("_on_minigame_started"):   # CRASH si parent == null
    parent._on_minigame_started()
```

`get_parent()` retourne `null` si le nœud n'est pas dans l'arbre scénique. `null.has_method()` lève une erreur runtime.

### Correction
```gdscript
var parent = get_parent()
if parent and parent.has_method("_on_minigame_started"):
    parent._on_minigame_started()
```

---

## C11 — Timer/tween zombie après `stop()` → fuite mémoire

**Fichier :** `MoyenAge/magasin_moyen_age.gd:175-239`
**Sévérité :** 🔴 CRITIQUE

### Le Bug
```gdscript
func _show_disguise_message() -> void:
    var timer := get_tree().create_timer(4.5)   # SceneTreeTimer — survit au nœud
    timer.timeout.connect(func():
        if not is_instance_valid(label):
            return
        var fade_out := create_tween()         # Tween sur nœud PROCESS_MODE_DISABLED
        ...
    )

func stop() -> void:
    if _disguise_label:
        _disguise_label.queue_free()
        _disguise_label = null
```

`queue_free()` est différé. `is_instance_valid(label)` peut retourner `true` APRÈS `queue_free()` car la désallocation réelle a lieu au prochain frame. `create_tween()` sur un nœud en `PROCESS_MODE_DISABLED` crée un tween zombie.

### Correction
```gdscript
var _disguise_timer_active := false

func _show_disguise_message() -> void:
    _disguise_timer_active = true
    var timer := get_tree().create_timer(4.5)
    timer.timeout.connect(func():
        if not _disguise_timer_active:
            return
        ...
    )

func stop() -> void:
    _disguise_timer_active = false
    ...
```

---

## H5 — `is_key_pressed(KEY_E)` spam attaque continu

**Fichier :** `MoyenAge/campement.gd:170`
**Sévérité :** 🟠 HAUTE

### Le Bug
```gdscript
if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_E):
    if attack_cooldown <= 0.0:
        _perform_attack()
```

`Input.is_key_pressed()` est `true` à **CHAQUE frame** tant que la touche est maintenue. Avec un cooldown de 0.3s, maintenir E appuyé crée une **attaque automatique tous les 0.3s**. `is_action_just_pressed("ui_accept")` est aussi lié à E → double déclenchement.

### Correction
```gdscript
if Input.is_action_just_pressed("ui_accept"):
    if attack_cooldown <= 0.0:
        _perform_attack()
```

---

## H6 — `get_node("collision")` sans `_or_null` (×10 occurrences)

**Fichier :** `MoyenAge/MoyenAge.gd:299,319,339,359,379,417,439,483,499,1116`
**Sévérité :** 🟠 HAUTE

### Le Bug
```gdscript
var collision_node := time_aunote.get_node("collision") as CollisionShape2D
collision_node.disabled = true   # CRASH si collision_node == null
```

`get_node()` **lève une erreur** si le chemin n'existe pas. Le `as CollisionShape2D` ne protège pas contre l'échec de `get_node()`.

### Correction
```gdscript
var collision_node := time_aunote.get_node_or_null("collision") as CollisionShape2D
if collision_node:
    collision_node.disabled = true
```

---

## H7 — `get_parent().get_node("TimeAunote")` crash si null

**Fichier :** `MoyenAge/magasin_moyen_age.gd:149`
**Sévérité :** 🟠 HAUTE

### Le Bug
```gdscript
var player = get_parent().get_node("TimeAunote")
```

### Correction
```gdscript
var parent_node = get_parent()
var player = parent_node.get_node_or_null("TimeAunote") if parent_node else null
if player and player.has_method("apply_disguise"):
    player.apply_disguise()
```

---

## H8 — Accès à `_mg_instance._won` privé

**Fichier :** `MoyenAge/parc_moyen_age.gd:67`
**Sévérité :** 🟠 HAUTE

### Le Bug
```gdscript
if _mg_instance and is_instance_valid(_mg_instance) and _mg_instance._won:
```

Accès à une variable préfixée `_` (privée par convention) d'une autre classe. Si la variable est renommée dans `MiniJeuAmitie`, ce code casse silencieusement.

### Correction
Ajouter un signal `finished(success: bool)` dans `MiniJeuAmitie` ou un getter public.
