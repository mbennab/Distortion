# 🟡 MOYENNE — MoyenÂge : Bugs non-critiques

---

## M4 — Accès à `DialogueSystem._find_quest()` privé

**Fichier :** `MoyenAge/MoyenAge.gd:573,579`
**Sévérité :** 🟡 MOYENNE

### Le Bug
```gdscript
var quest = DialogueSystem._find_quest(quest_id)
```

Même problème que [H11 dans WarpSystem](09_Architecture_high.md). `_find_quest()` est une méthode privée par convention.

### Correction
Utiliser `DialogueSystem.find_quest(quest_id)` (après avoir ajouté la méthode publique).

---

## M5 — Signaux connectés sans déconnexion dans `stop()`

**Fichier :** `MoyenAge/MoyenAge.gd:409-410,744-745`
**Sévérité :** 🟡 MOYENNE

### Le Bug
```gdscript
if not sortie_foret.body_entered.is_connected(_on_foret_sortie_entered):
    sortie_foret.body_entered.connect(_on_foret_sortie_entered)
# JAMAIS déconnecté dans stop()
```

Bien que Godot nettoie les connexions lors de la libération, c'est asymétrique et peut causer des doubles connexions si `start()` est appelé plusieurs fois.

### Correction
```gdscript
func stop() -> void:
    if sortie_foret.body_entered.is_connected(_on_foret_sortie_entered):
        sortie_foret.body_entered.disconnect(_on_foret_sortie_entered)
```

---

## M6 — `move_and_collide` au lieu de `move_and_slide`

**Fichier :** `MoyenAge/MoyenAge.gd:228`
**Sévérité :** 🟡 MOYENNE

### Le Bug
```gdscript
time_aunote.move_and_collide(direction * speed * delta)
```

`move_and_collide()` ne gère pas le glissement le long des murs (pentes, coins). `CharacterBody2D` est conçu pour `move_and_slide()`. Le joueur peut rester bloqué sur des coins de collision.

### Correction
```gdscript
time_aunote.velocity = direction * speed
time_aunote.move_and_slide()
```

---

## M7 — `DirAccess.open("res://")` ne marche pas en export

**Fichier :** `MoyenAge/MoyenAge.gd:148-161`
**Sévérité :** 🟡 MOYENNE

### Le Bug
```gdscript
var dir := DirAccess.open("res://audio/moyen_age/" + target_zone + "/")
```

Dans un projet exporté (PCK), `DirAccess.open("res://")` ne liste pas les fichiers d'un dossier. Les ressources sont packagées dans le PCK.

### Correction
```gdscript
func _load_zone_audio(zone: String) -> void:
    var audio_files := _get_predefined_audio_list(zone)  # Liste hardcodée des chemins
    for path in audio_files:
        var stream := load(path) as AudioStream
        if stream:
            streams.append(stream)
```
