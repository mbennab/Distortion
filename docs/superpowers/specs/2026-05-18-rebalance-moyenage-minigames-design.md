# Rebalance Minigames MoyenÂge — Design Spec

**Date** : 2026-05-18  
**Branche** : `feature/rebalance-moyenage-minigames`  
**Status** : Draft

---

## Objectif

Ajuster la difficulté de deux minigames du MoyenÂge :
1. **MiniJeuEcouteTables** (espionnage à l'auberge) → un peu plus dur
2. **MiniJeuMarchandage** (attraper les fringues du marchand) → légèrement plus facile

Les deux ajustements sont purement paramétriques : aucune mécanique nouvelle, aucun changement de structure.

---

## 1. MiniJeuEcouteTables — Rendre plus dur

### Mécanique actuelle

- 3 tables (rounds) à écouter dans l'auberge
- Barre verticale (350px), zone verte (60px) oscillante, curseur contrôlé par **E maintenu** (monte 250px/s) / **relâché** (descend 150px/s)
- 2 jauges : **Infos glanées** (vert, se remplit quand curseur dans la zone) vs **Éveil des soupçons** (rouge, se remplit quand curseur hors zone)
- Gagner : info à 100% avant suspicion. Perdre : suspicion à 100% → **toutes les tables reset**
- `ROUND_CONFIG` : 3 entrées avec difficulté croissante par table

### Paramètres actuels

| Table | green_speed | info_rate | attn_rate | dir_min | dir_max |
|-------|-------------|-----------|-----------|---------|---------|
| 1     | 60          | 15        | 10        | 1.5     | 3.0     |
| 2     | 100         | 12        | 13        | 1.0     | 2.0     |
| 3     | 150         | 10        | 18        | 0.5     | 1.5     |

### Nouveaux paramètres (~20-30% plus dur)

| Table | green_speed | info_rate | attn_rate | dir_min | dir_max |
|-------|-------------|-----------|-----------|---------|---------|
| 1     | 80          | 12        | 12        | 1.2     | 2.5     |
| 2     | 130         | 10        | 17        | 0.8     | 1.6     |
| 3     | 190         | 7         | 24        | 0.4     | 1.2     |

### Justification

- **Table 1** : reste accessible (~6.5s pour gagner si dans la zone), mais n'est plus triviale. La suspicion monte maintenant à 12/s, forçant une attention immédiate.
- **Table 2** : info_rate < attn_rate signifie qu'il faut être dans la zone >63% du temps. La zone traverse la barre en ~1.6s.
- **Table 3** : attn_rate 24/s vs info_rate 7/s → faut être dans la zone ~77% du temps. Zone à 190px/s traverse la barre en ~1.4s, changements de direction toutes les 0.4-1.2s. Réellement tendu.

### Non modifié

- Taille de la barre (350px), zone verte (60px)
- Vitesse du curseur (250 up / 150 down)
- Pénalité d'échec (reset complet des 3 tables)
- Nombre de tables (3)

---

## 2. MiniJeuMarchandage — Rendre plus facile

### Mécanique actuelle

- 8 lancers : 5 bons items à attraper, 3 pièges à esquiver
- Condition de victoire : ≥4 bons attrapés ET ≤1 piège touché
- Joueur bouge gauche/droite à 720px/s
- L'item tombe du marchand avec trajectoire parabolique + wobble latéral
- Détection de capture : `absf(item_x - player_x) <= _fall_radius + 28.0`

### Paramètres actuels

`ROUND_PARAMS` : `[durée_chute, rayon_attrap, durée_anticip]`

| Round | fall_duration | catch_radius | anticipate |
|-------|---------------|--------------|------------|
| 1     | 2.00          | 55           | 0.50       |
| 2     | 1.75          | 55           | 0.44       |
| 3     | 1.50          | 55           | 0.38       |
| 4     | 1.28          | 55           | 0.33       |
| 5     | 1.08          | 55           | 0.28       |
| 6     | 0.90          | 55           | 0.24       |
| 7     | 0.75          | 55           | 0.20       |
| 8     | 0.62          | 55           | 0.16       |

**Problème** : le rayon de capture est constant à 55px pour tous les rounds alors que la vitesse de chute augmente. Le joueur perd plus par vitesse que par précision.

### Nouveaux paramètres (rayon progressif)

| Round | fall_duration | catch_radius | anticipate | Effectif (radius+28) |
|-------|---------------|--------------|------------|----------------------|
| 1     | 2.00          | **60**        | 0.50       | 88px (+6%)           |
| 2     | 1.75          | **60**        | 0.44       | 88px (+6%)           |
| 3     | 1.50          | **65**        | 0.38       | 93px (+12%)          |
| 4     | 1.28          | **65**        | 0.33       | 93px (+12%)          |
| 5     | 1.08          | **70**        | 0.28       | 98px (+18%)          |
| 6     | 0.90          | **70**        | 0.24       | 98px (+18%)          |
| 7     | 0.75          | **75**        | 0.20       | 103px (+24%)         |
| 8     | 0.62          | **75**        | 0.16       | 103px (+24%)         |

### Justification

- Le bonus est progressif : +6% en début de partie (quasi imperceptible), +24% sur les 2 derniers rounds. C'est là que les joueurs échouent le plus souvent.
- Ne touche pas à la durée de chute (la « pression temporelle » reste identique).
- La calibration « toujours atteignable depuis le centre » est préservée — le rayon plus large ne fait que réduire la précision nécessaire.
- L'augmentation est « légère » comme demandé : un joueur qui ratait de 15px au round 8 réussira maintenant.

### Non modifié

- PLAYER_SPEED (720px/s)
- Nombre de rounds (8), good (5), decoy (3)
- Condition de victoire (≥4 catches, ≤1 decoy)
- Trajectoire parabolique, wobble, positions marchand
- Effets visuels (flash, shake, dust, combo)
- Tous les pools d'items et séquençage

---

## Fichiers modifiés

| Fichier | Lignes | Changement |
|---------|--------|------------|
| `Scripts/MiniJeuEcouteTables.gd` | 5-9 | Remplacer `ROUND_CONFIG` par nouveaux paramètres |
| `Scripts/MiniJeuMarchandage.gd` | 16-25 | Remplacer `ROUND_PARAMS` par rayons progressifs |

---

## Tests de validation

1. **MiniJeuEcouteTables** : jouer les 3 tables, vérifier que la table 1 reste gagnable en ~7s, la table 3 est significativement plus tendue mais atteignable.
2. **MiniJeuMarchandage** : jouer les 8 rounds, vérifier que la zone de capture visuelle (anneau autour du joueur) reflète bien le nouveau rayon, que les attrapes de fin de partie sont plus indulgentes.
3. **Non-régression** : vérifier que rien ne casse dans le flux de quête (parler au roi → prison → évasion → marchand → auberge).
