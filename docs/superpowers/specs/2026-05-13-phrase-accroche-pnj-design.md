# Design : Phrase d'accroche PNJ (guidage joueur)

**Date** : 2026-05-13
**Statut** : Approuvé

## Objectif

Quand le joueur parle à un PNJ, le PNJ commence automatiquement la conversation par une
phrase d'accroche pertinente qui guide le joueur sur ce qu'il doit faire. La première
conversation utilise un message statique défini dans le JSON ; les conversations suivantes
sont gérées dynamiquement par l'IA via l'historique.

## Résumé des décisions

| Aspect | Décision |
|--------|----------|
| Source du message | Champs `first_message` optionnel dans chaque NPC du JSON dimension |
| 1ère conversation | Message statique du JSON, affiché en typewriter dès l'ouverture du dialogue |
| Conversations suivantes | L'IA génère une phrase d'accroche basée sur l'historique des échanges |
| Déclencheur | `DialogueSystem.start_dialogue()` lit `first_message` et émet un signal |
| UI | Réutilise le système typewriter existant, input désactivé pendant la lecture |
| Tracking | Dictionnaire session-only `_spoken_to: Dictionary` (npc_id → true) |
| Prompt IA | Instruction ajoutée pour les retours de conversation |
| Rétrocompatibilité | `first_message` optionnel — absence = pas d'accroche |

## Architecture

### Flux général

```
start_dialogue(npc_id)
  ├─ npc_id dans _spoken_to ?
  │   ├─ NON → first_message existe et non vide ?
  │   │   ├─ OUI → _current_first_message = first_message
  │   │   │         _spoken_to[npc_id] = true
  │   │   └─ NON → _current_first_message = ""
  │   └─ OUI → _current_first_message = ""
  │             (prompt IA inclura instruction rappel)
  └─ emit dialogue_started(npc_id, npc_name)
        │
        ▼
DialogueUI._on_dialogue_started()
  → get_first_message() → si non vide →
      typewriter accroche → input activé
  → sinon → input activé directement
```

### 1. Modifications DialogueSystem.gd

**Nouveaux champs :**
```gdscript
var _spoken_to: Dictionary = {}        # clé = npc_id, valeur = true
var _current_first_message: String = ""
```

**Méthode `start_dialogue()` modifiée :**
- Après avoir chargé le NPC depuis le JSON
- Si `npc.has("first_message")` ET `npc.first_message` non vide ET `!_spoken_to.has(npc.id)` :
  - `_current_first_message = npc.first_message`
  - `_spoken_to[npc.id] = true`
- Sinon : `_current_first_message = ""`
- Puis émet `dialogue_started` comme avant

**Nouvelle méthode `get_first_message() -> String`:**
```gdscript
func get_first_message() -> String:
    var msg = _current_first_message
    _current_first_message = ""
    return msg
```

**Méthode `stop_dialogue()` modifiée :**
- `_current_first_message = ""`

**System prompt augmenté (dans `_build_system_prompt`) :**
Quand `_spoken_to.has(npc_id)` est vrai, ajouter en fin de prompt :

> NOTE : Le joueur te reparle après une conversation précédente.
> Commence par une phrase d'accroche naturelle et courte, en rapport avec
> vos échanges précédents et ce que tu attends de lui.
> Ne répète PAS les sujets déjà abordés.

### 2. Modifications DialogueUI.gd

**Nouvelle méthode `_display_accroche(message: String)`:**
- Désactiver `retro_input_line.editable = false`
- Vider `retro_message_label.text`
- Lancer `_start_typewriter(message)` avec connexion à `_on_accroche_finished()`

**Nouvelle méthode `_on_accroche_finished()`:**
- Activer `retro_input_line.editable = true`
- `retro_input_line.grab_focus()`

**Méthode `_on_dialogue_started()` modifiée :**
```gdscript
func _on_dialogue_started(npc_id: String, npc_name: String) -> void:
    # ... initialisation panel existante ...
    var accroche: String = DialogueSystem.get_first_message()
    if accroche != "":
        _display_accroche(accroche)
    else:
        retro_input_line.editable = true
        retro_input_line.grab_focus()
```

### 3. Modifications dimension JSON

Ajout du champ `first_message` (optionnel, string) dans chaque NPC :

```json
{
  "id": "npc_roi_moyenage",
  "name": "Le Roi du Château",
  "first_message": "Approche, voyageur… Je suis poignardé, le royaume se meurt. Trouve mes gardes… vite…",
  "personality": { ... }
}
```

Valeurs pour chaque PNJ :

| PNJ | first_message |
|-----|---------------|
| Gardien du Nexus (HUB) | "Bienvenue voyageur. Trois portails s'offrent à toi : le passé, le présent, le futur. Choisis wisely, mais sache que chaque choix a ses conséquences." |
| Roi (MoyenAge) | "Approche, étranger… Je suis poignardé, le royaume se meurt. Trouve mes gardes avant qu'il ne soit trop tard…" |
| Marchand (MoyenAge) | "Ah, un nouveau client ! J'ai des vêtements de qualité, mais il faudra les mériter. Dis-moi si tu es prêt à marchander." |
| Vukovi (Futur) | "T'as intérêt à avoir une bonne raison d'être ici. Le sous-sol est interdit sans autorisation." |
| Cheffe (Futur) | "Enfin quelqu'un de nouveau. On a besoin de mains ici. Renseigne-toi auprès des autres, vois ce qui peut t'être utile." |
| Mécano (Futur) | "Salut ! Si tu cherches du boulot, la Cheffe décide. Moi je répare, c'est tout." |
| Koiai (Futur) | "…Tu me vois ? D'habitude les gens traversent sans s'arrêter. Qu'est-ce que tu veux ?" |
| Punk (Futur) | "Hé toi. Dégaine pas un mauvais plan. Ici on survit, on fait pas de politique." |

## Composants système

### DialogueSystem
- **Nouveau champ** : `_spoken_to: Dictionary` (npc_id → true)
- **Nouveau champ** : `_current_first_message: String`
- **Méthode modifiée** : `start_dialogue(npc_id)` — lit `first_message` du JSON si nouvelle conversation
- **Nouvelle méthode** : `get_first_message() -> String` — consume `_current_first_message`
- **Méthode modifiée** : `_build_system_prompt()` — ajoute l'instruction de rappel si déjà parlé
- **Méthode modifiée** : `stop_dialogue()` — reset `_current_first_message`

### DialogueUI
- **Nouvelle méthode** : `_display_accroche(message)` — typewriter de l'accroche
- **Nouvelle méthode** : `_on_accroche_finished()` — active input après typewriter
- **Méthode modifiée** : `_on_dialogue_started()` — vérifie `get_first_message()` et affiche si non vide

### Dimension JSON
- **Nouveau champ optionnel** : `first_message` (string) dans chaque objet NPC

## Cas particuliers

| Situation | Comportement |
|-----------|-------------|
| Pas de `first_message` dans le JSON | Pas d'accroche, input activé directement |
| `first_message` vide | Pas d'accroche, input activé directement |
| Plusieurs dialogues avec le même PNJ | Première fois → accroche. Suivantes → phrase IA |
| Typewriter skipé (Enter) | Input activé immédiatement |
| PNJ avec `portrait_path` manquant | L'accroche s'affiche normalement avec le portrait silhouette |
| Dialogue fermé pendant l'accroche | `stop_dialogue()` reset tout, pas de corruption |
| API indisponible (conversation suivante) | Fallback normal du système, pas de blocage |
| Session fermée / restart | `_spoken_to` vidé → prochain dialogue = première fois |
