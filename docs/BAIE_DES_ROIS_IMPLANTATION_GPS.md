# Implantation GPS — kiosques de la Baie des Rois

## Références prioritaires

- Les captures `Capture7.PNG`, `Capture8.PNG` et `Capture9.PNG` du dossier `assets/models/image geographique/` restent les références prioritaires pour l'implantation des kiosques. La capture 7 représente notamment les deux rangées qui se font face.
- Les photos publiques de la promenade de la Baie des Rois servent de références architecturales et paysagères : dallage clair, pelouses en îlots, palmiers espacés, mobilier urbain discret, garde-corps ajourés et kiosques/pavillons en bois.
- Les données `data/osm/environment.geojson` du projet apportent des géométries locales du littoral et des espaces verts. Elles doivent primer sur les anciens placements décoratifs approximatifs lorsqu'elles couvrent la zone.

## Coordonnées GPS communiquées

Les trois coordonnées sont exprimées en latitude, longitude (WGS84).

| Repère | Latitude | Longitude | Rôle |
|---|---:|---:|---|
| P1 | 0.40392567507842964 | 9.431029723961437 | Premier kiosque de la rangée A |
| P2 | 0.4038486056410187 | 9.430125017741204 | Dernier kiosque communiqué de la même rangée A |
| P3 | 0.403847888849537 | 9.431017268453365 | Point supposé sur la rangée opposée |

## Conversion avec le repère de world_map.gd

La conversion reprend exactement les constantes du projet : `CENTER_LAT = 0.400`, `CENTER_LON = 9.4475` et `METERS_PER_DEG_LAT = 111320.0`.

| Repère | X monde (m) | Z monde (m) |
|---|---:|---:|
| P1 | -1833.43 | -437.01 |
| P2 | -1934.14 | -428.43 |
| P3 | -1834.81 | -428.35 |

**Correction importante :** ces valeurs recalculées remplacent les conversions erronées données dans un précédent message.

## Géométrie des deux rangées

- La distance P1–P2 est d'environ **101,1 m**.
- L'axe de la rangée A est presque ouest-est, avec une légère composante nord-sud.
- P3 est à environ **8,77 m** de P1.
- En projetant P3 perpendiculairement à l'axe P1–P2, l'écartement indicatif entre les axes des rangées est d'environ **8,51 m**.
- Cette valeur est une estimation issue du point P3, pas une mesure certifiée de la largeur de la chaussée.
- Le helper `game/scripts/baie_des_rois_survey.gd` applique actuellement un recul provisoire de 3 m vers l'extérieur à chaque rangée. Ce recul n'est pas encore validé visuellement.

## Premiers constats issus du GeoJSON environnemental

Le fichier `data/osm/environment.geojson` a été examiné autour des coordonnées P1, P2 et P3, avec le même repère métrique que `world_map.gd`.

- Le segment de littoral OSM le plus proche est l'entité `way/443854943` (`natural=coastline`, source indiquée : Mapbox + Landsat8).
- La distance minimale calculée entre ce littoral et les trois repères est d'environ **29 à 38 m**. Les points de littoral les plus proches se trouvent dans la direction du **+Z monde** par rapport aux kiosques.
- Plusieurs polygones OSM de type `vegetation` / `landuse=grass` sont présents à proximité. Le fichier comprend notamment les entités `way/1070652050`, `way/1070652051`, `way/1070652052`, `way/1070652053` et `way/1070652055`.
- Ces polygones sont déjà chargés par `world_map.gd` dans `_load_environment()`. Il faut donc éviter de créer par-dessus des rectangles de pelouse inventés qui pourraient masquer ou contredire les formes cartographiées.
- Le littoral OSM est une ligne de référence cartographique, pas une mesure de la limite exacte du dallage ou de la promenade. Il ne suffit pas à déterminer la largeur des trottoirs.

## État actuel du code à surveiller

- `game/scripts/baie_des_rois.gd` instancie actuellement quatre kiosques par rangée, soit huit au total, aux progressions `[0.08, 0.36, 0.64, 0.92]`.
- Les rotations de façade ont été inversées pour essayer d'orienter les ouvertures vers le passage central. Cette orientation reste à confirmer visuellement dans Godot.
- Le mobilier est actuellement placé par décalages fixes : palmiers à 7,2 m, lampadaires à 5,7 m et bancs à 6 m des axes de rangée. Ces valeurs sont provisoires et ne prouvent pas que les objets sont hors de la chaussée ou du trottoir.
- Les anciens générateurs de promenade, d'eau, de pelouse et de mobilier dans `baie_des_rois.gd` sont des placeholders historiques. Ils ne doivent pas être réactivés sans reconstruction géométrique adaptée.

## Règles de reconstruction

1. Conserver les coordonnées GPS et l'alignement longitudinal des deux rangées.
2. Garder le passage client central entièrement libre ; les façades commerciales doivent être tournées vers ce passage.
3. Reculer les kiosques vers les emplacements réellement occupés sur le terrain, sans les poser sur la route ni sur le trottoir.
4. Construire séparément chaussée, trottoirs/dallage, pelouses et bordures. Ne pas utiliser un grand rectangle unique pour toute la promenade.
5. Utiliser les polygones OSM existants pour les pelouses lorsqu'ils correspondent à la zone ; compléter uniquement les manques confirmés.
6. Placer palmiers, bancs et lampadaires dans les espaces paysagers ou les bandes extérieures, jamais au milieu du cheminement piéton.
7. Garder des garde-corps ajourés près du bord d'eau lorsque les références photographiques et la géométrie locale le justifient.
8. Distinguer les éléments réellement visibles sur les photos de la zone des projets ou aménagements annoncés pour d'autres secteurs de la Baie des Rois.
9. Optimiser les meshes et matériaux pour la cible modeste du projet (GT 730 2 Go) : peu de matériaux, géométries groupées et végétation légère.

## Ce qui reste à confirmer avant de figer les positions

- La limite exacte de la route et des trottoirs au droit des kiosques.
- Le côté précis de chaque bande paysagère et la largeur des zones pavées.
- L'orientation finale des façades des GLB dans le jeu.
- La correspondance définitive de P3 avec le centre du kiosque opposé.
- La position exacte des bancs, lampadaires et arbres par rapport aux cheminements.

## Prochaine étape technique

Reconstituer une première section de promenade autour des deux rangées à partir des coordonnées GPS et des contours OSM, sans déplacer arbitrairement les kiosques ni poser de mobilier dans le passage. Le contrôle visuel dans Godot reste indispensable avant de considérer les positions comme validées.
