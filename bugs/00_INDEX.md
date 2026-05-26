# Bug Report Index — Distortion (timeOnaute)

> Rapport généré le 2026-05-26 après exploration exhaustive de tout le codebase.
> **Branche :** `fix/bugs`
> **Total bugs :** ~90+ (toutes sévérités confondues)

---

## 🔴 CRITIQUES (Crash / Blocage de progression)

| # | Fichier | Bug | Rapport |
|---|---------|-----|---------|
| C1 | `Scripts/DialogueSystem.gd:47` | `OS.get_environment()` → `OS.getenv()` — API Godot 3 supprimée, dialogue IA mort | [01_DialogueSystem_OS_API.md](01_DialogueSystem_OS_API.md) |
| C2 | `Personnage/TimeAunote.gd:74-81` | Logique de direction inversée (sprite regarde à gauche quand il va à droite) | [02_TimeAunote_direction_inverted.md](02_TimeAunote_direction_inverted.md) |
| C3 | `Main.gd:11,23,26,29` | `start()` appelée sans argument `spawn_id` requis → erreur "Too few arguments" | [03_Main_gd_missing_args.md](03_Main_gd_missing_args.md) |
| C4 | `HUB Central/TimeAunote.tscn:3` | Référence script cassée (pointe vers `res://HUB Central/TimeAunote.gd` inexistant) | [04_HUB_broken_scripts_sprites.md](04_HUB_broken_scripts_sprites.md) |
| C5 | `HUB Central/` | Sprite chien : 471px vs 468px décalage + hardcodé dans MiniJeuChien.gd | [04_HUB_broken_scripts_sprites.md](04_HUB_broken_scripts_sprites.md) |
| C6 | `Present.gd:120,1490+` | `modulate.a = X` ne modifie pas la propriété (copie de struct éphémère en Godot 4) | [05_Present_critical_bugs.md](05_Present_critical_bugs.md) |
| C7 | `Present.gd:152-167` | Tween de pulsation jamais tué → conflit avec le tween de fade-out | [05_Present_critical_bugs.md](05_Present_critical_bugs.md) |
| C8 | `Present.gd:1820-1832` | `_salle_machine_done = true` même en cas d'échec → softlock permanent | [05_Present_critical_bugs.md](05_Present_critical_bugs.md) |
| C9 | `MoyenAge/campement.gd:175-196` | Conflit victoire/défaite dans le même frame → cinématique corrompue | [06_MoyenAge_critical.md](06_MoyenAge_critical.md) |
| C10 | `MoyenAge/prison_moyen_age.gd:85-109` | `get_parent()` null sans vérification → crash | [06_MoyenAge_critical.md](06_MoyenAge_critical.md) |
| C11 | `MoyenAge/magasin_moyen_age.gd:175-239` | Timer/tween zombie après `stop()` → fuite mémoire | [06_MoyenAge_critical.md](06_MoyenAge_critical.md) |
| C12 | `Scripts/MiniJeuTourelles.gd` | Pas de `.tscn` → positions tourelles à (0,0) → jeu impossible | [07_MiniGames_critical.md](07_MiniGames_critical.md) |
| C13 | `Scripts/GardeEtage.gd:82-120` | Collision rectangle ≠ cône visuel → détection complètement cassée | [07_MiniGames_critical.md](07_MiniGames_critical.md) |
| C14 | `Scripts/MiniJeuAmitie.gd:741` | `_on_tree_exiting()` au lieu de `_exit_tree()` → nettoyage jamais appelé | [07_MiniGames_critical.md](07_MiniGames_critical.md) |
| C15 | `Futur/route.gd:147` | Division par zéro si textures obstacle absentes | [08_Futur_critical.md](08_Futur_critical.md) |
| C16 | `Scripts/GardeEtage.gd:77` | `texture.get_size()` sur null → crash si texture manquante | [08_Futur_critical.md](08_Futur_critical.md) |
| C17 | `Scripts/CombatBossFutur.gd:1004,1053,1131` | `texture.get_size()` sur null → crash si assets victoire manquants | [08_Futur_critical.md](08_Futur_critical.md) |

---

## 🟠 HAUTE SÉVÉRITÉ (Game-breaking / Progression bloquée)

| # | Fichier | Bug | Rapport |
|---|---------|-----|---------|
| H1 | `Present.gd:1413-1942` | `_darkness_active` jamais reset → overlay ne s'affiche plus au restart | [05_Present_critical_bugs.md](05_Present_critical_bugs.md) |
| H2 | `Present.gd:1413-1417` | `started` pas reset → joueur bloqué au restart | [05_Present_critical_bugs.md](05_Present_critical_bugs.md) |
| H3 | `Present.gd:255,578+` | `await tween.finished` coroutines zombies après `stop()` | [05_Present_critical_bugs.md](05_Present_critical_bugs.md) |
| H4 | `Present/pnj_securité.gd:83-86` | `z_index = 10` manquant + `play()` manquant dans `apparition()` | [05_Present_critical_bugs.md](05_Present_critical_bugs.md) |
| H5 | `MoyenAge/campement.gd:170` | `is_key_pressed(KEY_E)` = spam attaque continu | [06_MoyenAge_critical.md](06_MoyenAge_critical.md) |
| H6 | `MoyenAge/MoyenAge.gd:499+` | `get_node("collision")` sans `_or_null` x10 dans tout le dossier | [06_MoyenAge_critical.md](06_MoyenAge_critical.md) |
| H7 | `MoyenAge/magasin_moyen_age.gd:149` | `get_parent().get_node(...)` crash si contexte invalide | [06_MoyenAge_critical.md](06_MoyenAge_critical.md) |
| H8 | `MoyenAge/parc_moyen_age.gd:67` | Accès à `_mg_instance._won` privé | [06_MoyenAge_critical.md](06_MoyenAge_critical.md) |
| H9 | `Scripts/CombatBossFutur.gd:471` | StyleBoxFlat partagé → barres de vie toutes de la même couleur | [10_CombatBoss_high.md](10_CombatBoss_high.md) |
| H10 | `Scripts/CombatBossFutur.gd:888` | Shift/Ctrl déclenchent échec QTE | [10_CombatBoss_high.md](10_CombatBoss_high.md) |
| H11 | `Scripts/WarpSystem.gd:569,690` | Appel à `DialogueSystem._find_quest()` privé | [09_Architecture_high.md](09_Architecture_high.md) |
| H12 | `Scripts/DialogueUI.gd:400` | `var normal_panel` shadowe la variable membre | [09_Architecture_high.md](09_Architecture_high.md) |
| H13 | `Scripts/MiniJeuCablage.gd:616-627` | StyleBoxFlat partagé muté → couleurs erronées | [13_MiniGames_high.md](13_MiniGames_high.md) |
| H14 | `Scripts/MiniJeuTuyau.gd:598-615` | Tweens concurrents sur rotation des tuyaux | [13_MiniGames_high.md](13_MiniGames_high.md) |
| H15 | `Scripts/MiniJeuTuyau.gd:613-615` | Callback rotation corrompt puzzle après reset | [13_MiniGames_high.md](13_MiniGames_high.md) |
| H16 | `Scripts/MiniJeuTourelles.gd:92-97` | Signal `finished` émis multiple fois | [13_MiniGames_high.md](13_MiniGames_high.md) |
| H17 | `Scripts/OrbeTourelle.gd:5-15` | Auto-delete orbe compétition avec parent | [13_MiniGames_high.md](13_MiniGames_high.md) |
| H18 | `Menu/MainMenu.gd:140` | `duplicate()` retourne Variant, pas StyleBoxFlat | [09_Architecture_high.md](09_Architecture_high.md) |
| H19 | `Futur/Futur.gd:1366` | `get_node("collision")` sans `_or_null` dans `stop()` | [08_Futur_critical.md](08_Futur_critical.md) |
| H20 | `Futur/Futur.gd:135` | `_car_prompt.visible` sur null si joueur va au sous-sol trop vite | [08_Futur_critical.md](08_Futur_critical.md) |
| H21 | `Futur/route.gd:19` | Durée partie 30s au lieu de 40s (spéc) | [08_Futur_critical.md](08_Futur_critical.md) |
| H22 | `Present.gd:1108-1118` | `_go_to_hall()` cache pas toutes les sous-zones | [11_Present_progression_high.md](11_Present_progression_high.md) |

---

## 🟡 MOYENNE SÉVÉRITÉ

| # | Fichier | Bug | Rapport |
|---|---------|-----|---------|
| M1 | `Present/vestiaire.gd:142-146` | `shape_rect.size` sur null → crash collision | [14_Null_safety_medium.md](14_Null_safety_medium.md) |
| M2 | `Present/parking.gd,pnj_*.gd` | `body.name == "TimeAunote"` fragile vs identité | [14_Null_safety_medium.md](14_Null_safety_medium.md) |
| M3 | `Present.gd:551-559` | Prompts `disjoncteur` jamais cachés | [11_Present_progression_high.md](11_Present_progression_high.md) |
| M4 | `MoyenAge/MoyenAge.gd:573` | Accès `DialogueSystem._find_quest()` | [15_MoyenAge_medium.md](15_MoyenAge_medium.md) |
| M5 | `MoyenAge/MoyenAge.gd:409,744` | Signaux connectés sans déconnexion dans `stop()` | [15_MoyenAge_medium.md](15_MoyenAge_medium.md) |
| M6 | `MoyenAge/MoyenAge.gd:228` | `move_and_collide` au lieu de `move_and_slide` | [15_MoyenAge_medium.md](15_MoyenAge_medium.md) |
| M7 | `MoyenAge/MoyenAge.gd:148` | `DirAccess.open("res://")` ne marche pas en export | [15_MoyenAge_medium.md](15_MoyenAge_medium.md) |
| M8 | `Scripts/MiniJeuCrochetage.gd:299-301` | Condition tick audio toujours vraie | [13_MiniGames_high.md](13_MiniGames_high.md) |
| M9 | `Scripts/MiniJeuDisjoncteur.gd:264-285` | Null access sur `_switch_nodes[i]` | [13_MiniGames_high.md](13_MiniGames_high.md) |
| M10 | `Scripts/MiniJeuEcouteTables.gd:389-393` | Pas de gestion ESC pour quitter | [13_MiniGames_high.md](13_MiniGames_high.md) |
| M11 | `Scripts/MiniJeuEcouteTables.gd:651-657` | Timer lambda peut opérer sur nœud libéré | [13_MiniGames_high.md](13_MiniGames_high.md) |
| M12 | `Scripts/MiniJeuMarchandage.gd:328` | Emoji non rendus dans Label Godot | [13_MiniGames_high.md](13_MiniGames_high.md) |
| M13 | `Scripts/MiniJeuSoleil.gd:142-145` | Handler resize incomplet | [13_MiniGames_high.md](13_MiniGames_high.md) |
| M14 | `Scripts/MiniJeuTuyau.gd:766-770` | Fuite fluide conflit visuel avec highlight | [13_MiniGames_high.md](13_MiniGames_high.md) |
| M15 | `Scripts/CombatBossFutur.gd:685` | PV boss P2 250 vs spec 150 | [10_CombatBoss_high.md](10_CombatBoss_high.md) |
| M16 | `Futur/Futur.gd:1126` | Array non typé perte safety | [08_Futur_critical.md](08_Futur_critical.md) |
| M17 | `Futur/Futur.gd:650` | `load()` au lieu de `preload()` pour garde | [08_Futur_critical.md](08_Futur_critical.md) |

---

## 🔵 BASSE SÉVÉRITÉ (Code quality, maintenance)

| # | Fichier | Bug | Rapport |
|---|---------|-----|---------|
| L1 | `Personnage/TimeAunote.gd:23-25` | `_process()` vide qui tourne 60fps | [16_Code_quality_low.md](16_Code_quality_low.md) |
| L2 | `Personnage/TimeAunote.gd:9,20,89` | `timerAttente` sans callback connecté | [16_Code_quality_low.md](16_Code_quality_low.md) |
| L3 | `HUB Central/HUB Central.gd:320-335` | `timerSortie` pas stoppé dans `stop()` | [16_Code_quality_low.md](16_Code_quality_low.md) |
| L4 | `HUB Central/pnj_hub.gd` + `chien_hub.gd` | `player_nearby` pas reset dans `stop_idle()` | [16_Code_quality_low.md](16_Code_quality_low.md) |
| L5 | `Present/pnj_securité.gd` | Accent `é` dans filename → problèmes git cross-platform | [17_Git_portability.md](17_Git_portability.md) |
| L6 | `Present/parking.gd` | Typo "interation" → "interaction" | [16_Code_quality_low.md](16_Code_quality_low.md) |
| L7 | `Futur/Futur.tscn:82` | Root node "Futurrrrr" (typo 4 r) | [16_Code_quality_low.md](16_Code_quality_low.md) |
| L8 | `dimension_futur.json:351` | Global fallback hardcode "La Cheffe" | [16_Code_quality_low.md](16_Code_quality_low.md) |
| L9 | `pnj_mecano.gd:3` | `npc_id` = "npc_punk_futur" trompeur | [16_Code_quality_low.md](16_Code_quality_low.md) |
| L10 | Tous `pnj_*.gd` | Code bulle dialogue dupliqué ×11 scripts (~600 lignes) | [16_Code_quality_low.md](16_Code_quality_low.md) |
| L11 | `Scripts/MiniJeuMarchandage.gd:120` | `randomize()` obsolète Godot 4 | [16_Code_quality_low.md](16_Code_quality_low.md) |

---

## Actions Recommandées (Priorité)

1. **🔥 Immédiat** : Corriger C1 (DialogueSystem API), C2 (direction inversée), C3 (Main.gd args manquants)
2. **🔥 Immédiat** : Corriger C6-C8 (Present modulate + darkness + softlock)
3. **🔥 Immédiat** : Corriger C9-C11 (MoyenAge combat + prison + magasin)
4. **🔥 Immédiat** : Corriger C12-C14 (MiniJeuTourelles, GardeEtage, MiniJeuAmitie)
5. **⚠️ Urgent** : Corriger H1-H4 (Présent restart + zombie coroutines)
6. **⚠️ Urgent** : Corriger H5-H8 (MoyenAge combat spam + null safety)
7. **⚠️ Urgent** : Corriger H9-H11 (CombatBoss style partagé + QTE + WarpSystem)
8. **📋 Normal** : Corriger les bugs MEDIUM
9. **🧹 Faible** : Refactoring code quality
