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
| Déplacement haut | `↑` / `Z` |
| Déplacement bas | `↓` / `S` |
| Déplacement gauche | `←` / `Q` |
| Déplacement droite | `→` / `D` |

Les actions `marche_haut/bas/gauche/droite` (ZQSD) sont définies dans `project.godot`. Les flèches utilisent les actions intégrées `ui_up/down/left/right`.

---

## Architecture

```
Main.tscn (Node2D)
├── TimeAunoteDansHUBCentral (Node2D) — scène du HUB central
│   ├── fondHubCentral (fond + collisions + portes + markers)
│   ├── TimeAunote (CharacterBody2D) — le personnage dans le HUB
│   └── timerSortie (Timer) — déclenche la sortie après une porte
│
└── TimeOnauteDansPrehistoire (Node2D) — scène préhistoire
    ├── fondPrehistoire (fond + animations + markers)
    └── TimeOnautePrehistoire (CharacterBody2D) — le personnage préhistorique
```

**Flux de jeu :**  
1. Le HUB central s'affiche en premier. Le personnage apparaît à `entreePrincipale`.  
2. Le joueur se déplace et peut entrer en collision avec :
   - Les **portes de voyage temporel** (jaune, bleue, rouge) → déclenchent une animation de sortie puis basculent vers le niveau suivant
   - Les **portes de voyage de salle** (gauche, droite) → téléportent le personnage de l'autre côté du HUB
   - Les **limites de déplacement** → bloquent le personnage (murs, tables)
3. Quand le HUB est terminé, la scène **Préhistoire** s'affiche.

### Scènes

| Fichier | Rôle |
|---------|------|
| `Main.tscn` | Orchestrateur : lance le HUB, puis la Préhistoire |
| `HUB Central/TimeAunoteDansHubCentral.tscn` | Conteneur du HUB : fond, portes, collisions, personnage |
| `HUB Central/TimeAunote.tscn` | Le personnage principal (CharacterBody2D) avec animations |
| `HUB Central/fondHubCentral.tscn` | Fond du HUB : image, collisions, portes animées, markers |
| `PorteJaune/TimeOnauteDansPrehistoire.tscn` | Conteneur de l'ère préhistorique |
| `PorteJaune/TimeOnautePrehistoire.tscn` | Personnage version préhistorique (CharacterBody2D) |
| `PorteJaune/fondPrehistoire.tscn` | Fond préhistorique avec porte d'arrivée animée |

### Scripts GDScript

| Fichier | Classe | Description |
|---------|--------|-------------|
| `Main.gd` | `Node2D` | Orchestrateur : démarre le HUB, puis switch vers Préhistoire quand le HUB se termine |
| `HUB Central/TimeAunoteDansHubCentral.gd` | `Node2D` | Gère le HUB : déplacements, collisions avec portes et murs, animations de sortie |
| `HUB Central/TimeAunote.gd` | `CharacterBody2D` | Personnage du HUB : apparition, animations (marche/repos/attente), collisions |
| `PorteJaune/TimeOnauteDansPrehistoire.gd` | `Node2D` | Gère la Préhistoire : apparition du personnage, gestion start/stop |
| `PorteJaune/TimeOnautePrehistoire.gd` | `CharacterBody2D` | Personnage préhistorique : déplacements, animations, collisions |

---

## Systèmes implémentés

### Déplacement

- **Dans le HUB :** `TimeAunoteDansHubCentral.gd` lit les entrées, normalise le vecteur, puis appelle `move_and_collide()` sur le personnage. Vitesse = **350** px/s.
- **En Préhistoire :** `TimeOnautePrehistoire.gd` gère ses propres déplacements en interne. Vitesse = **200** px/s.

### Collisions

Le HUB possède un système de collisions complet dans `fondHubCentral.tscn` :

| Corps de collision | Effet |
|--------------------|-------|
| `limitesDeplacament` (table + contour) | Bloque le personnage |
| `porteJaune` | Animation de sortie → switch vers Préhistoire |
| `porteBleue` | Animation de sortie (niveau à venir) |
| `porteRouge` | Animation de sortie (niveau à venir) |
| `porteGauche` | Téléporte le personnage à `retourDroite` |
| `porteDroite` | Téléporte le personnage à `retourGauche` |

Les collisions de portes déclenchent chacune une animation :
1. L'`AnimationPlayer` de la porte joue `"animationPorte"` (rotation + scale → 0)
2. L'`AnimationPlayer` du personnage joue `"animationPlayer"` (déplacement vers le centre de la porte + rotation)
3. Un `Timer` de 3 secondes déclenche le changement de niveau

### Animations

**Personnage du HUB** (`TimeAunote.tscn`) :
- `idle_face` / `idle_dos` / `idle_cote` — repos selon la direction
- `marche_face` / `marche_dos` / `marche_cote` — marche 4 directions
- `attente` — animation quand le personnage est immobile depuis +3s
- `animationPlayer` — animation de sortie (rotation + scale vers 0)

**Personnage préhistorique** (`TimeOnautePrehistoire.tscn`) :
- `repos` — immobile
- `marche_haut` / `marche_bas` / `marche_droite` — marche 4 directions
- `attente` — immobilité prolongée
- `animationPlayer` — animation d'arrivée (scale de 0 → 0.8 + rotation)

### Portes animées

Chaque porte voyage-temps (`porteJauneAnimee`, `porteBleueAnimee`, `porteRougeAnimee`) possède un `AnimationPlayer` avec une animation `"animationPorte"` qui réduit son `scale` à (0,0) et applique une rotation de ~360° sur 3 secondes.

---

## Assets graphiques

Tous les sprites sont dans `art/` :
- `art/` — personnage HUB (idle face/dos/côté, marche) + portes + fond HUB
- `art/prehistoire/` — personnage préhistorique (marche 4 dirs, repos) + fond + coffres

---

## Limitations actuelles

- Seul le portail **jaune** (Préhistoire) a un niveau jouable derrière lui ; bleu et rouge déclenchent l'animation mais n'ont pas de scène cible
- La Préhistoire n'a pas encore de collisions (pas de murs ni de portes de sortie)
- Pas de menu principal, pas de sauvegarde

---

## Contribuer

- Ne **jamais** ajouter de fichiers `.cs` ou `.csproj` (le projet a été migré de C# vers GDScript)
- Le dossier `.godot/` est dans `.gitignore` — ne pas le committer
- Les signaux dans les `.tscn` utilisent la convention snake_case (`_on_timer_sortie_timeout`)
- Les animations utilisent le format `".:property"` dans `find_track()`
- Lire `AGENTS.md` pour les conventions techniques
