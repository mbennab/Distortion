# Spécification Technique - Nexus Dog Playroom (Morpion & Chien-Pong)

Ce document définit les spécifications de conception et de logique pour la refonte complète du mini-jeu d'interaction avec le chien dans le HUB Central de **Distortion**.

---

## 🎨 1. Concept Global

L'interaction avec le chien (`chienHub`) dans le HUB Central n'ouvre plus un simple jeu d'arcade unidimensionnel, mais un menu de sélection interactif appelé **« NEXUS DOG PLAYROOM »**. Ce hub d'interaction permet au joueur de se mesurer directement au chien à travers deux jeux rétro classiques revisités avec humour :

1. **🦴 Le Morpion des Os (Tic-Tac-Toe)** : Jeu stratégique tour par tour où le chien réfléchit et joue de manière autonome avec des os vectoriels, tandis que le joueur joue avec des balles de tennis vertes.
2. **🏓 Chien-Pong** : Un Pong rétro frénétique où la raquette adverse est représentée par la **queue rose** du chien qui s'anime et aboie joyeusement en renvoyant le projectile.

---

## 📂 2. Architecture Technique et États

Le système est entièrement autonome et écrit en **GDScript (Godot 4.6)** dans un seul fichier : `res://HUB Central/MiniJeuChien.gd`.

### Machine à États de l'Interface
Le mini-jeu s'articule autour de l'énumération suivante :
```gdscript
enum GameState {
	MENU,        # Menu de sélection principal
	MORPION,     # Écran et boucle de jeu du Morpion
	PONG         # Écran et boucle de jeu de Pong
}
```

---

## 🐶 3. Conception et Logique des Jeux

### 3.1. Le Menu Principal (`GameState.MENU`)
- **Portrait du Chien** : Un dessin vectoriel de la tête du chien est rendu via `_draw()`.
- **La Queue Animée** : Une ligne courbe vectorielle représentant sa queue oscille doucement via une formule mathématique basée sur le temps :
  ```gdscript
  var sway := sin(Time.get_ticks_msec() * 0.015) * 20.0
  ```
  Le chien remue lentement sa queue dans le menu pour montrer qu'il est de bonne humeur et prêt à jouer.
- **Boutons** : Des boutons Godot stylisés avec le thème violet néon du HUB.

---

### 3.2. Le Morpion des Os (`GameState.MORPION`)
- **Plateau** : Grille vectorielle 3x3 centrée. Chaque case de la grille est un bouton invisible ou une zone de clic souris.
- **Symboles** :
  - **Joueur (Rond/Balle de tennis)** : Dessine un cercle néon vert (`Color(0.24, 0.95, 0.79)`).
  - **Chien (Croix/Os de chien)** : Dessine un os blanc néon (`Color(1.0, 1.0, 1.0)`). L'os est composé d'une ligne centrale et de quatre petits cercles aux extrémités.
- **IA Canine (Tour par Tour)** :
  1. Le joueur clique sur une case vide. Son symbole s'affiche.
  2. Le tour passe au chien. Le statut affiche : `🐾 LE CHIEN FLAIRE LE PLATEAU...`.
  3. Un minuteur de **0.7 seconde** s'écoule pour simuler la réflexion du chien.
  4. L'IA applique les priorités suivantes :
     - **Attaque** : Si le chien peut aligner 3 symboles pour gagner, il joue ce coup.
     - **Défense** : Si le joueur s'apprête à aligner 3 symboles, le chien joue la case pour le bloquer.
     - **Centre/Coins** : Le chien privilégie le centre, puis les quatre coins.
     - **Aléatoire** : S'il n'y a pas de menace immédiate, il choisit une case disponible.
  5. Le chien pose son symbole, joue un petit aboiement joyeux, et le tour repasse au joueur.
- **Fin de Partie** :
  - **Victoire Joueur** : Le chien pousse un petit glapissement déçu, et des petites larmes vectorielles bleues coulent sous ses yeux.
  - **Victoire Chien** : Le chien pousse un double aboiement triomphant, et sa queue oscille à toute vitesse.

---

### 3.3. Le Chien-Pong (`GameState.PONG`)
- **Terrain** : Rectangle 600x240 avec bordure violette et filet pointillé central.
- **Commandes Joueur** : Déplacement de la raquette gauche (cyan) via la souris (axe Y) ou au clavier (touches Z/S, A/Q ou flèches).
- **IA de la Queue du Chien** :
  - La raquette droite (rose) représente la queue du chien.
  - Elle suit la position en Y de la balle.
  - Pour rendre le jeu équitable et amusant, sa vitesse de suivi est bridée :
    ```gdscript
    var target_y := ball_pos.y
    paddle_dog_y = move_toward(paddle_dog_y, target_y, dog_paddle_speed * delta)
    ```
- **La Balle (Croquette Temporelle)** : Se déplace de gauche à droite, rebondissant sur les parois supérieures et inférieures. Sa vitesse augmente de 10% à chaque échange réussi.
- **Audio de Collision** :
  - Rebond sur raquette joueur -> Petit jappement aigu.
  - Rebond sur raquette chien -> Aboiement franc.
- **Condition de Victoire** : Le premier joueur à atteindre **5 points** gagne la partie.

---

## 🔊 4. Intégration Audio et Particules

- **Aboiements Joyeux** : Utilisent les fichiers originaux de `res://audio/chien/` en appliquant un pitch-scale aléatoire entre `1.15` et `1.45` pour moduler ses émotions.
- **Particules de Victoire** : Lorsque le joueur marque un point au Pong ou remporte une partie de Morpion, le script appelle `declencher_particles_victoire()` sur le parent pour faire exploser des confettis cyber-cyan autour du chien dans le HUB.

---

## 🛠️ 5. Validation de la Sécurité du Code
- **GDScript Strict** : Typage statique imposé (`:=` et typages de paramètres explicites).
- **Nettoyage Mémoire** : Nettoyage rigoureux des tableaux, des timers et des écouteurs d'événements lors de la fermeture pour éviter toute corruption.
