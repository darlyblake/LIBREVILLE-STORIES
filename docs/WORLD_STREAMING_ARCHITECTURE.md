# Streaming spatial du monde — première fondation

## Objectif

Découper le monde jouable en secteurs carrés indépendants. Le joueur déclenche
l'activation des secteurs proches ; les secteurs éloignés sont désactivés avec
un rayon de sortie plus large afin d'éviter le clignotement à la frontière.

## Implémentation initiale

- Script : `game/scripts/world_streaming_manager.gd`
- Nœud : `WorldStreamingManager` dans `game/scenes/main.tscn`
- Taille de secteur par défaut : 256 m
- Rayon d'activation : 2 secteurs
- Rayon de sortie : 3 secteurs
- Actualisation : 0,20 s
- Conversion monde → secteur par coordonnées X/Z avec `floori`.
- API `register_node(node, category, world_position)` pour ranger les éléments
  générés dans un conteneur spatial et conserver leur transformation globale.
- Désactivation : visibilité, traitement des nœuds et couches de collision.
  Les objets ne sont pas détruits ; leurs ressources restent disponibles.

## Limite volontaire de cette première étape

Le terrain possède déjà son propre streaming en chunks DEM. Les routes,
bâtiments, végétation, littoral et POI sont encore construits par les
générateurs de `world_map.gd`. Ils ne sont pas encore tous enregistrés dans
les secteurs : il ne faut donc pas présenter cette étape comme un streaming
complet de la ville.

La prochaine intégration devra découper les lots de géométrie par secteur,
et non déplacer un grand mesh multi-quartiers selon son seul centre. Les
collisions routières, les intersections, les trottoirs et les dépendances de
la Baie des Rois devront rester cohérents lors des transitions.

## Contrôles requis

- Vérifier le parse Godot 4.3 et le démarrage de `main.tscn`.
- Vérifier le reparentage avec conservation du transform global.
- Vérifier l'activation/désactivation des collisions.
- Tester les transitions à pied et en véhicule.
- Comparer les secteurs traversés avec le périmètre validé du projet :
  aucun contenu hors périmètre ne doit être généré.

## Première intégration : tuiles routières

- Le gestionnaire utilise désormais des secteurs de 800 m, alignés sur
  `ROAD_TILE_SIZE` de la carte.
- Chaque tuile routière générée devient un conteneur unique `RoadTile_x_z`.
- Chaussée, bordures, trottoirs, marquages et collisions restent ensemble.
- Le conteneur est enregistré dans le secteur correspondant à son centre.
- Le reparentage conserve le repère global des meshes créés par SurfaceTool.
- Une tuile enregistrée hors rayon est immédiatement masquée et ses collisions
  sont désactivées, y compris lorsqu'elle est ajoutée après la création du secteur.

Les bâtiments ne sont pas encore intégrés : leurs meshes sont actuellement
regroupés par lots de 1 200 empreintes triées par distance, pas par position.
Les bâtiments sont maintenant regroupés en lots limités à un seul secteur,
avec un maximum de 1 200 empreintes par lot. Les bâtiments spéciaux de la Baie
des Rois sont eux aussi enregistrés individuellement dans leur secteur.
Chaque lot de murs, toitures et détails de façade est placé dans un conteneur
sectoriel unique. Les empreintes sont affectées au secteur de leur centre ; les
très grands bâtiments traversant une frontière restent donc une limite à tester.
