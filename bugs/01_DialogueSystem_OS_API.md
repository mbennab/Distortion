# 🔴 CRITIQUE — `OS.get_environment()` → API Godot 3 supprimée

**Fichier :** `Scripts/DialogueSystem.gd:47`
**Sévérité :** CRITIQUE (dialogue IA complètement mort, autoload brisé)

## Le Bug

```gdscript
# Ligne 47 — API Godot 3.5, SUPPRIMÉE dans Godot 4+
api_key = OS.get_environment("OPENROUTER_API_KEY")
```

## Pourquoi c'est un crash

`OS.get_environment()` a été **renommé** en `OS.getenv()` dans Godot 4. Cette méthode n'existe plus.

Au runtime, l'appel provoque :
```
Nonexistent function 'get_environment' in base 'OS'
```

Ce crash stoppe **net** l'exécution de `_ready()` dans DialogueSystem. Les lignes suivantes ne s'exécutent JAMAIS :
- Connexion du signal `HTTPRequest.request_completed` (l.55)
- Chargement du fichier `dimension_hub.json` (l.59)
- Initialisation de `_npc_intentions` (l.70)

## Impact

- **Toute la gestion des dialogues IA est morte** — `DialogueSystem` est un Autoload, donc son `_ready()` s'exécute au démarrage. Si Godot 4 ne lance pas d'erreur fatale pour une méthode manquante (certaines versions continuent), `api_key` reste `""` et tous les appels API OpenRouter échouent.
- `_npc_intentions` n'est jamais initialisé → dialogues silencieux partout.
- Les fichiers `dimension_*.json` ne sont pas chargés → quêtes jamais initialisées.
- **Dans le pire des cas, le jeu plante au lancement** (selon la version Godot).

## Correction

```gdscript
api_key = OS.getenv("OPENROUTER_API_KEY")
```

## Notes

Même chose pour `OS.get_environment()` ailleurs dans le projet :
- Vérifier si d'autres appels à `OS.get_environment()` existent dans `Scripts/`

## Prévention

Ne pas utiliser d'API Godot 3.x dans un projet Godot 4.x. Les méthodes supprimées incluent :
- `OS.get_environment()` → `OS.getenv()`
- `OS.set_environment()` → `OS.setenv()`
- `OS.unset_environment()` → `OS.unsetenv()`
- `connect("string", obj, "method")` → `signal.connect(callable)`
- `yield()` → `await`
- `parse_json()` → `JSON.parse_string()`
- `to_json()` → `JSON.stringify()`
