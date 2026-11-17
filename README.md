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
- [ ] Nouvelle extraction découpée en neuf tuiles et intégration automatique des fichiers dans le dépôt
- [ ] Test d'ouverture et de performance dans Godot sur le PC cible
- [ ] Relief, littoral, végétation, mobilier urbain et bâtiments détaillés
- [ ] Chargement par secteurs et optimisation avancée

## Lancer le projet

1. Installer Godot 4.3 ou une version 4.x compatible.
2. Cloner le dépôt.
3. Ouvrir le dossier du projet dans Godot.
4. Lancer la scène principale avec F6/F5.

Les données cartographiques doivent être présentes dans `data/osm/roads.geojson` et `data/osm/buildings.geojson`. Si elles ne sont pas encore dans le dépôt, télécharger l'artefact « libreville-osm-extraction » depuis l'onglet Actions du dépôt et placer les deux fichiers dans `data/osm/`.

## Attribution et licence des données

Les géométries de base proviennent d'OpenStreetMap et sont soumises à l'ODbL 1.0. Attribution à afficher dans le jeu et ses crédits : **© OpenStreetMap contributors**. Les données OSM ne fournissent pas systématiquement les hauteurs, les niveaux, les détails de façade ni les limites exactes des quartiers. Les hauteurs générées dans le prototype sont des estimations visuelles, pas des mesures réelles.

## Contributions

Les changements sont réalisés sur `main` avec des commits ciblés. Toute version de carte doit être vérifiée dans Godot avant d'être déclarée jouable.
