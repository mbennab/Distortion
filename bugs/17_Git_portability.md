# 🔵 BASSE — Portabilité Git : Accents dans les noms de fichiers

---

## L5 — Accent `é` dans `pnj_securité.gd`

**Fichier :** `Present/pnj_securité.gd` (nom complet)
**Sévérité :** BASSE mais risque réel

### Le Problème
Le fichier contient un `é` accentué dans son nom :
```
Present/pnj_securité.gd
```

### Pourquoi c'est problématique

Sous Linux (ext4, btrfs), les caractères UTF-8 fonctionnent nativement. Mais :

| Système | Comportement | Risque |
|---------|-------------|--------|
| **macOS (HFS+/APFS)** | Normalise NFD `e` + `´` → fichier "non trouvé" | ÉLEVÉ |
| **Windows (NTFS)** | Normalisation différente | MOYEN |
| **Git cross-platform** | `core.precomposeunicode` varie selon config | MOYEN |

Si un développeur clone le projet sur macOS, le fichier `pnj_securité.gd` peut ne pas être trouvé car le système normalise le `é` en `e` + accent combinant, tandis que git stocke la forme précomposée.

### Impact
- `git status` peut montrer le fichier comme modifié sans raison
- Godot peut ne pas trouver le script au chargement
- Certains outils CI peuvent échouer

### Correction
Renommer le fichier sans accent et mettre à jour les références :

```
Present/pnj_securite.gd    (sans accent)
```

Mettre à jour les références dans :
- `Present/Present.gd` (chargement du script)
- La scène `.tscn` qui référence le script
- Tout `preload()` ou `load()` vers ce fichier
