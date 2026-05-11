# Tutoriel — Générateur JSON pour Distortion

Ce dossier contient les outils pour créer, éditer et tester les fichiers de dialogue (`dimension_*.json`) du jeu **timeOnaute (Distortion)**.

---

## Démarrage rapide

```bash
cd GenerateurJson
pip install -r requirements.txt
python app.py                     # → http://localhost:8000
```

La clé API est lue depuis `../.env` (racine du projet). Pas d'export nécessaire.

---

## 1. AI Studio (recommandé) — `http://localhost:8000/ai-builder`

L'outil principal pour créer et tester des dimensions. Tout se fait en discutant avec l'IA.

**Modèle** : `mistralai/mistral-small-3.2-24b-instruct` via OpenRouter (24B, bien meilleur que le 3B précédent pour la génération JSON structurée). Override possible : `MODEL=mon-modele python app.py`.

---

### 🧠 Créer — Brainstorm mode

#### Démarrage rapide par ère

Une barre de boutons en haut permet de démarrer instantanément pour une ère spécifique :

| Bouton | Ère | Contexte pré-injecté |
|--------|-----|----------------------|
| 🌀 HUB | Hub Central | Nexus temporel, Gardien du Nexus existant, portails |
| 🏰 Moyen Âge | Médiévale | Château, roi mourant existant, prison, chevaliers |
| ☢️ Présent | Nucléaire 2087 | Ruines, bunkers, dimension_nuclear.json de référence |
| 🚀 Futur | Futuriste | Cité hi-tech, pnj_futur.gd visuel existant, sous-sol |
| ✏️ Libre | — | Zone de texte directe, décris ce que tu veux |

L'IA connaît le lore complet de Distortion (4 ères, PNJs existants, mécaniques) — elle propose du contenu cohérent avec ce qui est déjà dans le jeu.

#### 4 phases automatiques

1. **Pitch** — balancez votre concept, l'IA extrait : dimension, PNJs, quêtes
2. **Détail PNJ** — fiche complète pour chaque PNJ (speech, connaissances, objectifs, intentions, arc), vous validez/ajustez
3. **Détail Quêtes** — étapes, PNJs impliqués, dépendances, conditions
4. **Finalisation** — global_fallbacks, mini-jeux, items, sauvegarde

Répondez "ok", "oui", "parfait", ou précisez ce que vous voulez changer. L'IA passe à l'étape suivante sans redemander.

#### Autosave

Le brouillon en cours est automatiquement sauvegardé dans `localStorage` du navigateur. Rechargez la page : il est restauré. Ctrl+S sauvegarde sur le serveur.

---

### 📝 Modifier — Import et édition

Importez un JSON existant (fichier, serveur workshop, ou **dossiers du jeu Godot** directement), l'IA vous aide à le modifier chirurgicalement.

```
"Ajoute un PNJ marchand avec 4 intentions"  →  fiche complète générée
"Change le ton du roi, plus désespéré"       →  seul le champ tone/speech change
"Ajoute une quête secondaire liée à Zak"    →  quête + conditions dans les intentions
```

L'IA a accès au JSON complet en contexte : elle ne perd aucun champ lors des modifications.

---

### 🧪 Tester — Dialogue direct

Sélectionnez un PNJ et parlez-lui comme dans le jeu. Le prompt utilisé est **identique** à celui du DialogueSystem Godot.

#### Debug bar

Une barre fixe au-dessus du chat affiche en temps réel :

| Indicateur | Description |
|------------|-------------|
| 💬 `X/5` | Numéro du message courant sur 5 max |
| ⚡ `action dans X` | Nombre de messages avant forçage automatique de l'action trigger |
| 🎯 `X intentions` | Nombre d'intentions actives pour l'état de quête actuel |
| Pills de quêtes | État de chaque quête — **cliquer pour cycler** |

#### Contrôle des états de quête

Cliquez sur une pill de quête pour faire avancer son état :
```
not_started → étape 1 → étape 2 → ... → done → not_started
```
La conversation se réinitialise automatiquement pour refléter les nouvelles conditions d'intention. Cela permet de tester toutes les branches d'un PNJ sans modifier le JSON.

---

### 💾 Sauver vs 🚀 Déployer

| Action | Effet |
|--------|-------|
| **💾 Sauver** (Ctrl+S) | Sauvegarde dans `dimensions/` (workshop local) |
| **🚀 Déployer** | Sauvegarde dans `dimensions/` **ET** copie dans le dossier du jeu Godot |
| **📋** | Copie le JSON dans le presse-papier |

Le bouton Déployer est visible uniquement quand l'ID de la dimension correspond à une ère connue :

| meta.id | Dossier cible |
|---------|---------------|
| `hub` | `HUB Central/dimension_hub.json` |
| `moyenage` | `MoyenAge/dimension_moyenage.json` |
| `nuclear` | `Present/dimension_nuclear.json` |
| `futur` | `Futur/dimension_futur.json` |

#### Vue Fiches

Basculez entre **JSON** et **Fiches** dans le preview pour voir les NPCs sous forme de cartes lisibles (tone, état émotionnel, liste d'intentions avec conditions et actions, arc de conversation) et les quêtes avec leurs étapes.

---

## 2. CLI — Tester en ligne de commande

```bash
# Mode brainstorm IA (l'IA vous interviewe)
python distortion_dialogue.py --ai

# Wizard manuel
python distortion_dialogue.py --new mon_nom

# Tester une dimension
python distortion_dialogue.py
python distortion_dialogue.py dimensions/dimension_nuclear.json
```

### Commandes

| Commande | Description |
|----------|-------------|
| `/npc <id>` ou `/npc` | Parler à un PNJ |
| `/list` | Lister tous les PNJ |
| `/info` | Fiche détaillée du PNJ actuel |
| `/state` | État des quêtes |
| `/history` | Historique de la conversation |
| `/step <qid> <sid>` | Avancer une étape de quête |
| `/complete <qid>` | Terminer une quête |
| `/reset <qid>` | Réinitialiser une quête |
| `/action <type> <id>` | Déclencher une action manuellement |
| `/model <id>` | Changer le modèle |
| `/key <apikey>` | Définir la clé API |
| `/help` | Aide |
| `/quit` | Quitter |

Mode simulation disponible sans clé API (réponses préfixées `[SIMULÉ]`).

---

## 3. Éditeur web manuel — `http://localhost:8000`

Pour l'édition fine des JSON.

- **Sidebar** : lister/créer/supprimer/importer/exporter
- **Onglet PNJ** : identité, speech, connaissances, objectifs, arc, intentions
- **Quick-add** : barre rapide `déclencheur | exemple | trigger/action`
- **Onglet Quêtes** : étapes avec drag-and-drop
- **Validation** : erreurs en temps réel (IDs, fallbacks, conditions)

---

## 4. Format JSON

```jsonc
{
  "meta": {"id": "moyenage", "name": "Moyen Âge", "era": "Médiévale", "description": "...", "completed": false},
  "npcs": [{
    "id": "npc_roi_moyenage",
    "name": "Le Roi du Château",
    "personality": {
      "tone": "noble, solennel, mourant",
      "backstory": "Souverain usé par les guerres, vient d'être poignardé",
      "emotional_state": "mourant, affaibli, paniqué mais digne",
      "speech": {
        "vouvoiement": true,           // true = vous, false = tu
        "vocatif": "voyageur",         // comment il appelle le joueur
        "phrases": "courtes, 1-2 phrases haletantes",
        "expressions": ["tousse", "sa voix faiblit"],
        "interdits": ["ne connais PAS l'assassin"]
      },
      "knowledge": ["il meurt", "l'assassin s'est enfui"],
      "goals": ["trouver de l'aide", "appeler ses gardes"],
      "conversation_arc": [
        {"phase": 1, "until_message": 2, "focus": "expliquer ce qui arrive"},
        {"phase": 2, "until_message": 4, "focus": "chercher de l'aide"},
        {"phase": 3, "until_message": 5, "focus": "agonie, dire adieu"}
      ]
    },
    "intentions": [{
      "id": "roi_adieu",
      "condition": null,               // null = toujours dispo
      "trigger": "le joueur dit au revoir",
      "example": "GARDES ! Venez m'aider...",
      "action": {"type": "trigger", "id": "roi_adieu", "description": "Le roi meurt."}
    }],
    "fallbacks": {
      "off_topic": "...", "insult": "...", "timeout": "...",
      "unknown": "...", "default_template": "Je suis {name}. Que veux-tu ?"
    }
  }],
  "quests": [{
    "id": "quete_roi", "title": "La mort du Roi", "status": "not_started",
    "requires_quests": [],
    "steps": [
      {"id": "parler_au_roi", "description": "Parler au roi mourant"},
      {"id": "roi_appelle_gardes", "description": "Le roi appelle les gardes"}
    ]
  }],
  "mini_games": [],
  "items": [],
  "global_fallbacks": {
    "off_topic": "...", "insult": "...", "timeout": "...",
    "unknown": "...", "default_template": "... {name} ..."
  }
}
```

---

## 5. Patterns

### PNJ mourant (arc forcé — action à 5 msg max)
```jsonc
"conversation_arc": [
  {"phase": 1, "until_message": 2, "focus": "choc, explique"},
  {"phase": 2, "until_message": 4, "focus": "faiblit, cherche aide"},
  {"phase": 3, "until_message": 5, "focus": "agonie, adieu"}
]
// Une intention avec action trigger → forcée automatiquement à 5 messages
```

### PNJ guide (pas d'action, réponses libres)
```jsonc
"speech": {"vouvoiement": true, "vocatif": "voyageur", "phrases": "poétiques, 2-3"},
"interdits": ["ne dis jamais 'je ne sais pas'"],
"goals": ["guider vers un portail"]
```

### Conditions de quête
```jsonc
{"condition": null}                                                         // toujours dispo
{"condition": {"quest_id": "q", "quest_status": "not_started"}}            // quête pas commencée
{"condition": {"quest_id": "q", "quest_step": "etape_labo"}}               // étape spécifique active
{"condition": {"quest_id": "q", "quest_status": "done"}}                   // quête terminée
```

### Règles d'or
1. **`interdits`** bloquent l'IA : soyez précis ("ne connais PAS l'assassin")
2. **`conversation_arc`** donne une direction. Sans arc, l'IA reste cohérente mais sans but
3. **`goals`** orientent chaque réponse. L'IA les lit en priorité
4. **Actions forcées à 5 msg** si non déclenchées avant — parfait pour les cinématiques
5. **Tester avec les pills de quête** dans AI Studio pour valider toutes les branches
6. **`example` = guide**, pas texte fixe. L'IA reformule librement
7. **Déployer** uniquement quand la dimension est testée et validée (badge vert)

---

## 6. Dépannage

| Problème | Solution |
|----------|----------|
| "OPENROUTER_API_KEY non définie" | `.env` à la racine avec `OPENROUTER_API_KEY=sk-...` |
| L'IA répond du texte bizarre | Vérifier `interdits` et `knowledge` — l'IA invente si mal cadrée |
| L'action ne se déclenche pas | `action.type` et `action.id` doivent correspondre aux `intentions[].action` |
| 0 intentions dans le debug bar | Les conditions de quête filtrent tout — utiliser les pills pour changer l'état |
| Déployer grisé | `meta.id` doit être `hub`, `moyenage`, `nuclear` ou `futur` |
| 404 sur /ai-builder | Relancer `python app.py` |
| Erreur de validation | Cliquer sur le badge rouge dans le preview — la liste des erreurs s'affiche |
| JSON invalide | `python3 -c "import json; json.load(open('dimensions/dimension_X.json'))"` |
