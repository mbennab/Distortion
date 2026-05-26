# 🟠 HAUTE — Problèmes d'architecture et d'encapsulation

---

## H11 — Appel à méthode privée `DialogueSystem._find_quest()`

**Fichier :** `Scripts/WarpSystem.gd:569,690`
**Sévérité :** 🟠 HAUTE

### Le Bug
```gdscript
# WarpSystem.gd — Accès à une méthode PRIVÉE d'un Autoload externe
var quest = DialogueSystem._find_quest(quest_id)
```

### Pourquoi c'est un problème
`_find_quest()` est préfixé par `_` (convention privée en GDScript). WarpSystem accède directement à l'implémentation interne de `DialogueSystem`. Si le nom ou la signature de `_find_quest()` change (refactoring, bugfix), WarpSystem **crasse silencieusement**.

C'est une **violation d'encapsulation** qui crée un couplage fort entre les deux systèmes.

### Correction
Ajouter une méthode publique dans `DialogueSystem.gd` :
```gdscript
func find_quest(quest_id: String) -> Dictionary:
    return _find_quest(quest_id)
```

Puis utiliser dans WarpSystem :
```gdscript
var quest = DialogueSystem.find_quest(quest_id)
```

---

## H12 — `var normal_panel` shadowe la variable membre

**Fichier :** `Scripts/DialogueUI.gd:400`
**Sévérité :** 🟠 HAUTE

### Le Bug
```gdscript
# Ligne 19 — Membre
var normal_panel: Panel

# Ligne 400 — SHADOWE le membre !
var normal_panel = root_control.get_node_or_null("DialoguePanel")
```

### Pourquoi c'est un problème
Le mot-clé `var` crée une **variable locale** qui shadowe totalement le membre de classe `normal_panel`. Le membre déclaré ligne 19 garde sa valeur initiale (`null`) et n'est jamais mis à jour. Toutes les opérations sur `normal_panel` ailleurs dans la classe utilisent le membre, qui reste `null`.

### Correction
```gdscript
# Ligne 400 — Enlever 'var' pour utiliser la variable membre
normal_panel = root_control.get_node_or_null("DialoguePanel")
```

---

## H18 — `duplicate()` retourne Variant, pas StyleBoxFlat

**Fichier :** `Menu/MainMenu.gd:140`
**Sévérité :** 🟠 HAUTE

### Le Bug
```gdscript
var h: StyleBoxFlat = n.duplicate()    # duplicate() retourne Variant !
```

### Pourquoi c'est un problème
`Resource.duplicate()` retourne `Variant`, pas le type spécifique. En Godot 4 avec typage strict (`:=` ou annotation `: Type`), l'assignation effectue une vérification de type au runtime. Si `duplicate()` retourne un type inattendu, ça plante.

Comme documenté dans AGENTS.md : *"StyleBoxFlat.duplicate() retourne Variant. Utilisez un type explicite."*

### Correction
```gdscript
var h: StyleBoxFlat = n.duplicate() as StyleBoxFlat
```
