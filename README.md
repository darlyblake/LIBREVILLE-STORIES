# LIBREVILLE STORIES

Jeu PC 3D en monde ouvert inspiré de Libreville, au Gabon.

## Vision

Créer progressivement une ville explorable en 3D, avec une ambiance semi-réaliste et une carte inspirée des quartiers de Libreville. Le développement commence par l'exploration à pied ; véhicules, missions et activités viendront ensuite.

## Technologie et cible

- **Moteur :** Godot 4
- **Rendu :** Compatibility (OpenGL), pour les cartes graphiques modestes
- **Résolution de travail initiale :** 1280 × 720
- **Carte :** géométries OpenStreetMap converties en meshes 3D regroupés
- **Optimisation :** matériaux simples, meshes regroupés et possibilité de limiter le nombre de bâtiments affichés

## Première zone prévue

Centre-ville, Louis, Glass, Nombakélé, Mont-Bouët, Nkembo et Akébé.

Ces noms définissent le périmètre de travail. La zone technique actuelle est une emprise rectangulaire provisoire autour de Libreville ; elle ne constitue pas une limite administrative officielle ni une reproduction certifiée des quartiers.

## État du projet

- [x] Dépôt Godot initialisé
- [x] Contrôles de déplacement et caméra de troisième personne
- [x] Première extraction OpenStreetMap contrôlée : 4 503 voies et 49 359 empreintes de bâtiments
- [x] Générateur Godot des routes et bâtiments 3D ajouté
- [x] Fichiers GeoJSON vérifiés et intégrés dans le dépôt : 4 503 voies, 49 359 bâtiments, 2 595 POI et 256 éléments environnementaux
- [x] Couche dédiée aux noms OSM de localités/quartiers (`localities.geojson`) ajoutée au moteur ; extraction fraîche en cours après fusion
- [x] Attribution OpenStreetMap affichée dans la scène
- [x] Première passe de détails de façades (fenêtres et portes stylisées) regroupés en meshes ; validation Godot CI en cours sur la PR dédiée
- [x] Liste de contrôle de finalisation de la carte : [docs/MAP_COMPLETION_CHECKLIST.md](docs/MAP_COMPLETION_CHECKLIST.md)
- [x] Validation Godot 4.3 sous OpenGL Compatibility (Mesa/llvmpipe) : scène chargée et 4 503 routes + 49 359 bâtiments générés
- [x] Première découpe de gameplay intégrée : 72 secteurs de quartiers et 6 regroupements d'arrondissement ; 13 frontières communes alignées sur des routes OSM et 2 sur des éléments naturels
- [x] Référentiel des quartiers confronté à la loi n°020/2025 du 27 juin 2025 ; huit rattachements corrigés et registre des noms manquants créé dans `data/osm/REFERENTIEL_QUARTIERS_2025.json`
- [ ] Compléter les points et polygones des quartiers cités par le référentiel 2025 mais absents des 72 secteurs OSM actuels ; les listes officielles ne constituent pas des géométries SIG
- [x] Téléporteurs contrôlés par les polygones de gameplay : exclusion du repère « Libreville », vérification de l'appartenance au quartier, marge de sécurité dans la carte et conversion du repère local vers le repère global
- [ ] Vérification visuelle des contours dans QGIS et Godot sur le PC cible ; les limites restent provisoires et non officielles
- [ ] Test de déplacement/atterrissage après téléportation et mesure des performances dans Godot sur le PC cible
- [ ] Relief (Copernicus GLO-30 candidat, DSM et non terrain nu), surface océan/mer, mobilier urbain et façades détaillées
- [ ] Chargement par secteurs et optimisation avancée

## Lancer le projet

1. Installer Godot 4.3 ou une version 4.x compatible.
2. Cloner le dépôt.
3. Ouvrir le dossier du projet dans Godot.
4. Lancer la scène principale avec F6/F5.

Les données cartographiques doivent être présentes dans `data/osm/roads.geojson`, `data/osm/buildings.geojson`, `data/osm/pois.geojson`, `data/osm/environment.geojson` et `data/osm/localities.geojson`. Si elles ne sont pas encore dans le dépôt, télécharger l'artefact « libreville-osm-extraction » depuis l'onglet Actions du dépôt et placer les deux fichiers dans `data/osm/`.

## Attribution et licence des données

Les géométries de base proviennent d'OpenStreetMap et sont soumises à l'ODbL 1.0. Attribution à afficher dans le jeu et ses crédits : **© OpenStreetMap contributors**. Les données OSM ne fournissent pas systématiquement les hauteurs, les niveaux, les détails de façade ni les limites exactes des quartiers. Les hauteurs générées dans le prototype sont des estimations visuelles, pas des mesures réelles.

## Contributions

Les changements sont réalisés sur `main` avec des commits ciblés. Toute version de carte doit être vérifiée dans Godot avant d'être déclarée jouable.
