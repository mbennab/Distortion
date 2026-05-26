# 🟠 HAUTE — CombatBossFutur : Bugs de combat

---

## H9 — StyleBoxFlat partagé → barres de vie toutes de la même couleur

**Fichier :** `Scripts/CombatBossFutur.gd:37-38,149-154,191,233,274,464-471`
**Sévérité :** 🟠 HAUTE

### Le Bug
```gdscript
var hp_fill_style: StyleBoxFlat    # Instance UNIQUE partagée entre TOUTES les barres

# Toutes les barres utilisent LE MÊME style
boss_hp_fill.add_theme_stylebox_override("panel", hp_fill_style)
intankables_hp_fill.add_theme_stylebox_override("panel", hp_fill_style)
player_hp_fill.add_theme_stylebox_override("panel", hp_fill_style)
```

### Pourquoi c'est un problème
`_set_hp_fill()` est appelée une fois par barre de vie par frame. Le dernier appel gagne : la couleur du style partagé reflète **toujours la dernière barre mise à jour** (intankables). Les trois barres affichent la **même couleur** en permanence :

- Le boss à 10% PV (devrait être rouge) → couleur d'intankables
- Le joueur à 90% PV (devrait être vert) → couleur d'intankables

Le feedback visuel des PV est **totalement trompeur**.

### Correction
```gdscript
# Dupliquer le style pour chaque barre
boss_hp_fill.add_theme_stylebox_override("panel", hp_fill_style.duplicate())
intankables_hp_fill.add_theme_stylebox_override("panel", hp_fill_style.duplicate())
```

Puis dans `_set_hp_fill()`, récupérer et modifier le style spécifique de la barre :
```gdscript
var style := fill.get_theme_stylebox("panel") as StyleBoxFlat
if style:
    style.bg_color = c
```

---

## H10 — Shift/Ctrl déclenchent échec QTE

**Fichier :** `Scripts/CombatBossFutur.gd:888-894`
**Sévérité :** 🟠 HAUTE

### Le Bug
```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if not qte_active:
        return
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == qte_keys[qte_current_index]:
            _advance_qte()
        else:
            _complete_qte(false)     # Shift → ÉCHEC !
```

### Pourquoi c'est un problème
`InputEventKey` inclut **toutes** les touches, y compris Shift, Ctrl, Alt, Meta. Si le joueur appuie sur Shift ou Ctrl en jouant le QTE (par exemple pour courir ou utiliser un modificateur), `_complete_qte(false)` est appelé immédiatement. Le QTE devient **impossible à réussir**.

### Correction
```gdscript
if event.is_action_pressed("ui_accept"):
    if qte_keys[qte_current_index] == KEY_E or ... :
        _advance_qte()
    else:
        _complete_qte(false)
```

Ou :
```gdscript
if event.keycode in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
    return
```

---

## M15 — PV boss P2 : 250 au lieu de 150 (spéc)

**Fichier :** `Scripts/CombatBossFutur.gd:685`
**Sévérité :** 🟡 MOYENNE

### Le Bug
```gdscript
boss_max_hp = 250    # Spec AGENTS.md dit 150
```

Déséquilibre du combat final par rapport au design documenté.

### Correction
```gdscript
boss_max_hp = 150    # Match spec
```
