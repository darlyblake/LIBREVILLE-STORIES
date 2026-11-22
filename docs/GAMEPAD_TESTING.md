# Test des manettes — Libreville Stories

## Commandes à pied

| Action | Clavier | Manette |
|---|---|---|
| Avancer / reculer | ZQSD / WASD | Stick gauche |
| Sauter | Espace | A / Croix |
| Caméra | Souris | Stick droit |
| Entrer / sortir du véhicule | F | Y / Triangle |

## Conduite du véhicule de test

| Action | Manette | Clavier |
|---|---|---|
| Diriger | Stick gauche horizontal | A / D ou flèches |
| Accélérer | RT | W / Flèche haut |
| Freiner | LT | S / Flèche bas |
| Entrer / sortir | Y / Triangle | F |

Le véhicule de test est construit avec des primitives 3D afin de pouvoir vérifier immédiatement la conduite sans attendre le téléchargement d'un modèle GLB. Son visuel sera remplaçable par une voiture détaillée ultérieurement.

## Vérification sous Linux

1. Brancher la manette avant de lancer le jeu.
2. Vérifier qu'Ubuntu la détecte avec `lsusb` (USB) ou les paramètres Bluetooth.
3. Lancer le projet Godot.
4. Tester les sticks, RT, LT et Y/Triangle.
5. Vérifier que le joueur peut entrer dans la voiture à proximité, conduire, freiner et en sortir.
6. Refaire le test dans une session exportée, pas seulement dans l'éditeur.

## Notes techniques

- Les gâchettes RT/LT sont lues comme axes analogiques Godot. Sur les manettes standard, leur valeur neutre est -1 et leur valeur pressée tend vers +1.
- Le bouton Y est utilisé comme équivalent de Triangle sur les manettes PlayStation reconnues par Godot.
- Les commandes doivent être validées avec la manette physique utilisée : les dispositions peuvent varier selon le pilote et le mode XInput/DirectInput.
- Le véhicule est un prototype de conduite, pas encore une simulation automobile complète.
