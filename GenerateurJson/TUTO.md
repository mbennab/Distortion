# Tutoriel — Générateur JSON pour Distortion

Ce dossier contient les outils pour créer, éditer et tester les fichiers de dialogue (`dimension_*.json`) du jeu **timeOnaute (Distortion)**.

---

## Démarrage rapide (30 secondes)

```bash
cd GenerateurJson
pip install requests          # une seule dépendance
python distortion_dialogue.py # lance le wizard interactif ou auto-sélectionne une dimension
```

La clé API est lue automatiquement depuis `../.env` (racine du projet). Pas besoin d'exporter quoi que ce soit.

---

## 1. CLI — Tester ou créer des dialogues

### Lancement

```bash
# Mode wizard (création interactive)
python distortion_dialogue.py --new mon_nom

# Tester une dimension existante
python distortion_dialogue.py
python distortion_dialogue.py dimensions/dimension_nuclear.json
```

### Commandes

| Commande | Raccourci | Description |
|----------|-----------|-------------|
| `/npc <id>` | — | Parler à un PNJ |
| `/npc` | — | Choisir un PNJ dans la liste |
| `/list` | — | Lister tous les PNJ |
| `/info` | — | Fiche détaillée du PNJ actuel |
| `/state` | — | État des quêtes |
| `/history` | — | Historique de la conversation |
| `/step <qid> <sid>` | — | Avancer une étape de quête |
| `/complete <qid>` | — | Marquer une quête terminée |
| `/reset <qid>` | — | Réinitialiser une quête |
| `/action <type> <id>` | — | Déclencher une action manuellement |
| `/model <id>` | — | Changer le modèle OpenRouter |
| `/key <apikey>` | — | Définir la clé API |
| `/help` | `/h` `/?` | Aide |
| `/quit` | `/q` | Quitter |

### Exemple de session

```
╔══ Distortion Dialogue Tester v3 ══╗
║ Nucléaire (2087)
║ ✓ clé chargée  |  mistralai/ministral-3b-2512  |  temp=0.7
╚══════════════════════════╝

  PNJ disponibles :
    1. Dr. Hélène Vasseur [npc_docteur_helene]  (9 intentions, 0 actions)
    2. Colonel Bravo [npc_colonel_bravo]  (7 intentions, 0 actions)
    3. Zak l'Écumeur [npc_marchand_zak]  (6 intentions, 0 actions)

  Tapez /help pour les commandes, /npc <id> pour parler.

> /npc npc_docteur_helene

  ╔═ Dr. Hélène Vasseur [npc_docteur_helene] ════════════════════════
  ║ Tone: clinique, fatiguée mais déterminée...
  ║ État: épuisée mais lucide...
  ║ Parle: vouvoiement, vocatif=, 2-3 phrases
  ║ Objectifs:
  ║   • convaincre le joueur de récupérer le vaccin
  ║   • soigner les survivants du bunker
  ╚══════════════════════════════════════

  ┌─ État des quêtes ─
  │  ○ quete_vaccin [not_started] → etape_labo
  │  ○ quete_abri [not_started] → etape_bunker_trouve
  └────────────────────

  [Dr. Hélène Vasseur] Que voulez-vous me dire ?

> Bonjour, qui êtes-vous ?

  [Dr. Hélène Vasseur] Dr. Vasseur. Médecin de l'unité 7. Si vous êtes
  venu jusqu'ici sans crever des radiations, c'est que vous avez une bonne
  raison. Alors dites-moi ce qui vous amène.
  [msg #1 | 7 int | live]

> J'ai besoin d'un remède contre les radiations.

  [Dr. Hélène Vasseur] Il y avait un projet de vaccin avant l'effondrement.
  Le prototype est à Saint-Lazare. Si quelqu'un pouvait le récupérer...
  [msg #2 | 7 int | live]
```

### Mode simulation (sans clé API)

Si aucune clé n'est trouvée, le CLI fonctionne en mode simulation sans appeler l'API. Les réponses sont préfixées `[SIMULÉ]`. Parfait pour tester la structure JSON.

### Wizard mode — créer une dimension de zéro

```bash
python distortion_dialogue.py --new mon_royaume
```

Le wizard vous guide pas à pas :
1. Métadonnées (nom, époque, description)
2. Ajout de PNJ (nom, tempérament, backstory, état émotionnel, speech)
3. Intentions pour chaque PNJ (déclencheur, exemple, action optionnelle)
4. Sauvegarde automatique dans `dimensions/`

---

## 2. Éditeur web (interface graphique)

### Lancement

```bash
cd GenerateurJson
pip install -r requirements.txt
python app.py              # → http://localhost:8000
```

### Fonctionnalités

- **Sidebar** : lister/créer/supprimer/importer/exporter des dimensions
- **Onglet PNJ** : éditer identité, speech, connaissances, objectifs, arc de conversation
- **Quick-add** : barre en bas de la table d'intentions : `déclencheur | exemple | trigger/id_action`
- **Onglet Quêtes** : créer/modifier des quêtes avec étapes, drag-and-drop
- **Validation** : détection en temps réel des erreurs (IDs snake_case, fallbacks vides, etc.)

---

## 3. Format JSON complet

```jsonc
{
  "meta": {
    "id": "moyenage",              // snake_case, unique
    "name": "Moyen Âge",
    "era": "Médiévale",
    "description": "Un château fort...",
    "completed": false
  },
  "npcs": [{
    "id": "npc_roi_moyenage",
    "name": "Le Roi du Château",
    "personality": {
      "tone": "noble, solennel, mourant...",
      "backstory": "Souverain médiéval usé par les guerres...",
      "emotional_state": "mourant, affaibli, paniqué mais digne",
      "speech": {
        "vouvoiement": true,          // true = vous, false = tu
        "vocatif": "voyageur",        // comment le PNJ appelle le joueur
        "phrases": "très courtes, 1-2 phrases haletantes",
        "expressions": [              // comment il parle
          "tousse entre les mots",
          "sa voix faiblit"
        ],
        "interdits": [                // ce qu'il ne doit JAMAIS dire
          "ne connais PAS l'identité de l'assassin",
          "ne guéris jamais"
        ]
      },
      "knowledge": [                  // faits, monde, personnages
        "il est en train de mourir",
        "son assassin s'est enfui"
      ],
      "goals": [                      // objectifs de la conversation
        "trouver de l'aide",
        "appeler ses gardes avant de mourir"
      ],
      "conversation_arc": [           // phases de la conversation
        {"phase": 1, "until_message": 2,
         "focus": "expliquer ce qui arrive, être sous le choc"},
        {"phase": 2, "until_message": 4,
         "focus": "chercher de l'aide, faiblir"},
        {"phase": 3, "until_message": 5,
         "focus": "agonie, appeler les gardes, dire adieu"}
      ]
    },
    "intentions": [{
      "id": "roi_adieu",
      "condition": {                  // null = toujours dispo, sinon :
        "quest_id": null,             //   id de quête
        "quest_status": null,         //   "not_started" | "done" | null
        "quest_step": null            //   step_id | null
      },
      "trigger": "le joueur dit au revoir ou la conversation touche à sa fin",
      "example": "GARDES ! Venez m'aider... Je me sens mourir...",
      "action": {                     // optionnel — déclenche un event jeu
        "type": "trigger",
        "id": "roi_adieu",
        "description": "Le roi meurt, les gardes arrivent et accusent le joueur."
      }
    }],
    "fallbacks": {
      "off_topic": "Par la couronne ! Je meurs, parle-moi de choses qui comptent.",
      "insult": "Garde ta langue, insolent ! Je suis ton roi.",
      "timeout": "Le temps... s'arrête... Je ne sens plus rien...",
      "unknown": "Je... je ne comprends pas. Ma vision se trouble...",
      "default_template": "Écoute, voyageur, je meurs. Que veux-tu ?"
    }
  }],
  "quests": [{
    "id": "quete_roi",
    "title": "La mort du Roi",
    "status": "not_started",
    "requires_quests": [],
    "steps": [
      {"id": "parler_au_roi", "description": "Parler au roi mourant"},
      {"id": "roi_appelle_gardes", "description": "Le roi appelle les gardes"}
    ]
  }],
  "mini_games": [{
    "id": "mini_jeu_crochetage",
    "name": "Crochetage",
    "linked_quest_id": "quete_abri",
    "requires_quest_step": "etape_bunker_ouvert"
  }],
  "items": [{
    "id": "objet_cle_bunker",
    "name": "Clé du bunker",
    "description": "Clé rouillée..."
  }],
  "global_fallbacks": {
    "off_topic": "...",
    "insult": "...",
    "timeout": "...",
    "unknown": "...",
    "default_template": "Le PNJ te regarde. {name}, que dis-tu ?"
  }
}
```

---

## 4. Patterns et conseils

### PNJ mourant (arc forcé)

```jsonc
"conversation_arc": [
  {"phase": 1, "until_message": 2, "focus": "sous le choc, explique ce qui arrive"},
  {"phase": 2, "until_message": 4, "focus": "faiblit, cherche de l'aide"},
  {"phase": 3, "until_message": 5, "focus": "agonie, dit adieu"}
]
// + une intention avec action trigger → forcée à msg 5 si pas déclenchée avant
```

### PNJ guide (réponses libres, pas d'action)

```jsonc
"speech": {
  "vouvoiement": true,
  "vocatif": "voyageur",
  "phrases": "poétiques, 2-3 par réponse",
  "expressions": ["parle par énigmes", "métaphores temporelles"],
  "interdits": ["ne dis jamais 'je ne sais pas'"]
},
"goals": ["guider le joueur vers un portail"],
"conversation_arc": [
  {"phase": 1, "until_message": 3, "focus": "accueillir, présenter les portails"},
  {"phase": 2, "until_message": 99, "focus": "répondre avec des énigmes"}
]
// intentions sans action → l'IA parle librement
```

### PNJ marchand (tutoiement, argot)

```jsonc
"speech": {
  "vouvoiement": false,     // tutoiement
  "vocatif": "l'ami",
  "phrases": "familières, argot, 2-3 phrases",
  "expressions": ["marchande tout", "utilise l'argot des terres désolées"],
  "interdits": ["ne donne jamais quelque chose gratuitement"]
}
```

### Conditions de quête

```jsonc
// Réplique toujours disponible
{"condition": null, ...}

// Seulement si la quête n'a pas commencé
{"condition": {"quest_id": "quete_vaccin", "quest_status": "not_started", "quest_step": null}, ...}

// Seulement pendant une étape spécifique
{"condition": {"quest_id": "quete_vaccin", "quest_status": null, "quest_step": "etape_labo"}, ...}

// Seulement si la quête est terminée
{"condition": {"quest_id": "quete_vaccin", "quest_status": "done", "quest_step": null}, ...}
```

### Règles d'or

1. **Les `interdits` sont votre meilleur outil** — ils empêchent l'IA de divaguer. Soyez précis.
2. **L'arc de conversation (`conversation_arc`)** est crucial pour les PNJ scénarisés. Sans arc, l'IA reste cohérente mais sans direction.
3. **Les `goals`** donnent un but à chaque conversation. L'IA les lit et adapte ses réponses.
4. **Les actions sont forcées à 5 messages** si le PNJ en a une et que l'IA ne l'a pas déclenchée. Pratique pour les cinématiques.
5. **Tester en CLI d'abord** avant d'intégrer dans Godot. Le mode simulation fonctionne sans clé API.
6. **Les `example` sont des guides**, pas du texte fixe. L'IA peut reformuler librement en gardant le sens.
7. **Un PNJ peut ne pas avoir d'action** — il sera purement conversationnel.

---

## 5. Intégration Godot

Les fichiers `dimension_*.json` créés ici sont directement utilisables par le jeu :
- Placer le JSON dans le dossier de l'ère correspondante (ex: `MoyenAge/dimension_moyenage.json`)
- Le `DialogueSystem` autoload charge automatiquement le JSON via `load_dimension(path)`
- Les actions `trigger` déclenchées par l'IA sont écoutées côté Godot via `action_triggered` signal

---

## 6. Dépannage

| Problème | Solution |
|----------|----------|
| "OPENROUTER_API_KEY non définie" | Créer un fichier `.env` à la racine avec `OPENROUTER_API_KEY=sk-...` |
| "Fichier introuvable" | Vérifier que le fichier existe dans `dimensions/` |
| L'IA répond du texte bizarre | Vérifier les `interdits` et `knowledge` du PNJ — l'IA invente si mal cadrée |
| L'action ne se déclenche pas | Vérifier que `action.type` et `action.id` sont bien définis dans `intentions` |
| Erreur de validation | Lancer `python app.py` → ouvrir `http://localhost:8000` → l'onglet validation liste les erreurs |
