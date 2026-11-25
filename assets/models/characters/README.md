# Personnage de test — LIBREVILLE STORIES

Le personnage de test utilise le mannequin humanoïde riggé **UAL1_Standard.glb** de Quaternius. La bibliothèque **UAL2_Standard.glb** est également incluse pour compléter les animations de locomotion, de combat et de parkour. Les deux ressources sont sous licence CC0 1.0 ; voir `LICENSE-Quaternius-UAL.txt`.

## Bibliothèques intégrées

- `UAL1_Standard.glb` : mannequin et clips de base déjà utilisés par `player_visual.gd`.
- `UAL2_Standard.glb` : bibliothèque complémentaire importée depuis la distribution officielle Quaternius. Les clips ne sont pas encore activés dans le contrôleur du joueur : le diagnostic Godot doit d'abord confirmer leurs noms et la compatibilité exacte des squelettes.

## Import dans Godot

Les deux fichiers GLB sont versionnés dans le dépôt. Ouvrir le projet avec Godot 4.3 ou supérieur et laisser l'import des ressources se terminer. Le script `tools/inspect_character_animations.gd` liste les clips disponibles et compare les os des deux squelettes. La validation GitHub Actions exécute ce diagnostic automatiquement après l'import du projet.

Si UAL1 n'est pas disponible, `player_visual.gd` génère un mannequin humain provisoire à la place du tube bleu.

## Sources et licences

- UAL1 : https://quaternius.itch.io/universal-animation-library
- UAL2 : https://quaternius.itch.io/universal-animation-library-2
- Licence des deux ressources : CC0 1.0 Universal.
