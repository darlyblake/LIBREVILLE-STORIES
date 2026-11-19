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

## Génération du nouveau terrain régional

Le générateur séparé `generate_extended_dem.py` construit une grille SRTM1 d'environ 30 m couvrant l'emprise de travail 0,300–0,500° N et 9,370–9,550° E. Cette emprise est volontairement régionale : elle permet d'englober les nouveaux points du nord et de l'est, mais elle ne représente pas une limite administrative officielle et peut inclure des zones voisines.

### Génération automatique

Le workflow GitHub Actions `.github/workflows/generate-extended-terrain.yml` démarre lorsqu'on modifie le générateur sur `main`. Il télécharge la tuile SRTM1 `N00E009`, crée les deux fichiers, vérifie leur taille, puis publie une archive d'artefact nommée `libreville-terrain-etendu-srtm1`.

Pour récupérer les fichiers :
1. ouvrir l'onglet **Actions** du dépôt ;
2. ouvrir l'exécution **Generate extended Libreville terrain** ;
3. attendre que le travail **generate-dem** soit terminé avec succès ;
4. télécharger l'artefact **libreville-terrain-etendu-srtm1**.

Les fichiers produits sont :
- `libreville_dem_extended.json`
- `libreville_dem_extended_f32.bin`

### Génération locale (facultative)

Installer les dépendances puis lancer depuis la racine du dépôt :

```bash
python3 -m pip install numpy rasterio
python3 tools/map-generator/generate_extended_dem.py
```

### Important avant intégration au jeu

Le DEM étendu est produit sous des noms distincts. Il ne remplace pas `libreville_dem.json` ni `libreville_dem_f32.bin`, et le jeu continue donc d'utiliser le terrain actuel tant que l'intégration n'est pas faite. Il faudra ensuite vérifier le repère local, le placement du joueur, les collisions, les limites invisibles et la cohérence des couches OSM dans Godot. La nouvelle emprise ne doit pas être présentée comme une extension officielle de la commune.

## Résultat du DEM régional généré (19 novembre 2026)

La génération GitHub Actions a réussi et les fichiers sont maintenant enregistrés à la racine du dépôt :
- `libreville_dem_extended.json`
- `libreville_dem_extended_f32.bin`

Contrôles effectués sur l'artefact généré :
- grille : **668 colonnes × 743 lignes** ;
- pas annoncé : **30 m** ;
- binaire : **1 985 296 octets**, soit exactement 668 × 743 × 4 ;
- altitudes observées : **-10,45 m à 120,28 m** ;
- aucune cellule NoData dans la grille finale ;
- plage d'altitudes cohérente avec le relief connu de la zone.

Le commit de données est `002027fb6b3abc2995a0d2f1d941a6ff5c05543a`.

**État d'intégration :** le nouveau DEM est généré, contrôlé et versionné, mais le jeu utilise encore l'ancien DEM. Les couches routes, bâtiments, végétation, POI et localités doivent être extraites dans la même emprise élargie, puis contrôlées ensemble. Les polygones de quartiers et les limites d'arrondissements ne doivent pas être inventés à partir du seul relief.

