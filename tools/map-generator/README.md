# Extraction cartographique de Libreville

Premier outil de récupération des **routes** et des **empreintes de bâtiments** OpenStreetMap dans l'emprise provisoire du jeu.

## Lancer sous Windows

1. Installer Python 3 en cochant « Add Python to PATH ».
2. Ouvrir PowerShell dans le dossier du dépôt.
3. Exécuter :

```powershell
py tools/map-generator/extract_libreville.py
```

Le script utilise uniquement Python (aucun paquet à installer). Il tente plusieurs serveurs Overpass en cas d'indisponibilité.

## Résultats

Les fichiers sont créés localement dans `data/osm/` :
- `roads.geojson` : lignes des objets portant le tag OSM `highway`.
- `buildings.geojson` : polygones des objets portant le tag OSM `building`.
- `extraction-report.json` : date, emprise, nombre d'objets et catégories.

Les fichiers de données générés sont ignorés par Git pour ne pas alourdir le dépôt.

## Emprise provisoire

BBOX Overpass (sud, ouest, nord, est) : `0.355, 9.400, 0.445, 9.495`. C'est une zone technique de départ, pas une frontière administrative officielle.

Pour modifier les limites :

```powershell
py tools/map-generator/extract_libreville.py --south 0.355 --west 9.400 --north 0.445 --east 9.495
```

## Limites de cette première extraction

- Cette version récupère les objets OSM de type `way`. Les bâtiments présents uniquement dans des relations multipolygones seront ajoutés lors d'une étape suivante.
- OSM n'est pas exhaustif : des bâtiments et chemins peuvent manquer.
- Les coordonnées GeoJSON sont en WGS84 (longitude, latitude) ; elles devront être converties en coordonnées locales métriques avant la génération 3D dans Godot.
- Attribution obligatoire dans le jeu : **© OpenStreetMap contributors**. Données sous licence ODbL.

Documentation : https://wiki.openstreetmap.org/wiki/Overpass_API
