# Design : Système de dialogue IA libre (remplacement du dialogue_bank)

**Date** : 2026-05-11
**Statut** : Approuvé

## Objectif

Remplacer l'actuel système d'arbre de dialogue (`dialogue_bank` où l'IA choisit un `reply_id`
parmi des répliques pré-écrites) par un système où l'IA génère du texte libre à partir du
contexte JSON du PNJ, et déclenche des actions de jeu via des signaux structurés.

## Résumé des décisions

| Aspect | Actuel | Nouveau |
|--------|--------|---------|
| Réponse IA | `{"id": "reply_id"}` | `{"text": "...", "action": {...}}` |
| Texte PNJ | Pré-écrit dans le JSON | Généré par l'IA |
| JSON PNJ | `dialogue_bank` (id→text) | `intentions` (trigger + example + action) |
| Contexte PNJ | `personality.tone + prompt_context` | `personality.tone + backstory + knowledge + style` |
| Signal | `reply_resolved(reply_id)` | `action_triggered(action: Dictionary)` |
| Historique | Aucun | 10-15 derniers messages |
| Modèle | ministral-3b, temp 0.1, 128 tokens | ministral-3b, temp 0.7, 256 tokens |
| Fallbacks | Conservés | Conservés (texte pré-écrit si API down) |
| Validation | Aucune | Actions validées contre `intentions[].action` |

## Architecture

```
Player tape un message → DialogueUI._send_message()
  → DialogueSystem.send_message(text)
    → assemble le prompt IA (fiche PNJ + intentions + historique + msg joueur)
    → POST OpenRouter
    → réponse : {"text": "...", "action": {...}}
    → validation de l'action (existe dans intentions du PNJ)
    → émet dialogue_response(npc_name, text)     → UI affiche bulle + chat
    → émet action_triggered(action) si valide    → scène réagit (trigger, quête, etc.)
```

## Structure JSON (nouveau format)

### PNJ

```json
{
  "id": "npc_roi_moyenage",
  "name": "Le Roi du Château",
  "personality": {
    "tone": "noble, solennel, mourant...",
    "backstory": "Souverain médiéval usé par les guerres...",
    "knowledge": [
      "il est en train de mourir",
      "ignore l'identité de son assassin"
    ],
    "style": "Phrases courtes, respiration difficile..."
  },
  "intentions": [
    {
      "id": "roi_accueil",
      "trigger": "le joueur salue ou se présente",
      "example": "Approche, voyageur...",
      "action": null
    },
    {
      "id": "roi_adieu",
      "trigger": "le joueur dit au revoir ou part",
      "example": "GARDES ! Venez m'aider...",
      "action": {
        "type": "trigger",
        "id": "roi_adieu",
        "description": "Le roi appelle ses gardes dans un dernier souffle."
      }
    }
  ],
  "fallbacks": {
    "off_topic": "...",
    "insult": "...",
    "timeout": "...",
    "unknown": "...",
    "default_template": "..."
  }
}
```

### Champ `action`

```json
{
  "type": "trigger | quest_update | give_item",
  "id": "identifiant_unique",
  "description": "Quand et pourquoi cette action se déclenche (lu par l'IA)"
}
```

## Prompt IA

Assemblé dynamiquement à chaque `send_message()` :

```
[SYSTÈME]
Tu incarnes un PNJ. Voici ta fiche :
NOM : ...
TON : ...
HISTOIRE : ...
CONNAISSANCES : [...]
STYLE : ...

Intentions disponibles :
- [id] trigger : "example de réponse" → action: null | {type, id}

RÈGLES :
- Réponds UNIQUEMENT en JSON : {"text": "...", "action": null | {...}}
- Ne parle QUE de ce que le PNJ connaît.
- N'invente rien. Si hors-sujet, reste dans le personnage.
- Maximum 3-4 phrases.
- Pas d'astérisques ni de narration.

[CONVERSATION]
Historique :
- Joueur : "..."
- PNJ : "..."
- Joueur : "message actuel"
```

## Historique de conversation

- Stocké dans `conversation_history: Array[Dictionary]` (paires `{role, text}`)
- Envoyé dans le prompt : les 10-15 derniers messages
- Vidé à chaque `stop_dialogue()`
- Pas de résumé automatique (les conversations sont courtes, 5-10 échanges)

## Validation des actions

```gdscript
func _validate_action(action: Dictionary) -> Dictionary:
    # 1. Structure : doit avoir type + id
    # 2. Existence : le couple (type, id) doit exister dans
    #    current_npc.intentions[].action
    # 3. Si invalide → logué et ignoré, le texte est affiché
```

Les conditions de quête (`quest_status`, `quest_step`) ne sont PAS vérifiées
dans la validation — les intentions sont déjà filtrées avant d'être envoyées
dans le prompt via `filter_dialogue_bank()` (renommé `filter_intentions()`).

## Signaux

| Signal | Émetteur | Destinataire | Usage |
|--------|----------|-------------|-------|
| `dialogue_started(npc_id, npc_name)` | DialogueSystem | DialogueUI | Affiche le panel |
| `dialogue_response(npc_name, text)` | DialogueSystem | DialogueUI | Affiche bulle + chat |
| `action_triggered(action: Dictionary)` | DialogueSystem | Scènes (MoyenAge, etc.) | Déclenche events jeu |
| `dialogue_ended` | DialogueSystem | DialogueUI | Ferme le panel |
| `quest_updated(quest_id, status, step)` | DialogueSystem | — | Progression quête |

Le signal `reply_resolved(reply_id: String)` est **supprimé** et remplacé par
`action_triggered(action: Dictionary)`.

## Migration des scènes existantes

### MoyenAge.gd

```gdscript
# Avant
DialogueSystem.reply_resolved.connect(_on_reply_resolved)
func _on_reply_resolved(reply_id: String):
    if reply_id == "roi_adieu": ...

# Après
DialogueSystem.action_triggered.connect(_on_action_triggered)
func _on_action_triggered(action: Dictionary):
    if action.type == "trigger" and action.id == "roi_adieu": ...
```

### Fichiers impactés

- `Scripts/DialogueSystem.gd` — refonte majeure
- `Scripts/DialogueUI.gd` — inchangé (reçoit toujours `dialogue_response(text)`)
- `MoyenAge/MoyenAge.gd` — changer la connexion de signal
- `HUB Central/TimeAunoteDansHubCentral.gd` — inchangé (appelle `start_dialogue/stop_dialogue`)
- `HUB Central/dimension_hub.json` — nouvelle structure
- `MoyenAge/dimension_moyenage.json` — nouvelle structure
- `MoyenAge/pnj_roi.gd` — inchangé
- `HUB Central/pnj_hub.gd` — inchangé

## Anti-hallucination

1. **Prompt strict** : règles explicites sur ce que le PNJ peut dire
2. **Validation code** : action ignorée si absente des intentions
3. **Intentions comme garde-fou** : l'IA reçoit une liste finie de sujets possibles
4. **Fallbacks** : si API down/timeout → texte pré-écrit du JSON

## Non-fonctionnel

- Modèle : `mistralai/ministral-3b-2512` (gratuit via OpenRouter)
- Température : 0.7
- Max tokens : 256
- Timeout : 15s (inchangé)
- Coût estimé par message : ~0$ (gratuit), ~1500 tokens consommés
