# 🔴 CRITIQUE — `start()` appelée sans argument `spawn_id` requis

**Fichier :** `Main.gd:11,23,26,29`
**Sévérité :** CRITIQUE (erreur "Too few arguments" au lancement)

## Le Bug

```gdscript
# Ligne 11 — HUB
sceneHUB = $TimeAunoteDansHUBCentral
sceneHUB.start()     ← attend spawn_id: String

# Lignes 22-30 — Changement d'ère depuis le HUB
"MoyenAge":
    sceneMoyenAge.start()    ← attend spawn_id: String
    current_zone = "moyenage"
"Present":
    scenePresent.start()     ← attend spawn_id: String
    current_zone = "present"
"Futur":
    sceneFutur.start()       ← attend spawn_id: String
    current_zone = "futur"
```

## Pourquoi c'est un crash

Toutes les époques implémentent `start(spawn_id: String)` **sans valeur par défaut** :
```gdscript
func start(spawn_id: String) -> void:   # Pas de = "entree"
```

Godot 4 lève une erreur `"Too few arguments"` quand un paramètre requis est manquant. C'est une erreur **runtime** qui stoppe l'exécution.

Par contraste, `warp_to_era()` à la ligne 44 appelle correctement :
```gdscript
func warp_to_era(zone: String, spawn_id: String) -> void:
    match current_zone:
        ...
    match zone:
        "hub":
            sceneHUB.start(spawn_id)  ← Correct !
```

## Impact

- **Le jeu ne démarre pas** à cause de la ligne 11 (HUB)
- Les transitions vers MoyenAge/Present/Futur depuis le HUB crashent
- **Progression bloquée à 100%**

## Correction

```gdscript
sceneHUB.start("entree")     # Ligne 11
sceneMoyenAge.start("entree")  # Ligne 23
scenePresent.start("entree")   # Ligne 26
sceneFutur.start("entree")     # Ligne 29
```

## Alternative (préventive)

Donner une valeur par défaut dans chaque script d'époque :
```gdscript
func start(spawn_id: String = "entree") -> void:
```
