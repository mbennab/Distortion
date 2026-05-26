# 🔴 CRITIQUE — HUB Central : Script cassé + Sprite chien décalé

**Sévérité :** CRITIQUE (crash + corruption visuelle)

---

## Bug 1 : Référence script inexistante

**Fichier :** `HUB Central/TimeAunote.tscn:3`

```gdscript
[ext_resource type="Script" path="res://HUB Central/TimeAunote.gd" id="1_gd"]
```

### Pourquoi c'est cassé
Le fichier `res://HUB Central/TimeAunote.gd` **n'existe pas**. Le vrai script du joueur est à `res://Personnage/TimeAunote.gd`.

Cette scène `HUB Central/TimeAunote.tscn` est probablement une copie orpheline de `Personnage/TimeAunote.tscn`. Si quoi que ce soit la référence, l'éditeur Godot affiche une erreur de ressource manquante.

### Correction
```gdscript
[ext_resource type="Script" path="res://Personnage/TimeAunote.gd" id="1_gd"]
```
Ou supprimer la scène si elle n'est utilisée nulle part.

---

## Bug 2 : Sprite chien — largeur de frame 471px au lieu de 468px

**Fichier :** `HUB Central/TimeAunoteDansHubCentral.tscn:11-17`
**Aussi :** `HUB Central/chien_hub.tscn:5-11` (correct : 468px)

```gdscript
# TimeAunoteDansHubCentral.tscn — FAUX (471px)
region = Rect2(0, 0, 471, 641)
region = Rect2(471, 0, 471, 641)

# chien_hub.tscn — CORRECT (468px)
region = Rect2(0, 0, 468, 641)
region = Rect2(468, 0, 468, 641)
```

### Pourquoi c'est un problème
La texture `res://art/chien-hub.png` fait 936×641px (2 frames de 468px chacune). Avec 471px :
- Première frame : prend 3px de la deuxième frame (bordure)
- Deuxième frame : commence 3px trop tard

**Le sprite du chien est décalé/corrompu visuellement** dans la scène HUB principale.

### Correction
Remplacer tous les `471` par `468` dans `TimeAunoteDansHubCentral.tscn`.

---

## Bug 3 : MiniJeuChien hardcode 468px

**Fichier :** `HUB Central/MiniJeuChien.gd:774-781`

```gdscript
var dest_w := 468.0 * 0.08
var dest_h := 641.0 * 0.08
var src_rect := Rect2(frame_index * 468.0, 0.0, 468.0, 641.0)
```

### Pourquoi c'est un problème
Les dimensions de la texture sont **hardcodées** en 468px. Combiné au Bug 2 qui utilise 471px dans la scène, le mini-jeu utilise une largeur différente de la scène HUB.

### Correction
Utiliser les dimensions dynamiques de la texture :
```gdscript
var frame_w := dog_sprite_tex.get_width() / 2.0
var frame_h := dog_sprite_tex.get_height()
var dest_w := frame_w * 0.08
var dest_h := frame_h * 0.08
var src_rect := Rect2(frame_index * frame_w, 0.0, frame_w, frame_h)
```

---

## Bug 4 : Ball physics dans `_process` au lieu de `_physics_process`

**Fichier :** `HUB Central/MiniJeuChien.gd:667`

```gdscript
# Dans _process_pong(delta) appelé depuis _process(delta)
ball_pos += ball_vel * ball_speed_multiplier * delta
```

### Pourquoi c'est un problème
`_process` utilise un delta **variable** (temps entre frames rendues). Sur un écran 144Hz le delta est ~6.9ms, sur 60Hz ~16.7ms. La physique de la balle change selon le moniteur → **gameplay inconsistant**.

### Correction
Déplacer le pong dans `_physics_process(delta)`.

---

## Résumé des corrections HUB

1. Corriger la référence script dans `TimeAunote.tscn`
2. Remplacer 471px → 468px dans `TimeAunoteDansHubCentral.tscn`
3. Remplacer hardcodé 468px par `get_width()/2` dans `MiniJeuChien.gd`
4. Déplacer pong `_process` → `_physics_process`
