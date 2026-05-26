# 🔵 BASSE — Qualité de code et maintenance

---

## L1 — `_process()` vide qui tourne 60fps

**Fichier :** `Personnage/TimeAunote.gd:23-25`

```gdscript
func _process(_delta):
    pass    # Appelé 60×/seconde pour rien !
```

Supprimer la fonction entière.

---

## L2 — `timerAttente` sans callback connecté

**Fichier :** `Personnage/TimeAunote.gd:9,20-21,89`

```gdscript
var timerAttente
timerAttente = $timerAttente
timerAttente.start()    # Timer qui tourne sans jamais rien faire
```

`timerAttente` est démarré à chaque appel de `animation()` mais **aucun callback n'est connecté** à son signal `timeout`. Le timer tourne et gaspille du CPU pour rien.

### Correction
Soit connecter un callback, soit supprimer le timer.

---

## L3 — `timerSortie` pas stoppé dans `stop()` (HUB)

**Fichier :** `HUB Central/HUB Central.gd:320-335`

```gdscript
func stop():
    process_mode = PROCESS_MODE_DISABLED
    hide()
    # ← timerSortie.stop() manquant !
```

### Correction
```gdscript
func stop():
    process_mode = PROCESS_MODE_DISABLED
    timerSortie.stop()
    hide()
```

---

## L4 — `player_nearby` pas reset dans `stop_idle()`

**Fichiers :** 
- `HUB Central/pnj_hub.gd:131-133`
- `HUB Central/chien_hub.gd:202-206`

```gdscript
func stop_idle() -> void:
    _idle_murmur_timer.stop()
    hide_bubble()
    # ← player_nearby = false manquant !
```

Quand l'ère est stoppée et redémarrée, `player_nearby` reste `true` de la session précédente → les prompts d'interaction ne se réaffichent pas.

### Correction
```gdscript
func stop_idle() -> void:
    _idle_murmur_timer.stop()
    hide_bubble()
    player_nearby = false
```

---

## L6 — Typo "interation" → "interaction"

**Fichier :** `Present/parking.gd:29`, `parking.tscn:55`

```gdscript
var zone = get_node_or_null("zone interation minijeux")
```

"interation" au lieu de "interaction". Cohérent entre les deux fichiers donc ça marche, mais confus pour la maintenance.

### Correction
Renommer en `"zone interaction minijeux"` dans le script ET la scène.

---

## L7 — Root node "Futurrrrr" (typo)

**Fichier :** `Futur/Futur.tscn:82`

```gdscript
[node name="Futurrrrr" type="Node2D"]
```

Typo : 4 'r' au lieu de 2. Pas de conséquence fonctionnelle.

### Correction
```gdscript
[node name="Futur" type="Node2D"]
```

---

## L8 — Global fallback hardcode "La Cheffe"

**Fichier :** `Futur/dimension_futur.json:349-355`

```json
"global_fallbacks": {
    "insult": "La Cheffe ignore tes provocations.",
    "default_template": "La Cheffe te regarde sans comprendre."
}
```

Quand ces fallbacks s'affichent pendant un dialogue avec Vukovi, Koiai, ou le boss, ils disent toujours "La Cheffe" au lieu du vrai PNJ.

### Correction
Utiliser `{npc_name}` dans le template et le substituer dynamiquement.

---

## L9 — `npc_id` = "npc_punk_futur" trompeur

**Fichier :** `Futur/pnj_mecano.gd:3`

```gdscript
const NPC_ID := "npc_punk_futur"
```

Le personnage s'appelle "La mécano" mais l'ID dit "punk". Fonctionnel (le JSON match) mais trompeur.

---

## L10 — Code bulle dialogue dupliqué ×11 scripts

Tous les scripts `pnj_*.gd` contiennent ~55 lignes identiques de création de bulle de dialogue (`Label`, `StyleBoxFlat`, `Timer`, `Tween`). C'est ~600 lignes de code dupliqué.

### Correction
Extraire dans un script commun `BulleDialogue.gd` ou un autoload `BubbleFactory`.

---

## L11 — `randomize()` obsolète Godot 4

**Fichier :** `Scripts/MiniJeuMarchandage.gd:120`

```gdscript
func _ready() -> void:
    randomize()    # Automatique dans Godot 4
```

Godot 4 seed automatiquement le RNG global au démarrage. `randomize()` est redondant.
