# Générateur cartographique

Le dépôt contient un premier jeu de données OpenStreetMap contrôlé dans `data/osm/`.

- `roads.geojson` : lignes de routes et chemins.
- `buildings.geojson` : empreintes de bâtiments.
- `extraction-report.json` : compteurs, emprise et attribution.

## Extraction principale

Le script `extract_libreville.py` permet de rafraîchir les routes, bâtiments, points d'intérêt et données de localités avec Overpass. Il remplace les GeoJSON principaux après validation des seuils : ne pas élargir son emprise sans avoir d'abord étendu et contrôlé le modèle numérique de terrain (DEM).

## Points de localités supplémentaires déjà vérifiés

Le fichier `data/osm/locality_candidates_verified.geojson` contient six points de localités OSM absents du fichier de localités actuel :

- Aéroport
- Okala
- Alibandeng
- Mikolongo
- Tahiti
- Ondogo

Les cinq premiers sont rattachés au 1er arrondissement dans le référentiel 2025. Ondogo reste volontairement sans arrondissement : la référence distingue Ondogo 1 GR et Ondogo 2, et le point OSM générique ne permet pas de savoir lequel il représente.

Les coordonnées et identifiants OSM sont documentés dans les propriétés GeoJSON, avec la page de source de chaque point. Ces points sont des **candidats**, pas des polygones de quartiers ni des téléporteurs.

## Repérage élargi par Overpass

Le script `extract_locality_candidates_extended.py` effectue une recherche séparée des localités OSM nommées sur une emprise élargie (0,300–0,500° N ; 9,370–9,550° E).

Depuis la racine du dépôt, lancer :

```bash
python3 tools/map-generator/extract_locality_candidates_extended.py
```

Il crée uniquement `data/osm/locality_candidates_extended.geojson`. Il ne modifie ni les 72 secteurs actuels, ni les routes, ni les bâtiments, ni le DEM. Chaque point porte notamment son identifiant OSM, son nom et `inside_current_dem`.

## Extension du terrain : étape obligatoire avant intégration

Le DEM actuel couvre environ 0,354461–0,445539° N et 9,399461–9,495539° E. Les six points du fichier vérifié sont tous hors de cette emprise. Il ne faut donc pas les ajouter au monde jouable tant que le DEM, ses métadonnées et son fichier binaire n'ont pas été régénérés ensemble.

L'emprise de recherche élargie n'est pas une limite administrative. Avant intégration, il faut confirmer la commune, vérifier les limites des arrondissements, étendre le DEM, puis étendre ensemble routes, bâtiments, environnement, points d'intérêt et polygones de quartiers. Les collisions et les limites invisibles du terrain dans Godot devront aussi être recalculées.

## Références administratives

La mairie publie des descriptions textuelles des limites des six arrondissements :
- [Premier arrondissement](https://libreville.ga/municipalite/premier-arrondissement/)
- [Deuxième arrondissement](https://libreville.ga/municipalite/deuxieme-arrondissement/)
- [Troisième arrondissement](https://libreville.ga/municipalite/troisieme-arrondissement/)
- [Quatrième arrondissement](https://libreville.ga/municipalite/quatrieme-arrondissement/)
- [Cinquième arrondissement](https://libreville.ga/municipalite/cinquieme-arrondissement/)
- [Sixième arrondissement](https://libreville.ga/municipalite/sixieme-arrondissement/)

Ces descriptions aident à vérifier les rattachements, mais ne constituent pas des fichiers de polygones SIG téléchargeables. Les secteurs doivent rester provisoires tant que leurs positions et limites ne sont pas contrôlées.

La génération 3D est réalisée par `game/scripts/world_map.gd`. Le script construit des meshes groupés à partir des GeoJSON.

Source et attribution des données OSM : © OpenStreetMap contributors — ODbL 1.0.
