# Tutoriel — Générateur JSON pour Distortion

Ce dossier contient les outils pour créer, éditer et tester les fichiers de dialogue (`dimension_*.json`) du jeu **timeOnaute (Distortion)**.

---

## Démarrage rapide

```bash
cd GenerateurJson
pip install -r requirements.txt
python app.py                     # → http://localhost:8000
# Onglet AI Studio pour créer avec l'IA, ou éditeur pour du manuel
```

La clé API est lue depuis `../.env` (racine du projet). Pas d'export nécessaire.

---

## 1. AI Studio (recommandé) — `http://localhost:8000/ai-builder`

L'outil principal pour créer et tester des dimensions. Tout se fait en discutant avec l'IA.

### 🧠 Créer — Brainstorm mode

Décrivez votre jeu librement, l'IA structure tout.

**4 phases automatiques :**
1. **Pitch** — balancez votre concept, l'IA extrait : dimension, PNJs, quêtes
2. **Détail PNJ** — l'IA propose fiche complète pour chaque PNJ (speech, connaissances, objectifs, intentions, arc), vous validez/ajustez
3. **Détail Quêtes** — étapes, PNJs impliqués, dépendances
4. **Finalisation** — récap, ajustements, sauvegarde

**Exemple :**
```
Vous : "Jeu medieval post-apo. Un roi se fait poignarder. Le joueur parle au roi
       mourant puis est accusé. Prison avec crochetage pour s'échapper."

IA   : "✅ Compris. Voici ce que j'ai extrait :
       → Dimension : moyen_age / Moyen Âge / Médiévale
       → PNJ : Le Roi du Chateau (mourant, action trigger roi_adieu)
       → Quête : Échapper de la prison (crochetage)
       Je détaille le roi ?"

Vous : "oui"
IA   : "Le Roi du Chateau [npc_roi_moyenage]
       Tone : noble, solennel, mourant ?
       Speech : vouvoiement, vocatif voyageur, phrases courtes et hachées ?
       Connaissances : il meurt, ignore l'assassin, a vu des lueurs jaunes ?
       Objectifs : trouver de l'aide, appeler ses gardes avant de mourir
       Intentions : 5 proposées...
       → Confirme ou ajuste."

Vous : "parfait"
IA   : "Quête : La mort du Roi. 2 étapes : parler au roi → il appelle les gardes.
       OK ?"

Vous : "ajoute le crochetage"
IA   : "✅ Ajouté : mini_jeu_crochetage lié a la sortie de prison. Sauvegarder ?"

Vous : "oui"
IA   : "✅ Sauvegardé : dimension_moyen_age.json"
```

L'IA est proactive : elle propose, vous validez. Répondez "ok", "oui", "parfait", ou précisez ce que vous voulez changer.

### 📝 Modifier — Import et édition

Importez un JSON existant (fichier ou depuis le serveur), l'IA vous aide à le modifier.

- "Ajoute un PNJ marchand" → l'IA crée le squelette et demande les détails
- "Change le ton du roi" → l'IA ajuste et confirme
- "Ajoute une quête secondaire" → l'IA propose les étapes

### 🧪 Tester — Dialogue direct

Sélectionnez un PNJ et parlez-lui comme dans le jeu. L'IA incarne le personnage avec son speech, ses connaissances et son arc de conversation.

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

### Exemple de session

```
╔══ Distortion Dialogue Tester v3 ══╗
║ Nucléaire (2087)
║ ✓ clé chargée  |  temp=0.7
╚══════════════════════════╝

  PNJ disponibles :
    1. Dr. Hélène Vasseur [npc_docteur_helene]

> /npc npc_docteur_helene

  [Dr. Hélène Vasseur] Que voulez-vous me dire ?

> Bonjour, qui êtes vous ?

  [Dr. Hélène Vasseur] Dr. Vasseur. Médecin de l'unité 7...
  [msg #1 | 7 int | live]
```

### Mode simulation

Sans clé API, le CLI fonctionne en simulation : réponses préfixées `[SIMULÉ]`.

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
    "steps": [
      {"id": "parler_au_roi", "description": "Parler au roi"},
      {"id": "roi_appelle_gardes", "description": "Le roi appelle les gardes"}
    ]
  }],
  "global_fallbacks": {"off_topic": "...", "insult": "...", "timeout": "...", "unknown": "...", "default_template": "..."}
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
{"condition": null}                                                                     // toujours
{"condition": {"quest_id": "q", "quest_status": "not_started"}}                        // quête pas commencée
{"condition": {"quest_id": "q", "quest_step": "etape_labo"}}                           // étape spécifique
{"condition": {"quest_id": "q", "quest_status": "done"}}                               // quête finie
```

### Règles d'or
1. **`interdits`** bloquent l'IA : soyez précis ("ne connais PAS l'assassin")
2. **`conversation_arc`** donne une direction. Sans arc, l'IA reste cohérente mais sans but
3. **`goals`** orientent chaque réponse. L'IA les lit en priorité
4. **Actions forcées à 5 msg** si non déclenchées avant — parfait pour les cinématiques
5. **Tester dans AI Studio ou CLI** avant Godot. Le mode simulation marche sans clé
6. **`example` = guide**, pas texte fixe. L'IA reformule librement

---

## 6. Dépannage

| Problème | Solution |
|----------|----------|
| "OPENROUTER_API_KEY non définie" | `.env` à la racine avec `OPENROUTER_API_KEY=sk-...` |
| L'IA répond du texte bizarre | Vérifier `interdits` et `knowledge` — l'IA invente si mal cadrée |
| L'action ne se déclenche pas | `action.type` et `action.id` doivent correspondre aux `intentions[].action` |
| 404 sur /ai-builder | Relancer `python app.py` |
| Erreur de validation | Ouvrir l'éditeur → l'onglet validation liste les erreurs |
| JSON invalide | `python3 -c "import json; json.load(open('dimensions/dimension_X.json'))"` |
