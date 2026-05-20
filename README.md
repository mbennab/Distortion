# timeOnaute (Distortion)

timeOnaute (Distortion) est un jeu d'aventure narratif 2D développé avec **Godot 4.6+ standard** (GDScript uniquement).  
Le joueur y incarne un **Time-Aunote**, un voyageur temporel chargé de traverser différentes époques à travers des portails dimensionnels pour résoudre des distorsions qui menacent de déchirer le continuum espace-temps.

---

## Pour commencer

### Prérequis
- Télécharger et installer [Godot 4.6+](https://godotengine.org/) (choisir la version **standard**, la version .NET / C# n'est pas supportée).
- Un accès internet et une clé d'API (optionnel, requis pour l'évaluation dynamique de l'IA de dialogue via OpenRouter).

### Installation
1. Cloner le dépôt de développement :
   ```bash
   git clone https://github.com/mbennab/Distortion
   ```
2. Créer un fichier nommé `.env` à la racine du projet pour configurer votre clé d'API OpenRouter (requise pour le système de dialogue intelligent) :
   ```env
   OPENROUTER_API_KEY=votre_cle_api_ici
   ```
3. Ouvrir Godot Engine ➔ Importer ➔ Sélectionner le fichier `project.godot` à la racine du projet.
4. Lancer le projet en appuyant sur la touche **F5** ou sur le bouton de lecture ▶️ de l'éditeur.

---

## Contrôles Généraux et Spécifiques

Le jeu prend en compte les configurations de claviers AZERTY et QWERTY grâce à un mappage double défini dans les paramètres de Godot.

### Contrôles de Navigation Générale
| Action | Touches (Clavier) | Rôle |
|--------|-------------------|------|
| **Déplacement** | `ZQSD` / `WASD` / Flèches directionnelles | Déplacer le personnage dans 4 directions |
| **Interagir / Parler** | `E` | Lancer une conversation avec un PNJ ou activer un objet interactif |
| **Passer / Fermer** | `Échap` | Fermer une interface de dialogue ou quitter un menu |
| **Voyage Rapide** | `F2` | Ouvrir le panneau d'administration de WarpSystem (disponible à tout moment) |

### Commandes Spécifiques aux Mini-Jeux et Combats
- **Parade Médiévale (Combat Réel)** : Maintenir la touche `A` ou `Q` enfoncée pour lever le bouclier et parer les attaques de l'assassin.
- **Attaque Sabre (Combat Réel)** : Appuyer sur `E` ou sur la touche Entrée pour asséner un coup d'épée.
- **Écoute aux Tables (Taverne)** : Maintenir la touche `E` enfoncée pour faire monter la jauge d'écoute, relâcher la touche `E` pour la faire descendre.
- **Conduite Automobile (Futur)** : Appuyer sur `Z` ou `marche_haut` (W / flèche haut) pour changer de voie vers le haut, et `S` ou `marche_bas` (S / flèche bas) pour changer de voie vers le bas.

---

## Architecture des Niveaux et Époques

Le jeu s'articule autour de quatre grandes zones temporelles :

```
Main.tscn (Conteneur principal & Chef d'orchestre)
├── HUB Central ➔ Le Nexus hors du temps. Point de transit contenant 3 portails colorés.
├── Moyen Âge ➔ Ère médiévale féodale. Château fort, village historique, taverne, parc et forêt.
├── Présent (2026) ➔ Ère nucléaire. Centrale électrique ultra-sécurisée, parking, hall d'accueil et vestiaires.
└── Futur ➔ Ère cyberpunk technologique. Base de la résistance sous terre, ruines de la supérette, réseau de métro et tour corporatiste d'Alfredo.
```

---

## Guide d'Exploration et Cheminement des Quêtes

### 1. Le HUB Central (Le Nexus temporel)
Le joueur apparaît dans le Nexus. Des bruits d'ambiance cosmiques se font entendre et trois portails s'élèvent devant lui :
- **Le portail orange** (à gauche - interne jaune) mène au **Moyen Âge**.
- **Le portail violet** (au centre - interne bleu) mène au **Présent nucléaire**.
- **Le portail vert** (à droite - interne rouge) mène au **Futur technologique**.

*Actions requises* : Parler au **Gardien du Nexus** pour obtenir des conseils mystiques et caresser le **chien** (qui aboie aléatoirement) avant de sauter dans l'un des portails.

---

### 2. Le Moyen Âge (Ère Médiévale)
Le fil conducteur de cette époque consiste à identifier et neutraliser l'assassin du souverain :
1. **La Salle du Trône (`quete_enquete_roi`)** : Vous trouvez le **Roi du Château** gisant au sol, poignardé. Engagez le dialogue. Dans son dernier souffle, il s'exclame, panique et appelle ses gardes. Il vous accuse à tort de son meurtre (`roi_adieu`), déclenchant votre arrestation immédiate.
2. **Le Cachot (`quete_evasion`)** : Vous êtes jeté au cachot. Vous devez approcher la grille de la cellule et réussir le mini-jeu de **crochetage de serrure** (5 paliers de timing parfaits). Une fois libre, évitez les patrouilles de gardes pour sortir de la prison.
3. **L'Échoppe du Marchand (`quete_deguisement`)** : Les gardes recherchent activement un étranger suspect. Entrez dans la boutique du **Marchand**. Il vous ordonne de vous camoufler. Allez au fond de la boutique, ouvrez l'armoire et réussissez le mini-jeu de **marchandage des habits** (rattraper les bons vêtements de paysan tout en esquivant les pièges). Une fois déguisé, reparlez au marchand qui vous conseille d'aller enquêter à la taverne.
4. **La Taverne du Village (`quete_piste_assassin`)** : Entrez dans la taverne. Parlez à **l'Aubergiste** pour obtenir l'autorisation d'écouter aux tables. Approchez-vous des trois tables et complétez le mini-jeu **d'Écoute aux Tables** (garder le curseur d'écoute stable dans la zone verte oscillante). Vous apprenez que l'assassin portait une cape sombre et a fui vers le parc et la forêt.
5. **Le Parc du Château** : Dans le parc, parlez à la **Femme du Parc** pour la questionner. Cela ouvre l'interface du **Dialogue d'Amitié** (jeu de chat textuel interactif). Discutez poliment avec elle pour faire monter sa confiance à **100%**. Elle vous révèle alors l'emplacement exact de la cachette de l'assassin dans la forêt.
6. **La Forêt et le Campement** : Entrez dans la forêt profonde. Vous y débusquez **l'Assassin** tapit dans l'ombre. Engagez le dialogue pour lancer le combat. Vous êtes téléporté dans l'arène de combat réel du **Campement** (système de posture et de parade en temps réel). Terrassez-le pour rétablir la paix de cette époque et être automatiquement ramené au HUB.

---

### 3. Le Présent (Ère Nucléaire - 2026)
Le but est d'infiltrer la centrale électrique pour empêcher une fusion nucléaire imminente :
1. **Le Poste de Sécurité (`quete_acces_centrale`)** : Tentez d'entrer dans la centrale. L'Agent **Moreau** vous barre la route, exigeant une carte d'accès physique (badge de maintenance). Sans badge, il refuse de vous laisser entrer et vous conseille de faire demi-tour vers le parking.
2. **Le Parking et le Badge** : Allez sur le parking. Approchez-vous discrètement du technicien de maintenance en train de travailler et lancez le mini-jeu du **1, 2, 3 Soleil** (s'approcher lorsque le technicien a le dos tourné et se figer instantanément lorsqu'il se retourne). Dérobez son badge d'accès en finissant le jeu.
3. **L'Infiltration (`quete_preparation`)** : Retournez voir le garde Moreau et montrez-lui le badge. Il s'écarte. Entrez dans le Hall d'accueil et parlez à la secrétaire **Sophie**. Elle vous prend pour le technicien de maintenance attendu et vous ordonne de réparer le circuit de refroidissement. Elle déverrouille le couloir d'accès.
4. **Les Vestiaires** : Allez dans le couloir, puis entrez dans la salle des vestiaires. Interagissez avec les armoires pour revêtir la combinaison de technicien de maintenance de la centrale.
5. **La PC de contrôle & La Salle Électrique** : Une fois en uniforme, vous disposez des habilitations nécessaires pour entrer dans la salle de contrôle. Activez le PC de contrôle principal et réenclenchez les disjoncteurs dans la salle électrique pour stabiliser la centrale nucléaire.

---

### 4. Le Futur (Ère Technologique Cyberpunk)
Vous devez rejoindre la tour corporatiste pour vaincre le dictateur temporel :
1. **La Base de la Résistance** : Vous arrivez dans un garage secret. Discutez avec les leaders de la résistance : **La Cheffe (Billie)** et **La Mécano (Nero)**. Descendez l'escalier vers le laboratoire du sous-sol et parlez au **Dr. Vukovi** et à **Koiai**. Ils vous expliquent que pour vaincre Alfredo, il faut utiliser la voiture blindée de Nero pour forcer l'entrée de la ville de Kadath.
2. **La Course-Poursuite (`MiniJeuVoiture.gd`)** : Remontez au garage et interagissez avec la voiture. La course démarre sur une autoroute à grande vitesse. Esquivez les obstacles et débris sur les 3 voies de circulation pendant **40 secondes consécutives sans le moindre choc**.
3. **Le Guet-apens de la Supérette (`MiniJeuTourelles.gd`)** : La voiture est stoppée devant les ruines d'une supérette. Des tourelles de défense automatiques s'activent. Vous devez survivre pendant **30 secondes** dans la zone de combat en esquivant les orbes d'énergie rougeoyants tirés à haute vitesse.
4. **Le Métro et la Tour** : Traversez le réseau de métro abandonné pour rejoindre l'entrée de la tour géante. Une cinématique vidéo d'introduction spectaculaire (`cinematique_futur.ogv`) se lance automatiquement.
5. **Le Face-à-Face Final (`CombatBossFutur.gd`)** : Pénétrez dans le bureau d'**Alfredo Sinko Nochez**. Lancez la confrontation pour démarrer un combat épique de style JDR au tour par tour. Vainquez Alfredo pour sauver le cours du temps et terminer le jeu !

---

## Fonctionnement des Mini-Jeux et Combats

Le jeu comporte 7 mini-jeux et combats uniques conçus avec des mécaniques bien distinctes :

### 1. Crochetage de la Serrure (Cachot)
- **Objectif** : Ouvrir la serrure en 5 étapes.
- **Règles** : Un curseur oscille de gauche à droite sur une jauge. Appuyez sur la touche `E` précisément lorsque l'indicateur passe dans la zone verte centrale. Chaque timing parfait valide un palier ; chaque erreur réinitialise la progression de l'étape en cours.

### 2. Marchandage des Habits (Magasin Médiéval)
- **Objectif** : Récupérer les vêtements requis pour le déguisement.
- **Règles** : Le marchand effectue des lancers paraboliques à droite et à gauche depuis 4 positions fixes.
  - Déplacez le personnage latéralement avec `←` / `→` pour intercepter les objets.
  - Attrapez au moins **4 vêtements colorés** sur les 5 lancés.
  - Évitez impérativement les pièges rouges marqués d'un signal `⚠️` (maximum 1 piège toléré).
  - La vitesse de chute s'accélère progressivement de 2.0s à 0.62s au cours des 8 rounds.

### 3. Écoute aux Tables (Taverne)
- **Objectif** : Remplir la jauge d'informations de 3 tables successives.
- **Règles** : Maintenez `E` pour monter et relâchez pour descendre. Maintenez le curseur d'écoute stable à l'intérieur d'une zone verte oscillant verticalement sur une jauge.
  - Rester dans la zone verte remplit la jauge d'informations.
  - En sortir fait grimper la jauge de suspicion des clients.
  - Si la jauge de suspicion d'une seule table arrive au maximum, c'est l'échec et tout le mini-jeu redémarre à la première table.

### 4. Dialogue d'Amitié (Parc)
- **Objectif** : Obtenir 100% de confiance mutuelle avec la Femme du Parc.
- **Règles** : Discutez par écrit en tapant vos propres messages dans la boîte de saisie.
  - L'IA analyse sémantiquement vos messages (formules de politesse, empathie, questions pertinentes).
  - Chaque réponse positive de l'IA octroie des points de confiance (`affinity_change` positif de +5 à +20).
  - Les insultes ou les hors-sujets provoquent une baisse de confiance.
  - Si vous jouez hors-ligne, un moteur linguistique de secours évalue vos entrées par rapport à un dictionnaire de mots-clés positifs et négatifs pour simuler l'affinité de manière réaliste.

### 5. Combat Réel contre l'Assassin (Campement)
- **Objectif** : Vaincre l'assassin (100 HP) tout en protégeant vos points de vie (5 HP).
- **Règles** : Observez la posture de l'assassin pour adapter votre stratégie :
  - **Posture Idle** : Attaquez immédiatement avec la touche `E` (inflige 1 point de dégât).
  - **Posture Défensive** : Ne l'attaquez surtout pas ! Si vous frappez son bouclier, vous êtes étourdi pendant **3 secondes**, vous laissant sans défense.
  - **Posture d'Attaque** : L'assassin charge un coup dévastateur (1.0s de préparation). Maintenez instantanément `A` ou `Q` pour parer. Si vous parez à temps, le coup est annulé et l'assassin est déstabilisé. Si vous ne parez pas, vous perdez 1 HP.
  - **Rage (Sous 50 HP)** : L'assassin entre dans une rage folle. Il change de posture deux fois plus vite, se défend dans 55% des cas, et charge ses attaques en seulement **0.5 seconde**, exigeant des réflexes surhumains !

### 6. Course d'Esquive Automobile (Autoroute du Futur)
- **Objectif** : Conduire et survivre pendant 40 secondes continues sur l'autoroute.
- **Règles** : La route comporte 3 voies de circulation.
  - Utilisez les touches `Z` (Haut) et `S` (Bas) pour naviguer entre les voies.
  - Esquivez les débris, barrages routiers et conteneurs qui défilent à la vitesse folle de **1200 px/s**.
  - **Attention** : Toucher un seul obstacle n'entraîne pas de game over immédiat, mais provoque un crash qui **réinitialise le chronomètre de survie à 40.0 secondes**. Vous devez réaliser un parcours parfait et sans-faute de 40 secondes consécutives pour gagner.

### 7. Infiltration 1, 2, 3 Soleil (Parking du Présent)
- **Objectif** : S'approcher du technicien de maintenance à moins de 55 pixels pour lui dérober son badge.
- **Règles** : Avancez horizontalement vers la gauche à l'aide des touches de déplacement.
  - **Il regarde ailleurs** : Foncez vers la gauche.
  - **Attention (Warning)** : Le technicien s'apprête à se retourner (durée d'avertissement de 0.3s). Arrêtez immédiatement tout déplacement.
  - **Ne bougez plus (Looking At)** : Le technicien vous fait face. Ne pressez aucune touche directionnelle.
  - **Pénalité** : Si vous êtes détecté en mouvement pendant les phases d'alerte, vous subissez un strike (maximum 3 tolérés), êtes étourdi pendant 1.2s et subissez un recul brutal de **200 pixels** vers la droite.

### 8. Évitement de Tourelles de Sécurité (Supérette)
- **Objectif** : Survivre aux tirs de tourelles laser automatiques pendant 30 secondes.
- **Règles** : Déplacez votre personnage librement dans la zone.
  - Les tourelles rotatives de sécurité ciblent la zone et projettent des vagues d'orbes énergétiques rouges continuellement.
  - Le moindre contact avec un orbe laser retire l'intégralité de vos points de vie et réinitialise l'épreuve à 30 secondes.

### 9. Combat JDR Tour par Tour contre Alfredo (Bureau)
- **Objectif** : Réduire les points de vie d'Alfredo (150 HP) à 0 avant qu'il ne détruise votre personnage (100 HP).
- **Règles** : À chaque tour, choisissez l'une des trois actions de combat :
  - **Attaquer** : Assène des dégâts physiques directs basés sur votre force d'attaque brute (ATK = 20) moins la défense d'Alfredo (DEF = 5), agrémenté d'une variation aléatoire.
  - **Parer** : Double votre statistique de défense pour le tour en cours afin d'atténuer considérablement les dégâts reçus si Alfredo décide d'attaquer.
  - **Soin** : Restaure **35 points de vie** instantanément. Cette compétence de secours a une charge unique et ne peut être utilisée qu'une seule fois durant tout l'affrontement.
  - **IA d'Alfredo** : Alfredo évalue sa situation et effectue un lancer de dé à chaque tour :
    - *70% de chance d'Attaquer* : Il vous inflige de lourds dégâts physiques (ATK de base = 15).
    - *20% de chance de Concentration* : Il renforce sa puissance d'attaque brute de +3 points de dégât permanents pour la suite du combat.
    - *10% de chance de Provocation* : Il rit et se moque de vos efforts sans consommer d'action nuisible.

---

## Organisation des Assets et Ressources du Projet

Toutes les ressources graphiques et sonores sont structurées de manière modulaire :

```
art/ ➔ Fichiers graphiques PNG et animations
├── perso_*.png ➔ Spritesheets d'animations de Time-Aunote (marche, idle, déguisé)
├── pnj-hub.png ➔ Sprite du Gardien du Nexus
├── chien-hub.png ➔ Sprite du chien interactif
├── MoyenAge/ ➔ Décors médiévaux, portraits du Roi et du Marchand, épée/bouclier
├── Present/ ➔ Graphismes de la centrale, sprite du garde Moreau et du technicien
├── Futur/ ➔ Graphismes cyberpunk, portraits de Nero, Billie, Vukovi, Alfredo et sprites laser
└── voiturefutur.png ➔ Sprite de la voiture blindée de la résistance

audio/ ➔ Ressources d'effets sonores et musiques d'ambiance
├── hub/ ➔ Musiques d'ambiance aléatoires lues en boucle dans le Nexus
├── chien/ ➔ Différents aboiements du chien interactif
└── crochetage/ ➔ Sons de clics de serrure (ticks), bruitages d'échec et de victoire
```

---

## Conseils de Contribution et Règles GDScript

Si vous souhaitez modifier ou ajouter du contenu au projet, merci de respecter scrupuleusement les consignes architecturales suivantes :

1. **Pas de C# / .NET** : timeOnaute est entièrement écrit en **GDScript**. Aucun fichier `.cs`, `.sln` ou `.csproj` ne sera accepté.
2. **Gestion de la Mémoire et Tweens** : Veillez à toujours nettoyer vos labels temporaires et tweens d'animation (via `queue_free()`) dans la fonction `stop()` de vos ères pour éviter les fuites de mémoire ou les plantages de scripts lors du déchargement de scènes (PROCESS_MODE_DISABLED).
3. **Mise à Jour des Objectifs de l'Interface** : La progression du joueur doit être mise à jour à l'aide de signaux de quête `quest_updated`. N'écrivez jamais d'objectifs statiques en dur dans l'interface globale.
4. **Typage GDScript Inférentiel** : Pour toutes les variables nécessitant une affectation avec inférence statique (`:=`), remplacez impérativement les appels à `clamp()` par des fonctions typées strictes comme **`clampf()`** ou **`clampi()`** pour éviter les parse-errors de type `Variant`.
5. **Modification des Dialogues** : Pour modifier la personnalité ou ajouter des quêtes à un PNJ, n'éditez pas directement les scripts Godot. Utilisez le générateur Python situé dans `GenerateurJson/` et enregistrez les modifications sous forme de fichiers JSON dans le répertoire correspondant.
