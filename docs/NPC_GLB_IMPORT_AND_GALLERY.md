# Import GLB et galerie de personnages

## Fonctionnement actuel

La scène `res://game/scenes/npc_gallery.tscn` affiche jusqu'à 100 résidents présents dans `PopulationManager.residents`.

Pour chaque résident :
1. Le script `game/scripts/npc_gallery.gd` lit le champ `gender` (`homme` ou `femme`).
2. Il recherche le GLB correspondant dans `assets/characters/base/`.
3. Si le fichier est importé et chargeable, il vérifie la présence d'un `Skeleton3D` avec au moins un os et d'un `AnimationPlayer` contenant une animation idle.
4. Si les contrôles réussissent, il instancie le GLB et lance l'animation idle.
5. Si le modèle est absent, non chargeable ou incomplet, il le rejette et utilise `npc_character.tscn`, le personnage procédural de secours.

Les chemins attendus sont :
- `assets/characters/base/civilian_male_01.glb`
- `assets/characters/base/civilian_female_01.glb`

Le modèle GLB doit avoir une racine de type `Node3D`. L'animation d'attente peut être nommée `idle-loop`, `Idle`, `idle` ou commencer par `idle`. Si aucune animation correspondante n'existe, le modèle reste affiché sans animation.

## Export depuis Ara 3D Gen

Pour chaque personnage :
- choisir un personnage complet, en pose A ;
- activer le rig de jeu ;
- exporter en GLB ;
- demander le niveau Low pour les foules et conserver une variante Medium si elle est réellement nécessaire ;
- inclure au minimum une animation d'attente (`idle`) ; walk et run seront validées ensuite ;
- conserver les paramètres de génération et les informations de licence dans `data/characters/sources/`.

Copier les fichiers GLB dans `assets/characters/base/`. Ne pas renommer les fichiers autrement sans mettre à jour `MODEL_BY_GENDER` dans `npc_gallery.gd`.

## Vérification dans Godot

1. Ouvrir le projet dans Godot 4.3 et attendre la fin de l'import glTF.
2. Ouvrir `game/scenes/npc_gallery.tscn` et lancer la scène (F6).
3. Vérifier que les modèles sont à la bonne échelle, debout sur le sol, orientés vers l'avant et correctement éclairés.
4. Vérifier dans la sortie de débogage le nombre de GLB chargés et de prototypes de secours.
5. Vérifier que les animations sont présentes dans l'`AnimationPlayer` et que l'animation idle joue.
6. Contrôler les déformations du squelette, les mains, les pieds, les cheveux et les vêtements.

## Limites connues

- Les fichiers GLB ne sont pas encore livrés dans le dépôt ; le fallback procédural reste donc utilisé.
- Le choix du modèle est pour l'instant basé sur le genre enregistré, pas sur la morphologie individuelle.
- Le contrôle runtime vérifie la présence d'un squelette non vide et d'une animation idle ; il ne garantit pas encore la qualité des poids, des matériaux, des proportions ou des déformations.
- La galerie est un outil de contrôle, pas le système final de streaming des PNJ.
- Les animations walk/run ne sont pas encore reliées au déplacement des personnages.
- Le chargement des modèles doit être testé avec Godot sur la machine cible avant d'augmenter le nombre de PNJ visibles.