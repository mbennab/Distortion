# 🟡 MOYENNE — Problèmes de sécurité null

---

## M1 — `shape_rect.size` sur null dans vestiaire

**Fichier :** `Present/vestiaire.gd:142-146`
**Sévérité :** 🟡 MOYENNE

### Le Bug
```gdscript
var shape_rect: RectangleShape2D = vetements_shape.shape
var vet_global_pos = vetements_shape.global_position - shape_rect.size / 2.0  # CRASH si shape_rect null
```

`vetements_shape.shape` retourne `Shape2D` (type de base). Si le shape n'est pas un `RectangleShape2D` ou est `null`, le cast implicite échoue silencieusement et `shape_rect` est `null`. `shape_rect.size` crash.

### Correction
```gdscript
var shape_rect: RectangleShape2D = vetements_shape.shape as RectangleShape2D
if not shape_rect:
    return
var vet_global_pos = vetements_shape.global_position - shape_rect.size / 2.0
```

---

## M2 — `body.name == "TimeAunote"` fragile (×5 fichiers)

**Fichiers :** 
- `Present/parking.gd:135,141`
- `Present/pnj_securité.gd:74`
- `Present/pnj_secretaire.gd:75`
- `Present/vestiaire.gd:84`
- `MoyenAge/auberge_moyen_age.gd`, `ville_moyen_age.gd`, etc.

**Sévérité :** 🟡 MOYENNE

### Le Bug
```gdscript
if body.name == "TimeAunote":
```

### Pourquoi c'est fragile
Si le nœud `TimeAunote` est renommé dans la scène, `body.name` ne correspond plus et la condition est fausse **silencieusement**. Le joueur ne déclenche plus les interactions. La comparaison par **identité d'objet** (`body == time_aunote`) est robuste.

### Correction
```gdscript
if body == time_aunote:
```

---

## M17 — DialogueSystem — `npc.first_message` accès property sans `.get()`

**Fichier :** `Scripts/DialogueSystem.gd:190-192`
**Sévérité :** 🟡 MOYENNE

### Le Bug
```gdscript
if npc.has("first_message") and npc.first_message is String and npc.first_message != "":
```

`npc.first_message` utilise la syntaxe property-access (`dict.key`). Inconsistant avec le reste du fichier qui utilise `.get()`. Si la clé existe mais la valeur est d'un type inattendu, `is String` protège, mais mieux vaut utiliser `.get()` pour la cohérence.

### Correction
```gdscript
var first_msg = npc.get("first_message")
if first_msg is String and first_msg != "":
```
