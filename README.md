# timeOnaute (Distortion)

Jeu 2D développé avec **Godot 4.6+ standard** (GDScript, pas .NET).  
Le joueur incarne un **Time-Aunote** qui voyage dans le temps en traversant des portails colorés.

---

## Pour commencer

- Installer [Godot 4.6+](https://godotengine.org/) (version **standard**, pas .NET)
- Cloner le dépôt : `git clone https://github.com/mbennab/Distortion`
- Créer un fichier `.env` à la racine avec `OPENROUTER_API_KEY=votre_cle_api` (optionnel, requis pour le dialogue IA)
- Ouvrir Godot → Importer → sélectionner `project.godot`
- Lancer avec F5 ou le bouton ▶️

---

## Contrôles

| Action | Clavier |
|--------|---------|
| Déplacement | ZQSD / WASD / Flèches |
| Interagir / Parler | `E` |
| Fermer dialogue | `Échap` |

Les actions `marche_haut/bas/gauche/droite` et `interagir` sont dans `project.godot`.

---

## Architecture

```
Main.tscn (Node2D)
├── TimeAunoteDansHUBCentral → HUB avec 3 portails temporels (lueur verte/violette/orange), PNJ Gardien, chien interactif
├── MoyenAge → château médiéval, roi mourant, prison + crochetage, magasin + marchandage
├── Present → ère nucléaire (sans PNJ pour l'instant)
└── Futur → ère futuriste, SousSol accessible via escalier, 2 PNJs avec dialogues IA
```

**Flux de jeu :**
1. Le HUB s'affiche (son d'ambiance, lueurs portails). Parlez au **Gardien du Nexus** qui vous accueille avec une phrase d'accroche et vous guide vers les portails. Le **chien** aboie spontanément.
2. **Portail orange** (interne jaune) → Moyen Âge : le **roi mourant** vous accueille avec une phrase d'accroche qui lance l'enquête sur son assassinat. Échappez-vous de la prison en crochetant la serrure, puis rendez-vous au magasin pour parler au **marchand** et obtenir un déguisement. Une fois déguisé, le marchand vous redirige vers la **taverne** pour continuer l'enquête.
3. **Portail violet** (interne bleue) → Présent nucléaire (en développement).
4. **Portail vert** (interne rouge) → Futur : dialoguez avec La Mécano et La Cheffe, empruntez l'escalier vers le SousSol.

---

## Système de dialogue IA

Le dialogue est généré par l'IA (OpenRouter, modèle `mistralai/ministral-3b-2512`). Chaque PNJ a une fiche de personnalité détaillée dans son fichier `dimension_*.json` :

- **Personnalité** : ton, histoire, état émotionnel
- **Façon de parler** : vouvoiement, vocatif, longueur des phrases, expressions, interdits
- **Connaissances** : ce que le PNJ sait (et ne sait pas)
- **Objectifs** : ce que le PNJ cherche à accomplir pendant la conversation
- **Arc de conversation** : phases qui guident le focus de l'IA (accueil → discussion → conclusion)
- **Intentions** : sujets de conversation avec exemples de réponse et actions de jeu optionnelles
- **Phrase d'accroche** (`first_message`) : message automatique affiché en machine à écrire lors du premier dialogue avec le PNJ, pour guider le joueur

Les actions (ex: `roi_adieu`) déclenchent des événements narratifs dans le jeu (cinématiques, quêtes).

### Quêtes et progression

Le système de quêtes (`quests` dans les JSONs de dimension) permet de faire évoluer le comportement des PNJs selon l'avancement du joueur :

- **Marchand du Moyen Âge** : parle de son armoire à habits tant que la quête `quete_deguisement` n'est pas terminée. Une fois le déguisement obtenu, ses intentions changent automatiquement — il oriente le joueur vers la **taverne du village** pour enquêter.
- L'objectif en haut à droite se met à jour automatiquement via le signal `quest_updated`.

### Affichage (interface retro)

Tous les dialogues utilisent la même interface inspirée du Futur — un panneau en bas de l'écran, police monospace, effet machine à écrire, avec un **portrait du PNJ** à gauche.

### Portraits des PNJ

Chaque PNJ peut afficher son portrait pendant le dialogue. Le portrait est chargé depuis le champ `portrait_path` défini dans le script du PNJ.

**Ajouter un portrait à un PNJ :**

1. Placer l'image dans `art/<Ere>/` (ex: `art/MoyenAge/pnj-roi-HD.png`). Format recommandé : PNG, portrait vertical centré, résolution ~370x640.
2. Dans le script `.gd` du PNJ, modifier la valeur par défaut de `portrait_path` :
   ```gdscript
   @export var portrait_path: String = "res://art/MoyenAge/pnj-roi-HD.png"
   ```
   Ou renseigner le champ `Portrait Path` dans l'inspecteur Godot sur l'instance du PNJ dans la scène.
3. Si `portrait_path` est vide ou pointe vers un fichier inexistant, un **portrait générique** (silhouette) est affiché automatiquement.

**Portraits existants :**

| PNJ | Chemin |
|-----|--------|
| La Mécano (Futur) | `res://art/Futur/pnj-mécano-HD.png` |
| La Cheffe (Futur) | `res://art/Futur/pnj-cheffe-HD.png` |
| Le Roi du Château (Moyen Âge) | `res://art/MoyenAge/portrait_roi.png` |
| Le Marchand (Moyen Âge) | `res://art/MoyenAge/portrait_marchand.png` |
| Gardien du Nexus | *générique* |

---

## Mini-jeux

### Marchandage des Habits (magasin médiéval)
Le marchand vous lance ses affaires — attrapez les bons vêtements, esquivez les pièges.

**Objectif :** attraper au moins **4 vêtements sur 5** et se faire piéger au maximum **1 fois**.

| Élément | Détail |
|---------|--------|
| **Rounds** | 8 lancers (5 bons vêtements + 3 pièges mélangés aléatoirement) |
| **Contrôle** | ← → pour déplacer le personnage |
| **Items** | Bons items en couleur tissu — pièges en rouge avec ⚠ |
| **Difficulté** | Durée de chute 2.0 s → 0.62 s, zone d'attrape 55 px → 13 px |
| **Trajectoires** | Arc parabolique aléatoire + déviation latérale croissante (wobble) |
| **Marchand** | Se déplace entre 4 positions — le lancer part depuis sa position |
| **Sprites** | Personnage joueur et marchand en pixel art réel |
| **Barre d'objectifs** | Affichage temps réel `🎯 X/4 vêtements · ⚠ Y/2 pièges` |

Résultat : `done(true)` → déguisement obtenu, progression vers la sortie du Moyen Âge.

### Crochetage (prison)
Mini-jeu de timing : appuyer sur E quand l'indicateur passe dans la zone verte pour crocheter la serrure en 5 étapes.

---

## Assets

```
art/
├── perso_*.png              — sprites personnage (idle/marche 4 directions)
├── pnj-hub.png              — sprite du Gardien du Nexus
├── chien-hub.png            — sprite sheet du chien (2 frames)
├── hub final.png            — fond du HUB
├── MoyenAge/fond_moyen-age.png
├── Present/fond_nucleaire.png
└── Futur/fond_futur.png
audio/
├── hub/                     — son d'ambiance du HUB (.mp3/.ogg/.wav, boucle automatique)
└── chien/                   — aboiements du chien (bark*.mp3, chargement automatique)
```

---

## Contribuer

- Ne **jamais** ajouter de fichiers `.cs` ou `.csproj` (projet migré de C# vers GDScript)
- `.godot/` et `.env` sont dans `.gitignore` — ne pas les committer
- Le personnage dans `Personnage/` est partagé — toute modif doit s'y faire
- Utiliser `clampf()` / `clampi()` plutôt que `clamp()` avec l'inférence `:=`
- Les PNJ suivent le pattern `ZoneDialogue` + `add_to_group("npc_dialogue")` + `show_bubble/hide_bubble`
- Lire `AGENTS.md` pour les conventions techniques détaillées
