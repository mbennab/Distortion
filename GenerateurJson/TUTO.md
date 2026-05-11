# Tutoriel — Générateur JSON pour Distortion

Ce dossier contient les outils pour créer, éditer et tester les fichiers de dialogue (`dimension_*.json`) du jeu **timeOnaute (Distortion)**.

---

## 1. Tester les dialogues en CLI (sans Godot)

L'outil `distortion_dialogue.py` permet de simuler une conversation avec n'importe quel PNJ en appelant l'API OpenRouter.

### Lancement

```bash
cd GenerateurJson
pip install requests    # dépendance unique
python distortion_dialogue.py dimensions/dimension_nuclear.json
```

La clé API est lue automatiquement depuis le fichier `.env` à la racine du projet (`../.env`), ou depuis la variable d'environnement `OPENROUTER_API_KEY`. Pas besoin d'exporter quoi que ce soit.

### Commandes

| Commande | Description |
|----------|-------------|
| `/npc <id>` | Sélectionner un PNJ (ex: `/npc npc_docteur_helene`) |
| `/list` | Lister tous les PNJ de la dimension |
| `/info` | Afficher la fiche détaillée du PNJ actuel |
| `/state` | Afficher l'état des quêtes |
| `/step <qid> <sid>` | Compléter une étape de quête |
| `/complete <qid>` | Marquer une quête comme terminée |
| `/reset <qid>` | Réinitialiser une quête |
| `/action <type> <id>` | Déclencher une action manuellement |
| `/history` | Afficher l'historique de la conversation |
| `/model <id>` | Changer le modèle OpenRouter |
| `/key <apikey>` | Définir la clé API manuellement |
| `/help` | Afficher l'aide |
| `/quit` | Quitter |

### Exemple de session

```
> /npc npc_docteur_helene
  🎭 Vous parlez maintenant à Dr. Hélène Vasseur

> Bonjour, qui êtes-vous ?
  [Dr. Hélène Vasseur] Dr. Vasseur. Médecin de l'unité 7. Si vous êtes venu jusqu'ici...
  [debug] msg #1 | 7 intentions filtrées | temp=0.7 max_tokens=256

> Avez-vous un remède contre les radiations ?
  [Dr. Hélène Vasseur] Il y avait un projet de vaccin avant l'effondrement. Le prototype
  est à Saint-Lazare. Si quelqu'un pouvait le récupérer...

> /state
  ┌─ État des quêtes ─────────────────────────────
  │  ○ quete_vaccin [not_started] → etape_labo
  │  ○ quete_abri [not_started] → etape_bunker_trouve
  └──────────────────────────────────────────────

> /quit
  Au revoir !
```

### Mode simulation (sans clé API)

Si aucune clé API n'est trouvée, le CLI fonctionne en mode simulation : il répond avec l'exemple de la première intention disponible, préfixé `[SIMULÉ]`.

---

## 2. Éditeur web (interface graphique)

### Lancement

```bash
cd GenerateurJson
pip install -r requirements.txt
python app.py
```

Ouvre ensuite `http://localhost:8000` dans un navigateur.

### Fonctionnalités

- **Sidebar** : liste des dimensions, créer/supprimer/importer/exporter
- **Onglet PNJ** : éditer la fiche complète (identité, speech, connaissances, objectifs, intentions)
- **Onglet Quêtes** : créer/modifier des quêtes avec leurs étapes
- **Onglet Fallbacks** : réponses de secours globales
- **Validation** : détection en temps réel des erreurs (IDs manquants, conditions invalides, etc.)

---

## 3. Format JSON

Un fichier de dimension contient :

```jsonc
{
  "meta": { "id": "nuclear", "name": "Nucléaire", "era": "2087" },
  "npcs": [{
    "id": "npc_docteur_helene",
    "name": "Dr. Hélène Vasseur",
    "personality": {
      "tone": "clinique, fatiguée...",
      "backstory": "Médecin survivante de l'effondrement...",
      "emotional_state": "épuisée mais lucide...",
      "speech": {
        "vouvoiement": true,
        "vocatif": "",
        "phrases": "directes, 2-3 phrases",
        "expressions": ["vocabulaire médical"],
        "interdits": ["ne jamais..."]
      },
      "knowledge": ["le bunker médical est fonctionnel..."],
      "goals": ["convaincre le joueur de récupérer le vaccin"],
      "conversation_arc": [
        {"phase": 1, "until_message": 2, "focus": "se présenter"},
        {"phase": 2, "until_message": 4, "focus": "parler du vaccin"},
        {"phase": 3, "until_message": 99, "focus": "répondre aux questions"}
      ]
    },
    "intentions": [{
      "id": "helene_presentation",
      "condition": {"quest_id": null, "quest_status": null, "quest_step": null},
      "trigger": "le joueur se présente ou demande qui elle est",
      "example": "Dr. Vasseur. Médecin de l'unité 7...",
      "action": null
    }],
    "fallbacks": {
      "off_topic": "...",
      "insult": "...",
      "timeout": "...",
      "unknown": "...",
      "default_template": "..."
    }
  }],
  "quests": [{ "id": "quete_vaccin", "title": "...", "steps": [...] }],
  "mini_games": [],
  "items": [],
  "global_fallbacks": { "off_topic": "...", "insult": "...", "timeout": "...", "unknown": "...", "default_template": "..." }
}
```

### Champs importants

| Champ | Description |
|-------|-------------|
| `personality.speech` | Règles strictes de dialogue (vouvoiement, vocatif, longueur, expressions, interdits) |
| `personality.emotional_state` | État émotionnel actuel du PNJ |
| `personality.goals` | Objectifs prioritaires pendant la conversation |
| `personality.conversation_arc` | Phases de conversation guidant le focus de l'IA |
| `intentions[].trigger` | Ce que le joueur dit ou fait pour déclencher cette intention |
| `intentions[].example` | Exemple de réponse (guide pour l'IA, pas du texte fixe) |
| `intentions[].action` | Action de jeu à déclencher (optionnel) : `{"type": "trigger", "id": "..."}` |
| `intentions[].condition` | Filtre par état de quête (`quest_id`, `quest_status`, `quest_step`) |
| `conversation_arc[].until_message` | Numéro de message jusqu'auquel cette phase est active |

### Règles de validation

- Tous les IDs doivent être en `snake_case`
- Chaque intention doit avoir `trigger` ET `example`
- Les fallbacks `off_topic` et `insult` ne doivent pas être vides
- `default_template` doit contenir `{name}` (remplacé par le nom du PNJ)
- Les conditions de quête référencées doivent exister
- Pas d'IDs en double

---

## 4. Conseils

- **Tester d'abord en CLI** avant d'intégrer dans Godot — le mode simulation fonctionne sans clé API
- **L'arc de conversation** est crucial : définir des phases claires aide l'IA à rester cohérente
- **Les interdits dans `speech`** empêchent l'IA de divaguer (ex: "ne connais PAS l'assassin")
- **Les actions** (`intentions[].action`) sont automatiquement forcées après 5 messages si l'IA ne les a pas déclenchées
