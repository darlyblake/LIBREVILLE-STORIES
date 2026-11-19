# Générateur cartographique

Le dépôt contient un premier jeu de données OpenStreetMap contrôlé dans `data/osm/`.

- `roads.geojson` : lignes de routes et chemins.
- `buildings.geojson` : empreintes de bâtiments.
- `extraction-report.json` : compteurs, emprise et attribution.

## Extraction principale

Le script `extract_libreville.py` permet de rafraîchir les routes, bâtiments, points d'intérêt et données de localités avec Overpass. Il remplace les GeoJSON principaux après validation des seuils : ne pas élargir son emprise sans avoir d'abord étendu et contrôlé le modèle numérique de terrain (DEM).

## Repérage des quartiers manquants

Le script `extract_locality_candidates_extended.py` effectue une recherche séparée des localités OSM nommées sur une emprise élargie (0,300–0,500° N ; 9,370–9,550° E).

Depuis la racine du dépôt, lancer :

```bash
python3 tools/map-generator/extract_locality_candidates_extended.py
```

Il crée uniquement `data/osm/locality_candidates_extended.geojson`. Il ne modifie ni les 72 secteurs actuels, ni les routes, ni les bâtiments, ni le DEM. Chaque point porte notamment :
- son identifiant et son type OSM ;
- son nom et son type de localité ;
- `inside_current_dem`, qui indique s'il tombe dans l'emprise du relief actuellement chargé.

**Important :** l'emprise élargie est une zone de recherche, pas la limite officielle de la commune. Les points hors DEM sont des candidats à étudier, pas des destinations de jeu prêtes à l'emploi. Avant leur intégration, il faut confirmer qu'ils relèvent bien de Libreville, vérifier leur arrondissement, étendre le DEM si nécessaire, puis reconstruire et contrôler les secteurs.

## Références administratives

La mairie publie des descriptions textuelles des limites des six arrondissements, notamment :
- [Premier arrondissement](https://libreville.ga/municipalite/premier-arrondissement/)
- [Deuxième arrondissement](https://libreville.ga/municipalite/deuxieme-arrondissement/)
- [Troisième arrondissement](https://libreville.ga/municipalite/troisieme-arrondissement/)
- [Quatrième arrondissement](https://libreville.ga/municipalite/quatrieme-arrondissement/)
- [Cinquième arrondissement](https://libreville.ga/municipalite/cinquieme-arrondissement/)
- [Sixième arrondissement](https://libreville.ga/municipalite/sixieme-arrondissement/)

Ces descriptions aident à vérifier les rattachements, mais ne constituent pas des fichiers de polygones SIG téléchargeables. Les secteurs doivent rester provisoires tant que leurs positions et limites ne sont pas contrôlées.

La génération 3D est réalisée par `game/scripts/world_map.gd`. Le script construit des meshes groupés à partir des GeoJSON.

Source et attribution des données OSM : © OpenStreetMap contributors — ODbL 1.0.
