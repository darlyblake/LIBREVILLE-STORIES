# Périmètre cartographique — version 0.3

## Objectif
Construire une représentation jouable de Libreville et de ses environs à partir de données géographiques réelles, sans inventer les tracés des routes ni la position des bâtiments.

## Emprise provisoire
L'extraction utilise la boîte sud/ouest/nord/est suivante : 0.355, 9.400, 0.445, 9.495. Cette emprise technique couvre une partie de Libreville et de ses environs ; elle ne constitue pas une limite administrative officielle des quartiers.

## Données OpenStreetMap
La chaîne d'extraction découpe la zone en 16 secteurs, conserve les propriétés OSM, met les réponses en cache et prévoit un repli vers le PBF du Gabon de Geofabrik. Les couches suivies sont :
- roads.geojson : axes routiers, catégories highway, noms de voies lorsqu'ils sont renseignés.
- buildings.geojson : empreintes des bâtiments et tags descriptifs disponibles.
- pois.geojson : lieux nommés ponctuels (équipements, commerces, santé, éducation, tourisme, transports, lieux historiques et services).

Source : OpenStreetMap contributors, licence ODbL 1.0. Attribution à afficher dans le jeu et les crédits : « © OpenStreetMap contributors ».

## Identification en jeu
Les noms de rues présents dans OSM sont affichés sur un nombre limité d'axes pour éviter de surcharger l'écran. Les lieux nommés sont affichés avec une couleur indicative selon leur catégorie (santé, éducation, administration, commerce, tourisme). Les catégories et noms sont ceux fournis par la base ; un lieu absent ou non renseigné dans OSM ne doit pas être inventé.

## Fidélité géométrique et limites connues
- Les positions et contours des routes et bâtiments proviennent des géométries OSM.
- Les hauteurs de bâtiments restent approximatives lorsque height ou building:levels ne sont pas renseignés.
- Les volumes sont des extrusions simples, pas des façades ou modèles architecturaux fidèles.
- Les polygones avec cours intérieures (trous) ne sont pas encore modélisés correctement.
- Le relief, les plages, le trait de côte détaillé, les mangroves, les cours d'eau et les limites officielles des quartiers restent à intégrer/valider avec des sources adaptées.
- La présence d'un lieu dans OSM ne garantit pas que son nom, son activité ou son état actuel soit encore exact. Une vérification terrain ou une source officielle est nécessaire pour les lieux sensibles/importants.

## Étapes de précision
1. Valider les couches routes, bâtiments et lieux nommés après extraction.
2. Ajouter les limites et noms de quartiers depuis une source administrative fiable.
3. Ajouter le relief, le littoral, l'hydrographie et les espaces naturels.
4. Améliorer l'architecture des bâtiments uniquement avec des références vérifiables (photos, hauteurs, niveaux, typologies).
5. Créer le chargement spatial par secteurs et mesurer les performances sur la machine cible.

## Tests
Les validations automatisées vérifient les GeoJSON, les géométries, les attributs et le chargement de la scène Godot. Elles ne remplacent pas une inspection visuelle, une vérification terrain, ni un test FPS sur la machine cible.
