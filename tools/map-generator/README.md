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

### Intégration progressive dans Godot

Le script `game/scripts/world_map.gd` charge maintenant automatiquement le DEM étendu lorsqu'il trouve ensemble `libreville_dem_extended.json` et `libreville_dem_extended_f32.bin`. Si l'un des deux fichiers manque, il conserve l'ancien DEM. Le repère local reste centré sur 0,400° N / 9,4475° E, conformément aux métadonnées du nouveau relief.

Pour les couches OSM, le chargeur privilégie `data/osm/extended/` lorsqu'un fichier étendu existe, avec repli vers `data/osm/` pour les fichiers absents. Exception volontaire : `neighbourhoods.geojson` continue d'utiliser les quartiers historiques tant que les nouveaux polygones n'ont pas été vérifiés. Les données des six arrondissements ne sont pas remplacées.

Le parseur Godot a réussi le contrôle automatisé après ces changements. Cela confirme la syntaxe et l'import du projet, pas encore le rendu visuel, les collisions en jeu ni le fonctionnement du téléporteur. Ces contrôles nécessitent un lancement réel dans Godot.

La nouvelle emprise ne doit pas être présentée comme une extension officielle de la commune.

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

**État d'intégration :** le jeu sait désormais charger le DEM étendu automatiquement, tout en gardant l'ancien DEM comme secours. Les couches routes, bâtiments, environnement, POI et localités sont en cours d'extraction dans `data/osm/extended/`. Elles ne seront utilisées qu'après validation du workflow. Les quartiers historiques restent actifs et les limites d'arrondissements ne sont pas remplacées ni inventées.

