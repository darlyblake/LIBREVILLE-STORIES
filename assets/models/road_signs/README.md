# Signalisation routière

## Pack GLB conservé en bibliothèque

- Fichier : `road_signs_pack_revamped.glb`
- Réception : 19 novembre 2026.
- État : scène-source conservée, non instanciée.
- Provenance, auteur et licence : non documentés dans le dépôt à ce stade.
- Règle : ne pas redistribuer ni instancier le pack avant d'avoir retrouvé sa source et vérifié les droits d'utilisation.

## Signalisation actuellement générée dans le jeu

Le script `game/scripts/traffic_signs.gd` construit des panneaux 3D originaux à partir des intersections de `data/osm/extended/roads.geojson` :
- panneaux STOP octogonaux ;
- plaques de nom de rue lorsque le nom OSM est disponible ;
- feux tricolores aux carrefours majeurs ;
- panneaux piétons lorsque les points de traversée sont présents dans les données.

Les positions sont calculées dans le même repère géographique que la carte et ajustées à la hauteur du terrain DEM. Les objets sont visuels ; ils ne commandent pas encore la circulation des véhicules.
