# 🔴 CRITIQUE — Logique de direction inversée (TimeAunote)

**Fichier :** `Personnage/TimeAunote.gd:74-81`
**Sévérité :** CRITIQUE (le joueur regarde dans la direction opposée à son déplacement)

## Le Bug

```gdscript
# Lignes 74-81 — direction inversée !
if mouvement.x != 0:
    timeAunoteAnimation.animation = _anim_name("marche_cote")
    if mouvement.x > 0:           # Le joueur va à DROITE
        timeAunoteAnimation.flip_h = true   # ← flip_h = true → SPRITE FACE À GAUCHE (FAUX !)
        direction = "gauche"                # ← "gauche" alors qu'il va à droite (FAUX !)
    else:                          # Le joueur va à GAUCHE
        timeAunoteAnimation.flip_h = false  # ← flip_h = false → SPRITE FACE À DROITE (FAUX !)
        direction = "droite"                # ← "droite" alors qu'il va à gauche (FAUX !)
```

## Pourquoi c'est inversé

En Godot, `AnimatedSprite2D.flip_h = true` **inverse horizontalement** le sprite. Quand le sprite est conçu pour regarder à droite par défaut :
- `flip_h = false` → le sprite regarde à **droite** ✅
- `flip_h = true` → le sprite regarde à **gauche** (miroir) ✅

Le code actuel fait l'inverse :
- `mouvement.x > 0` (droite) → `flip_h = true` → sprite face à **gauche** ❌
- `mouvement.x < 0` (gauche) → `flip_h = false` → sprite face à **droite** ❌

## Impact

**Sur TOUT le jeu** : Le personnage principal marche à droite mais regarde à gauche, et vice-versa.
- Toutes les époques (HUB, MoyenAge, Present, Futur)
- Tous les déplacements du joueur
- Expérience utilisateur immédiatement cassée

## Correction

```gdscript
if mouvement.x != 0:
    timeAunoteAnimation.animation = _anim_name("marche_cote")
    if mouvement.x > 0:
        timeAunoteAnimation.flip_h = false   # Droite → pas de flip
        direction = "droite"
    else:
        timeAunoteAnimation.flip_h = true    # Gauche → flip miroir
        direction = "gauche"
```
