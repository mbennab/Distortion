# Rebalance Minigames MoyenÂge — Plan d'Implémentation

**Date** : 2026-05-18  
**Branche** : `feature/rebalance-moyenage-minigames`  
**Status** : Ready for implementation

---

## Résumé

2 fichiers à modifier, 2 constantes à remplacer. Aucune nouvelle ligne de code, aucune nouvelle logique. Changements purement paramétriques.

---

## Étape 1 — MiniJeuEcouteTables : resserrer ROUND_CONFIG

**Fichier** : `Scripts/MiniJeuEcouteTables.gd`  
**Localisation** : Lignes 5-9 (const ROUND_CONFIG)

### Code actuel (à remplacer)

```gdscript
const ROUND_CONFIG := [
	{"green_speed": 60.0, "info_rate": 15.0, "attn_rate": 10.0, "dir_min": 1.5, "dir_max": 3.0},
	{"green_speed": 100.0, "info_rate": 12.0, "attn_rate": 13.0, "dir_min": 1.0, "dir_max": 2.0},
	{"green_speed": 150.0, "info_rate": 10.0, "attn_rate": 18.0, "dir_min": 0.5, "dir_max": 1.5},
]
```

### Nouveau code

```gdscript
const ROUND_CONFIG := [
	{"green_speed": 80.0, "info_rate": 12.0, "attn_rate": 12.0, "dir_min": 1.2, "dir_max": 2.5},
	{"green_speed": 130.0, "info_rate": 10.0, "attn_rate": 17.0, "dir_min": 0.8, "dir_max": 1.6},
	{"green_speed": 190.0, "info_rate": 7.0, "attn_rate": 24.0, "dir_min": 0.4, "dir_max": 1.2},
]
```

### Détail des changements par table

#### Table 1 (facile)
| Paramètre    | Avant | Après | Δ       |
|-------------|-------|-------|---------|
| green_speed | 60    | 80    | +33%    |
| info_rate   | 15    | 12    | -20%    |
| attn_rate   | 10    | 12    | +20%    |
| dir_min     | 1.5   | 1.2   | -20%    |
| dir_max     | 3.0   | 2.5   | -17%    |

#### Table 2 (moyen)
| Paramètre    | Avant | Après | Δ       |
|-------------|-------|-------|---------|
| green_speed | 100   | 130   | +30%    |
| info_rate   | 12    | 10    | -17%    |
| attn_rate   | 13    | 17    | +31%    |
| dir_min     | 1.0   | 0.8   | -20%    |
| dir_max     | 2.0   | 1.6   | -20%    |

#### Table 3 (difficile)
| Paramètre    | Avant | Après | Δ       |
|-------------|-------|-------|---------|
| green_speed | 150   | 190   | +27%    |
| info_rate   | 10    | 7     | -30%    |
| attn_rate   | 18    | 24    | +33%    |
| dir_min     | 0.5   | 0.4   | -20%    |
| dir_max     | 1.5   | 1.2   | -20%    |

### Vérification post-édition
- [ ] `ROUND_CONFIG` contient exactement 3 entrées
- [ ] Chaque entrée a exactement les 5 clés : `green_speed`, `info_rate`, `attn_rate`, `dir_min`, `dir_max`
- [ ] Toutes les valeurs sont des floats (`.0`)
- [ ] Les index `[round - 1]` en ligne 26 et 146 restent valides

---

## Étape 2 — MiniJeuMarchandage : élargir ROUND_PARAMS

**Fichier** : `Scripts/MiniJeuMarchandage.gd`  
**Localisation** : Lignes 16-25 (const ROUND_PARAMS)

### Code actuel (à remplacer)

```gdscript
const ROUND_PARAMS := [
	[2.00, 55.0, 0.50],
	[1.75, 55.0, 0.44],
	[1.50, 55.0, 0.38],
	[1.28, 55.0, 0.33],
	[1.08, 55.0, 0.28],
	[0.90, 55.0, 0.24],
	[0.75, 55.0, 0.20],
	[0.62, 55.0, 0.16],
]
```

### Nouveau code

```gdscript
const ROUND_PARAMS := [
	[2.00, 60.0, 0.50],
	[1.75, 60.0, 0.44],
	[1.50, 65.0, 0.38],
	[1.28, 65.0, 0.33],
	[1.08, 70.0, 0.28],
	[0.90, 70.0, 0.24],
	[0.75, 75.0, 0.20],
	[0.62, 75.0, 0.16],
]
```

### Détail des changements

| Round | Rayon actuel | Rayon nouveau | Effectif (radius+28) | Δ effectif |
|-------|-------------|---------------|----------------------|-----------|
| 1     | 55          | 60            | 83→88               | +6%       |
| 2     | 55          | 60            | 83→88               | +6%       |
| 3     | 55          | 65            | 83→93               | +12%      |
| 4     | 55          | 65            | 83→93               | +12%      |
| 5     | 55          | 70            | 83→98               | +18%      |
| 6     | 55          | 70            | 83→98               | +18%      |
| 7     | 55          | 75            | 83→103              | +24%      |
| 8     | 55          | 75            | 83→103              | +24%      |

### Zones du code impactées par ce changement

Ces fonctions lisent `ROUND_PARAMS[_round]` ou `_fall_radius` — elles **ne nécessitent aucune modification** car elles se contentent de lire la valeur :

| Ligne(s) | Code | Effet du changement |
|----------|------|---------------------|
| 260-263  | `_fall_radius = float(params[1])` | Le rayon est chargé depuis le tableau → automatiquement mis à jour |
| 494      | `absf(...) <= _fall_radius + 28.0` | Détection de capture → automatiquement plus large |
| 567      | `pr = (_fall_radius + 28.0) + sin(...)` | Anneau visuel autour du joueur → s'adapte automatiquement |

### Vérification post-édition
- [ ] `ROUND_PARAMS` contient exactement 8 entrées
- [ ] Seul le 2e élément (catch_radius) de chaque sous-tableau est modifié
- [ ] Les durées de chute (1er élément) sont inchangées
- [ ] Les durées d'anticipation (3e élément) sont inchangées
- [ ] `TOTAL_ROUNDS` (ligne 6) vaut toujours 8

---

## Étape 3 — Vérification JSON

Aucune modification des fichiers JSON de dimension — les minigames sont purement en code et ne référencent pas les dimensions.

Vérification rapide que les JSON restent valides :
```bash
python3 -c "import json; json.load(open('MoyenAge/dimension_moyenage.json')); print('OK')"
```

---

## Étape 4 — Commit

```bash
git add Scripts/MiniJeuEcouteTables.gd Scripts/MiniJeuMarchandage.gd
git commit -m "rebalance: ecoutes +30% dur, marchandage rayon progressif +6→24%"
```

---

## Risques et points d'attention

1. **Aucun** — changements purement paramétriques. Les constantes sont consommées de façon générique (lecture par index dans un tableau), donc les nouveaux nombres sont automatiquement utilisés partout.
2. **Pas de régression possible** sur le flux de quête : les minigames sont appelés de la même façon (`new()`, `add_child()`, signal `done`), seule la difficulté interne change.
3. **Si trop dur/facile** : ajuster les constantes est trivial, aucune autre modification nécessaire.

---

## Ordre d'exécution recommandé

1. Modifier `MiniJeuEcouteTables.gd` → `ROUND_CONFIG`
2. Modifier `MiniJeuMarchandage.gd` → `ROUND_PARAMS`
3. Valider JSON dimension
4. Commit
