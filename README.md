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
├── TimeAunoteDansHUBCentral → HUB avec 3 portails temporels, PNJ Gardien, chien prankeur
├── MoyenAge → château médiéval, roi mourant, prison + crochetage
├── Present → ère nucléaire (sans PNJ pour l'instant)
└── Futur → ère futuriste, SousSol accessible via escalier, PNJ visuel
```

**Flux de jeu :**
1. Le HUB s'affiche. Parlez au **Gardien du Nexus** qui vous guide vers les portails.
2. **Portail jaune** → Moyen Âge : parlez au roi mourant, découvrez son assassinat, échappez-vous de la prison en crochetant la serrure, puis rendez-vous au magasin pour **marchander des habits et obtenir un déguisement**.
3. **Portail bleu** → Présent nucléaire (en développement).
4. **Portail rouge** → Futur : explorez, empruntez l'escalier vers le SousSol.

---

## Système de dialogue IA

Le dialogue est généré par l'IA (OpenRouter, modèle `mistralai/ministral-3b-2512`). Chaque PNJ a une fiche de personnalité détaillée dans son fichier `dimension_*.json` :

- **Personnalité** : ton, histoire, état émotionnel
- **Façon de parler** : vouvoiement, vocatif, longueur des phrases, expressions, interdits
- **Connaissances** : ce que le PNJ sait (et ne sait pas)
- **Objectifs** : ce que le PNJ cherche à accomplir pendant la conversation
- **Arc de conversation** : phases qui guident le focus de l'IA (accueil → discussion → conclusion)
- **Intentions** : sujets de conversation avec exemples de réponse et actions de jeu optionnelles

Les actions (ex: `roi_adieu`) déclenchent des événements narratifs dans le jeu (cinématiques, quêtes).

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
├── chien-hub.png            — sprite sheet du chien prankeur (2 frames)
├── hub final.png            — fond du HUB
├── porteJaune/Bleue/Rouge.png — sprites portails
├── MoyenAge/fond_moyen-age.png
├── Present/fond_nucleaire.png
└── Futur/fond_futur.png
```

---

## Contribuer

- Ne **jamais** ajouter de fichiers `.cs` ou `.csproj` (projet migré de C# vers GDScript)
- `.godot/` et `.env` sont dans `.gitignore` — ne pas les committer
- Le personnage dans `Personnage/` est partagé — toute modif doit s'y faire
- Utiliser `clampf()` / `clampi()` plutôt que `clamp()` avec l'inférence `:=`
- Les PNJ suivent le pattern `ZoneDialogue` + `add_to_group("npc_dialogue")` + `show_bubble/hide_bubble`
- Lire `AGENTS.md` pour les conventions techniques détaillées
