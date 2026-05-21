# AGENTS.md — Distortion (timeOnaute)

## Projet
- **Godot 4.6+ standard** — **GDScript uniquement** (ne jamais introduire de fichiers `.cs` / `.csproj`).
- Scène principale : `res://Main.tscn` (définie dans `project.godot`).
- Dimensions de la fenêtre : **1024×682**, mode d'étirement `canvas_items` pour maintenir le ratio 2D pixel art.
- Fichiers ignorés par Git : Répertoire de build/cache `.godot/` et fichier de configuration locale `.env` (contenant `OPENROUTER_API_KEY`).

## Architecture Globale
- **Orchestration des Époques (`Main.gd`)** : `Main.gd` gère le cycle de vie du jeu. Lors d'un changement d'ère via `warp_to_era(zone, spawn_id)`, il appelle la méthode `.stop()` de l'époque courante, puis charge et démarre l'époque cible via `.start(spawn_id)`. Le processus est asynchrone et surveillé via `_process` pour s'assurer que les ressources sont correctement libérées.
- **Conteneurs d'Époques** : Chaque époque (HUB Central, Moyen Âge, Présent, Futur) hérite de `Node2D` et implémente obligatoirement `start(spawn_id: String)` et `stop()`.
- **Time-Aunote (`Personaggio/TimeAunote.tscn`)** : Scène unique du joueur, instanciée dynamiquement dans chaque ère.
  - Le script contient une variable statique `static var disguised: bool` pour suivre si le joueur porte une tenue d'époque.
  - Lorsque `disguised` est activé (Moyen Âge / Présent), le joueur charge des sprites spécifiques suffixés en `_MA` ou `_maintenance` pour se fondre dans la foule.
- **Couches Physiques (2D Collision Layers)** :
  - **Layer 1** : `player` (Joueur)
  - **Layer 2** : `hub_env` (Collisions environnement HUB)
  - **Layer 3** : `moyenage_env` (Collisions Moyen Âge)
  - **Layer 4** : `present_env` (Collisions Présent)
  - **Layer 5** : `futur_env` (Collisions Futur)

## Autoloads (Définis dans `project.godot`)
1. **`DialogueSystem`** (`Scripts/DialogueSystem.gd`) : Noyau logique gérant les fichiers de dimension JSON, les conversations avec l'IA et la progression des quêtes. Charge `dimension_hub.json` dans son `_ready()`.
2. **`DialogueUI`** (`Scripts/DialogueUI.tscn` avec le script `Scripts/DialogueUI.gd`) : Interface utilisateur rétro pour l'affichage des dialogues. Toujours configurée en `retro_mode = true` (police monospace, portrait de PNJ, effet machine à écrire). La version non-rétro est du code mort.
3. **`WarpSystem`** (`Scripts/WarpSystem.gd`) : Système de voyage rapide accessible via la touche **F2** (en production et debug). Intègre des raccourcis pour basculer les déguisements et modifier l'état des badges.

## GDScript Gotchas & Règles de Typage Strict
- **Inférence de Type avec `:=`** : L'utilisation de `:=` requiert des types statiques stricts.
  - `clamp()` retourne un type générique `Variant` sous Godot, ce qui provoque des erreurs de parsing lors d'une assignation stricte `:=`. Utilisez obligatoirement **`clampf()`** ou **`clampi()`** selon le type numérique.
  - `StyleBoxFlat.duplicate()` retourne `Variant`. Utilisez un type explicite : `var h: StyleBoxFlat = s.duplicate()`.
  - L'accès à un tableau non typé (`arr[i]`) retourne également un type `Variant`. Il faut effectuer un transtypage explicite, par exemple : `var p: Dictionary = arr[i]`.
- **Ressources Scènes (`.tscn`)** : Les scripts attachés aux nœuds des scènes doivent comporter une référence explicite `ext_resource type="GDScript"`. Évitez l'usage de chaînes UID fictives générées de manière aléatoire (`uid://...`), privilégiez les chemins relatifs (`path="..."`).
- **Noms de nœuds dans les `.tscn`** : Le code GDScript recherche fréquemment des nœuds par `get_node_or_null()`. Si vous renommez un nœud dans un `.tscn`, vous **devez** mettre à jour toutes les références dans les scripts associés. Exemple : `salleElectricite.tscn` a un Area2D nommé `"event3"` qui est référencé dans `Present.gd`.

---

## Système de Dialogue IA & Gestion d'État

Le système exploite le modèle **`mistralai/mistral-small-3.2-24b-instruct`** via l'API OpenRouter (température `0.7`, `256` tokens maximum) pour générer des réponses hautement contextualisées.

### Format JSON Imposé à l'IA
L'appel API demande obligatoirement un retour au format JSON :
```json
{
  "text": "Le texte parlé par le PNJ",
  "action": null,
  "affinity_change": 0,
  "feeling": "neutral"
}
```
- **`action`** : Un dictionnaire optionnel `{"type": "trigger", "id": "nom_action"}` déclenchant des événements en jeu (ex. `roi_adieu`, `assassin_combat`).
- **`affinity_change` & `feeling`** : Clés spécifiques pour le mini-jeu d'amitié, permettant de faire fluctuer le score de confiance.

### Validation Stricte des Actions
- Lorsqu'une intention PNJ est convertie en action de jeu, celle-ci est validée via la méthode `_validate_action()`. 
- **Règle critique** : L'action émise par l'IA doit correspondre à une intention **activement filtrée** (c'est-à-dire validée par les conditions de quêtes actuelles du joueur). Les actions hors contexte ou obsolètes sont systématiquement rejetées pour éviter la triche ou les sauts narratifs incohérents.
- **Sécurité anti-blocage** : Après **2 messages** (`_message_count >= 2`), si aucune action attendue n'a été émise par l'IA et que les intentions filtrées contiennent une action de type `"trigger"`, le système force son exécution pour garantir la fluidité de la progression.
- **Signal d'extinction** : Le signal `dialogue_ended` est émis **avant** la réinitialisation de l'état de conversation. Les écouteurs peuvent ainsi lire `current_npc_id` pour déclencher des transitions de scènes juste après la fin d'un échange.

### Structure des fichiers de dimension (`dimension_*.json`)
- Placées sous `res://<Ere>/dimension_<ere>.json`, elles définissent l'état narratif complet.
- **`npcs[].intentions[].condition`** : Filtre l'éligibilité des dialogues selon le statut de la quête active (`quest_id`, `quest_status`, `quest_step`).
- **Mécanique de progression dynamique** :
  - `first_message_after` : Surcharge le premier message d'accueil après réussite d'une quête.
  - `knowledge_after_quest` & `goals_after_quest` : Injecte de nouvelles variables de personnalité et de savoir dans l'invite de l'IA une fois une quête accomplie.
- **Historique** : Conserve les 15 derniers messages échangés pour maintenir la continuité contextuelle.

### Mini-Jeu d'Amitié (`MiniJeuAmitie.gd`) & Évaluation Rétrocompatible
- Déclenché en parlant à `npc_femme_parc` dans le parc médiéval.
- Ouvre une interface de chat textuel où l'IA de la femme évalue les inputs utilisateur et retourne un entier `affinity_change` (-20 à +20) pour faire monter le score de "Confiance mutuelle" jusqu'à **100%**.
- **Filet de sécurité (Offline/Fallback)** : Si la requête API à OpenRouter échoue, `DialogueSystem` exécute la fonction interne `_fallback_keyword_evaluation(text)` :
  - Analyse l'input par rapport à des tableaux de mots-clés positifs (`pos_mots` : bonjour, merci, ami, etc.) et négatifs (`neg_mots` : dégage, nul, stupide, etc.).
  - Calcule l'impact d'affinité, détecte les formules de politesse et applique une déduction dynamique de score pour émuler une réponse PNJ robuste sans connexion réseau.

---

## Spécificités Techniques des Époques & Mini-Jeux

### 1. HUB Central (`HUB Central/`)
- **Initialisation (`start()`)** : Sélectionne et joue un fichier audio aléatoire parmi les ressources présentes dans `audio/hub/`.
- **Destruction (`stop()`)** : Coupe impérativement les cycles d'animation et sons d'inactivité du PNJ et du chien (`chienHub.stop_idle()`, `pnjHub.stop_idle()`).
- **Portails** : Les portails temporels ont des identifiants internes distincts de leurs couleurs affichées (Portail gauche = Orange / Interne jaune ; Portail central = Violet / Interne bleue ; Portail droit = Vert / Interne rouge).

### 2. Moyen Âge (Médiéval)
#### Enchaînement des Quêtes :
`quete_enquete_roi` ➔ `quete_evasion` ➔ `quete_deguisement` ➔ `quete_piste_assassin`.
- **Mort du Roi** : L'action de dialogue `roi_adieu` s'exécute à la fin de l'échange avec le roi. Elle modifie la quête vers l'état de fuite, active les zones de détection de la prison (`ZonePorte`) et enferme le joueur.
- **Nettoyage du magasin (`magasin_moyen_age.gd`)** : La méthode `_show_disguise_message()` utilise un Label géré par un tween de 4.5 secondes. Si l'ère est arrêtée en plein milieu (passage en `PROCESS_MODE_DISABLED`), le tween se fige et corrompt la mémoire. Pour éviter cela, il est impératif d'appeler `_disguise_label.queue_free()` dans la méthode `stop()`.
- **Auberge & Écoute aux Tables (`MiniJeuEcouteTables.gd`)** :
  - Le joueur doit maintenir `E` pour élever une barre d'écoute dans une zone d'oscillation verte fluctuante et relâcher pour la descendre.
  - Comporte 3 tables à espionner. L'échec d'une seule jauge de suspicion remet à zéro l'intégralité du mini-jeu.
- **Arène de Combat Temps Réel (`MoyenAge/campement.gd`)** :
  - Déclenché en confrontant l'assassin dans la forêt. Warp instantané vers l'arène de combat en premier plan.
  - **Santé** : Joueur = 5 HP (affichés via `ProgressBar`), Assassin = 100 HP.
  - **Inputs & Cooldowns** : Touches `A` / `Q` maintenues pour parer avec le bouclier (bloque l'attaque et étourdit l'assassin si paré pendant son assaut). Touche `E` ou `ui_accept` pour sabrer (cooldown strict de 0.3s).
  - **États de l'Assassin (Postures)** : 
    - `"idle"` : Vulnérable aux assauts.
    - `"defense"` : Parera toute attaque du joueur, lui infligeant un étourdissement (`is_player_stunned`) de 3.0 secondes.
	- `"attack"` : Charge un coup dévastateur pendant 1.0s (avertissement via flash d'écran rouge). Le joueur doit parer sous peine de perdre 1 HP.
  - **Mode Rage (< 50 HP)** : L'assassin accélère son rythme de combat. Le changement de posture s'effectue toutes les 1.2 à 2.0s (au lieu de 2.0 à 3.0s), la posture défensive a 55% de chance de s'activer, et les attaques se chargent en **0.5 seconde** au lieu d'une seconde complète.
  - **Défaite & Résilience Temporelle** : Si le joueur tombe à 0 HP, la distorsion le sauve. Un écran noir affiche le message *"vous êtes sauvés par la distorsion..."* pendant 3 secondes, puis le joueur est replacé à l'entrée de la forêt avec tous ses points de vie. L'objectif est réinitialisé sur *"Trouver l'assassin dans la forêt"*.

### 3. Présent (Nuclear - 2026)
#### Enchaînement des Quêtes :
`quete_acces_centrale` ➔ `quete_preparation`.
- **Infiltration** : L'accès à la centrale est défendu par l'Agent Moreau (`npc_securite_present`). S'approcher sans badge redirige le joueur vers la zone de Parking.
- **Mini-jeu d'infiltration / 1, 2, 3 Soleil (`MiniJeuSoleil.gd`)** :
  - Le joueur doit dérober le badge d'un technicien en se déplaçant horizontalement vers la gauche via les actions d'input `marche_gauche/droite/haut/bas` (ZQSD / WASD / Flèches).
  - **Machine à États (Phases)** : 
	- `Phase.LOOKING_AWAY` : Le joueur peut avancer en toute sécurité.
	- `Phase.WARNING` : Avertissement de 0.3s. Le joueur doit stopper tout mouvement.
	- `Phase.LOOKING_AT` : Le technicien observe. Si le joueur bouge après la période de grâce de 0.1s, il subit une pénalité.
  - **Pénalité (Strike)** : Le joueur subit un recul (Knockback) de **200 pixels** vers la droite et un étourdissement de 1.2s. Au bout de 3 strikes, le jeu se solde par un échec.
  - **Victoire** : Atteindre une distance de rapprochement inférieure à **55 pixels** du technicien.
- **Salle des Machines & Salle Électrique (Présent)** :
  - Après le mini-jeu tuyau (`MiniJeuTuyau`), un court-circuit se déclenche (overlay d'obscurité pulsant rouge). Le joueur doit parler à Sophie (`npc_secretaire_present_courtcircuit`) qui l'engueule et l'envoie à la salle électrique.
  - **Mini-jeu de Câblage (`MiniJeuCablage.gd`)** : Remplace l'ancien `MiniJeuDisjoncteur`. Le joueur connecte des sources, portes logiques (AND/OR/NOT), et cibles via des câbles avec un budget limité. 3 niveaux progressifs avec câbles pré-posés et sources en panne au niveau 3. Lors du lancement du mini-jeu, le voile d'obscurité est retiré temporairement (le joueur voit l'armoire) ; si échec/ESC, le voile revient ; si succès, le voile est supprimé définitivement.
  - **Accès conditionnel** : La zone `event3` de la salle électrique n'est interactive que si `_salle_machine_done == true` (court-circuit déclenché). Avant cela, un message "L'armoire électrique fonctionne normalement" s'affiche.
- **Voile d'obscurité (darkness overlay)** : Géré par `_show_darkness_overlay()` / `_remove_darkness_overlay()` dans `Present.gd`. CanvasLayer layer 200, pulse rouge entre `Color(0.35, 0.02, 0.02, 0.55)` et `Color(0.08, 0.01, 0.01, 0.65)`. Ne jamais oublier de retirer le voile dans la callback de succès du mini-jeu électrique.
- **Bug pattern — Prompts persistants** : Après un mini-jeu, `time_aunote.show()` déclenche le signal `body_entered` sur les Area2D de la zone, ce qui réaffiche les prompts d'interaction. Toujours ajouter `not _salle_machine_done` dans les checks `_on_*_entered` et cacher le prompt dans la callback `_on_*_minigame_done`.

### 4. Futur (Technologique)
#### Enchaînement narratif :
Exploration de la base de la résistance ➔ Dialogue avec Vukovi et Koiai au sous-sol ➔ Mini-jeu Voiture ➔ Supérette (Laser) ➔ Métro ➔ Cinématique de la tour ➔ Boss Final Alfredo.
- **Conduite & Esquive de la Voiture (`route.gd` via `MiniJeuVoiture.gd`)** :
  - Trajet de **40 secondes** continu sur une autoroute à 3 voies (basé sur des nœuds de markers pour les positions Y).
  - Déplacements de la voiture de haut en bas via les actions `marche_haut` / `marche_bas` (touches Z/S ou flèches).
  - Les obstacles se déplacent vers la gauche à une vitesse phénoménale de **1200 px/s**.
  - **Règle stricte de collision** : Tout impact avec un débris ou obstacle réinitialise instantanément le minuteur à **40.0 secondes**. Le joueur doit impérativement réaliser un sans-faute continu pour valider la course.
- **Survie aux Lasers de la Supérette (`MiniJeuTourelles.gd`)** :
  - Jeu d'évitement de lasers de tourelles de défense pendant **30 secondes**.
  - Les tourelles génèrent des nœuds `CharacterBody2D` représentant des orbes énergétiques préchargés (`OrbeTourelle.gd`). 
  - Ces orbes se déplacent selon des trajectoires angulaires configurées (angles de tir distincts pour Tourelle 1 et Tourelle 2) à une vitesse de **400 px/s**.
  - Détecte les collisions via le masque de collision `17` (joueur). Le moindre impact entraîne une défaite immédiate et réinitialise l'épreuve.
- **Cinématique & Tour** : La transition vers la tour d'Alfredo déclenche la lecture plein écran de la vidéo d'introduction `res://art/Futur/cinematique_futur.ogv`.
- **Combat de Boss RPG au Tour par Tour (`Scripts/CombatBossFutur.gd`)** :
  - **Propriétés & Statistiques** :
	- Joueur : 100 HP, 20 ATK, 10 DEF.
	- Alfredo Sinko Nochez : 150 HP, 15 ATK, 5 DEF.
  - **Menu d'actions** :
    - **Attaquer** : Inflige des dégâts basés sur `player_atk - (boss_def / 2) + randi() % 7 - 3` (minimum 5).
    - **Parer** : Double la valeur de défense du joueur (`player_def * 2`) pour le tour en cours.
    - **Soin** : Restaure **35 HP**. Utilisable une seule et unique fois par combat (le bouton passe ensuite en état désactivé `Soin (épuisé)`).
  - **Intelligence Artificielle du Boss (Roll random sur 10)** :
    - `roll < 7` (70% de chance) : Alfredo assène une attaque puissante. Dégâts subis : `boss_atk + boss_atk_buff - (effective_def / 2) + randi() % 6 - 2` (minimum 5).
    - `roll < 9` (20% de chance) : Alfredo se concentre et accumule de la puissance physique (`boss_atk_buff += 3`).
    - `roll == 9` (10% de chance) : Alfredo ricane et nargue le joueur ("Vous croyez pouvoir me vaincre, misérable créature ?").
  - **Phase 2 — Les Intankables (Alliés)** :
    - Quand le boss P1 (Alfredo) tombe à 0 PV, transition vers boss P2 (150 PV, ATK+7). Les Intankables (sprite `cheffe_combat`) deviennent **alliés** du joueur.
    - Le joueur est déplacé plus haut (`_player_original_y - 200`) pour faire de la place.
    - **Barre de vie fusionnée** : `intankables_hp = player_hp + intankables_hp` (max 300 PV). La barre du joueur disparaît, remplacée par la barre "Voyageur + Intankables" au même emplacement (haut-gauche).
	- **Ciblage** : L'attaque du joueur cible directement le boss P2 (plus d'attaque sur Intankables).
    - **Dégâts du boss** : En phase 2, le boss endommage la barre combinée (`intankables_hp`). Défaite si elle atteint 0.
    - **Soin** : Le soin du joueur restaure la barre combinée.
    - **Victoire** : Le combat est gagné lorsque le boss P2 tombe à 0 PV.
  - **Polissage Visuel UI** :
	- Barres de HP dynamiques dont la couleur s'adapte selon le ratio restant (Vert > 50%, Jaune > 25%, Rouge sinon).
	- Jauges de dégâts retardées (`boss_hp_dmg` / `player_hp_dmg`) matérialisées par un rectangle rouge s'estompant via un tween d'interpolation mathématique en sinus (`TRANS_SINE`, `EASE_IN`) d'une durée de 0.6s.
	- Les sprites des personnages flottent doucement dans les airs via des tweens d'oscillation verticale de 8 pixels configurés en boucle infinie (`set_loops(-1)`).

---

## Générateur JSON (`GenerateurJson/`)

- C'est un micro-service écrit en Python permettant d'éditer et de valider les structures d'intentions des PNJ de manière dynamique.
- **Accès local** : `cd GenerateurJson && pip install -r requirements.txt && python app.py` (démarre le serveur web sur le port 8000).
- **Validation manuelle** : Enregistre le JSON finalisé dans le dossier `dimensions/` tout en injectant une copie dans le dossier d'époque Godot correspondant pour assurer la synchronisation en temps réel.
- **Validation en ligne de commande** :
  ```bash
  python3 distortion_dialogue.py dimensions/dimension_nuclear.json
  ```

## Commandes Importantes

- **Exécution locale** : Ouvrir `project.godot` dans l'éditeur de l'application Godot 4.6+ et appuyer sur **F5** pour exécuter le jeu.
- **Vérification syntaxique de JSON** :
  ```bash
  python3 -c "import json; json.load(open('HUB Central/dimension_hub.json'))"
  python3 -c "import json; json.load(open('MoyenAge/dimension_moyenage.json'))"
  python3 -c "import json; json.load(open('Present/dimension_present.json'))"
  python3 -c "import json; json.load(open('Futur/dimension_futur.json'))"
  ```
