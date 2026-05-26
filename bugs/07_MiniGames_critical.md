# 🔴 CRITIQUE — Mini-Jeux : Bugs bloquants

**Sévérité :** 4 CRITIQUES

---

## C12 — MiniJeuTourelles : Pas de `.tscn` → tourelles à (0,0)

**Fichier :** `Scripts/MiniJeuTourelles.gd` (pas de `.tscn`)
**Sévérité :** 🔴 CRITIQUE

### Le Bug
```gdscript
# MiniJeuTourelles.gd — @export variables
@export var tourelle1_position: Vector2    # Jamais configuré = Vector2(0,0)
@export var tourelle2_position: Vector2    # Jamais configuré = Vector2(0,0)
```

### Pourquoi c'est un problème
`@export` ne peut être configuré que dans l'**inspecteur** d'une scène `.tscn`. Comme **il n'existe pas de fichier `MiniJeuTourelles.tscn`**, les deux positions de tourelles restent à `Vector2(0, 0)`.

Tous les orbes énergétiques apparaissent à l'origine du monde (0,0) et volent dans des directions arbitraires. Le mini-jeu est **complètement injouable** — les orbes viennent du mauvais endroit et le joueur ne peut pas les esquiver.

### Impact
Le mini-jeu des tourelles dans le Futur (supérette) ne fonctionne pas du tout. Progression bloquée.

### Correction
```gdscript
func _ready() -> void:
    if tourelle1_position == Vector2.ZERO:
        tourelle1_position = Vector2(100, get_viewport_rect().size.y * 0.25)
    if tourelle2_position == Vector2.ZERO:
        tourelle2_position = Vector2(get_viewport_rect().size.x - 100, get_viewport_rect().size.y * 0.75)
```

Ou créer le fichier `.tscn` manquant.

---

## C13 — GardeEtage : Collision rectangle ≠ cône visuel

**Fichier :** `Scripts/GardeEtage.gd:82-120`
**Sévérité :** 🔴 CRITIQUE

### Le Bug
```gdscript
# Visuel : cône triangulaire (65° spread, 550px radius)
_arc.polygon = [...]    # Triangle

# Collision : RECTANGLE GÉANT
rect = RectangleShape2D.new()
rect.size = Vector2(550, 400)  # ou (400, 550)
_detect_shape.shape = rect
```

### Pourquoi c'est cassé
Le **cône visuel** (arc triangulaire de 65°) et le **shape de collision** (rectangle de 550×400) sont **géométriquement complètement différents** :

- Le rectangle couvre une zone **beaucoup plus grande** que le cône visuel
- Le joueur est détecté quand il est visiblement **en dehors** du cône
- Le feedback visuel du cône ne correspond pas à la détection réelle

Le méchanisme d'infiltration est **totalement cassé** — le joueur se fait attraper alors qu'il pense être hors de danger.

### Correction
```gdscript
# Utiliser ConvexPolygonShape2D qui correspond au cône visuel
var shape := ConvexPolygonShape2D.new()
shape.set_point_cloud(pts)  # Mêmes points que l'arc visuel
_detect_shape.shape = shape
```

---

## C14 — MiniJeuAmitie : `_on_tree_exiting()` n'est pas un callback Godot

**Fichier :** `Scripts/MiniJeuAmitie.gd:741`
**Sévérité :** 🔴 CRITIQUE

### Le Bug
```gdscript
func _on_tree_exiting() -> void:   # ← N'EXISTE PAS dans Godot !
    stop()
```

### Pourquoi c'est un problème
`_on_tree_exiting()` **n'est pas une méthode virtuelle Godot**. Le callback correct pour la sortie de l'arbre scénique est `_exit_tree()`.

Cette fonction n'est **jamais appelée**. Conséquences :
- `stop()` ne s'exécute jamais
- Les signaux connectés à `DialogueSystem` ne sont pas déconnectés
- `_typewriter_timer` (l.379) ne s'arrête jamais
- Les connexions de dialogue peuvent **fuiter** et causer des doubles appels

### Correction
```gdscript
func _exit_tree() -> void:   # ✅ Callback Godot correct
    stop()
```
