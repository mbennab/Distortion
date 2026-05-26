# 🟠 HAUTE / 🟡 MOYENNE — Present : Bugs de progression

---

## H22 — `_go_to_hall()` cache pas toutes les sous-zones

**Fichier :** `Present.gd:1108-1118`
**Sévérité :** 🟠 HAUTE

### Le Bug
```gdscript
func _go_to_hall() -> void:
    $fondPresent.hide()
    $Parking.hide()
    _set_parking_collisions(false)
    $Parking.set_interactive(false)
    hall.show()
    # ← couloir, pc_controle, vestiaire, salle_machine, salle_electricite
    #   toujours VISIBLES sous le hall !
```

Si le joueur est dans une sous-zone (vestiaire, salle machine, etc.) et que `_go_to_hall()` est appelé, ces zones restent affichées sous le hall. Le joueur peut interagir avec des éléments de sous-zones invisibles.

### Correction
```gdscript
func _go_to_hall() -> void:
    couloir.hide()
    _set_couloir_collisions(false)
    pc_controle.hide()
    _set_pc_controle_collisions(false)
    vestiaire.stop()
    _set_vestiaire_collisions(false)
    salle_machine.hide()
    _set_salle_machine_collisions(false)
    salle_electricite.hide()
    _set_salle_electricite_collisions(false)
    $fondPresent.hide()
    $Parking.hide()
    ...
```

---

## M3 — Prompts disjoncteur jamais cachés

**Fichier :** `Present.gd:551-559`
**Sévérité :** 🟡 MOYENNE

### Le Bug
```gdfunc
func _on_disjoncteur_entered(body: Node2D) -> void:
    if body == time_aunote and salle_electricite.visible:
        if _salle_machine_done and not _disjoncteur_done:
            _player_at_disjoncteur = true
            _disjoncteur_prompt.visible = true
        elif not _salle_machine_done:
            _disjoncteur_locked_prompt.visible = true
        # ← Si les DEUX sont vraies, AUCUN prompt n'est caché
```

Quand `_salle_machine_done` ET `_disjoncteur_done` sont tous les deux vrais, aucun des deux prompts n'est explicitement mis à `false`. Le prompt du body_entered précédent peut rester affiché.

### Correction
```gdscript
func _on_disjoncteur_entered(body: Node2D) -> void:
    if body == time_aunote and salle_electricite.visible:
        _disjoncteur_prompt.visible = false
        _disjoncteur_locked_prompt.visible = false
        if _salle_machine_done and not _disjoncteur_done:
            _player_at_disjoncteur = true
            _disjoncteur_prompt.visible = true
        elif not _salle_machine_done:
            _disjoncteur_locked_prompt.visible = true
```
