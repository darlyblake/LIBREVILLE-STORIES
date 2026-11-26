# Première galerie de personnages 3D

## Contenu

- `game/scenes/npc_character.tscn` : scène réutilisable d'un habitant.
- `game/scripts/npc_character.gd` : construction modulaire du corps, du visage, des cheveux et de quelques accessoires.
- `game/scenes/npc_gallery.tscn` et `game/scripts/npc_gallery.gd` : galerie technique qui instancie les 100 premiers habitants de la population sauvegardée.

## Identité persistante

Le personnage est construit depuis `resident.appearance`, déjà enregistré dans la fiche du résident. Le script ne tire pas de nouveaux traits au moment de l'affichage. Le même résident retrouve donc la même apparence après désactivation/réactivation et après rechargement de la sauvegarde.

L'identifiant de résident reste la clé d'association. La galerie ne crée pas de nouvelles identités et ne modifie pas la population.

## Limites de cette première version

Cette galerie est un prototype de formes primitives Godot, pas encore des modèles humains réalistes sculptés. Les traits de visage et vêtements sont volontairement simples. Les cheveux, les vêtements détaillés, les animations, les matériaux peau réalistes, les morphs d'âge et la transmission héréditaire des traits seront enrichis ensuite.

Pour lancer la galerie dans l'éditeur Godot, ouvrir `game/scenes/npc_gallery.tscn` puis exécuter la scène courante (F6). Elle utilise la population sauvegardée chargée par l'autoload `PopulationManager`.

## Performance

La galerie est un outil de vérification, pas la scène de jeu. Afficher 100 personnages simultanément sert à inspecter la diversité. En jeu, le système de proximité devra limiter les personnages 3D actifs et réutiliser les meshes et matériaux partagés.
