# timeOnaute (Distortion)

Jeu 2D développé avec **Godot 4.6+ standard** (GDScript, pas .NET).  
Le joueur incarne un **Time-Aunote** qui voyage dans le temps en traversant des portails colorés.

---

## Pour commencer

- Installer [Godot 4.6+](https://godotengine.org/) (version **standard**, pas .NET)
- Cloner le dépôt : `git clone https://github.com/mbennab/Distortion`
- Ouvrir Godot → Importer → sélectionner `project.godot`
- Lancer avec F5 ou le bouton ▶️

---

## Contrôles

| Action | Clavier |
|--------|---------|
| Déplacement haut | `↑` / `Z` / `W` |
| Déplacement bas | `↓` / `S` |
| Déplacement gauche | `←` / `Q` / `A` |
| Déplacement droite | `→` / `D` |

Les actions `marche_haut/bas/gauche/droite` (ZQSD/WASD) sont définies dans `project.godot`.

---

## Architecture

```
Main.tscn (Node2D)
├── TimeAunoteDansHUBCentral (Node2D) — scène du HUB central
│   ├── fondHubCentral (fond + collisions + portes + markers + Camera2D)
│   ├── TimeAunote (CharacterBody2D) — instance de Personnage/TimeAunote.tscn
│   ├── pnj-hub (Node2D) — PNJ du HUB
│   ├── chien-hub (Node2D) — chien prankeur qui se balade dans le HUB
│   └── timerSortie (Timer) — déclenche le changement de niveau
│
├── MoyenAge (Node2D) — ère médiévale (portail jaune)
│   ├── fondMoyenAge (fond + markers + Camera2D)
│   └── TimeAunote (CharacterBody2D) — instance de Personnage/TimeAunote.tscn
│
├── Present (Node2D) — ère nucléaire (portail bleu)
│   ├── fondPresent (fond + markers + Camera2D)
│   └── TimeAunote (CharacterBody2D) — instance de Personnage/TimeAunote.tscn
│
└── Futur (Node2D) — ère futuriste (portail rouge)
    ├── fondFutur (fond + markers + Camera2D)
    └── TimeAunote (CharacterBody2D) — instance de Personnage/TimeAunote.tscn
```

**Flux de jeu :**
1. Le HUB central s'affiche. Le personnage, le PNJ et le chien prankeur apparaissent à leurs positions respectives.
2. Le joueur se déplace dans le HUB :
   - **Portes de voyage temporel** (jaune → Moyen-Âge, bleue → Présent, rouge → Futur) : particules + fade-out → transition vers l'ère
   - **Portes de salle** (gauche/droite) : téléportent le personnage de l'autre côté du HUB
   - **Limites de déplacement** : bloquent le personnage (murs, tables)
3. Dans chaque ère, le personnage apparaît avec une animation de spin-in et peut se déplacer librement.

### Personnage partagé

Le personnage `Personnage/TimeAunote.tscn` est instancié dans **toutes** les scènes (HUB + 3 ères). C'est le même CharacterBody2D avec les mêmes sprites et animations.

### PNJ et chien prankeur

Le HUB contient deux entités animées :
- **pnj-hub** — un PNJ statique avec animation idle, apparaît à `pnjPos`
- **chien-hub** — un chien prankeur avec animation idle-dog (2 frames, sprite sheet), apparaît à `chienPos`

Les deux sont cachés par défaut et rendus visibles via leur méthode `apparition(position)` appelée par `TimeAunoteDansHUBCentral.start()`.

### Portails

| Portail | Destination | Fond |
|---------|-------------|------|
| Jaune | Moyen-Âge | `art/MoyenAge/fond_moyen-age.png` |
| Bleu | Présent | `art/Present/fond_nucleaire.png` |
| Rouge | Futur | `art/Futur/fond_futur.png` |

### Animation d'arrivée

Chaque ère joue une animation d'apparition :
1. Burst de particules (couleur propre à l'ère) à la position d'entrée
2. Le personnage apparaît en spin-in : scale 0→0.8 avec overshoot, rotation 360°→0, fade-in
3. Les contrôles sont débloqués après l'animation (~1s)

---

## Assets graphiques

```
art/
├── perso_*.png              — sprites du personnage (idle/marche face/dos/côté)
├── pnj-hub.png              — sprite du PNJ du HUB
├── chien-hub.png            — sprite sheet du chien prankeur (2 frames)
├── chien-hub-queue.png      — queue du chien prankeur (variante)
├── hub final.png            — fond du HUB
├── porteJaune/Bleue/Rouge.png — sprites des portails
├── MoyenAge/fond_moyen-age.png — fond ère médiévale
├── Present/fond_nucleaire.png  — fond ère nucléaire
└── Futur/fond_futur.png        — fond ère futuriste
```

---

## Limitations actuelles

- Pas de retour des ères vers le HUB (one-way pour l'instant)
- Pas de collisions/murs dans les ères
- Pas de menu principal, pas de sauvegarde
- Le chien prankeur est visuel uniquement (pas d'interaction)

---

## Contribuer

- Ne **jamais** ajouter de fichiers `.cs` ou `.csproj` (le projet a été migré de C# vers GDScript)
- Le dossier `.godot/` est dans `.gitignore` — ne pas le committer
- Le personnage est dans `Personnage/` — toute modif doit y être faite, pas dupliquée
- Utiliser `clampf()` / `clampi()` plutôt que `clamp()` quand le type est inféré avec `:=`
- Lire `AGENTS.md` pour les conventions techniques
