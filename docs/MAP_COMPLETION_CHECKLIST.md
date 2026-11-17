# Liste de contrôle — finalisation de la carte de Libreville

Cette liste suit uniquement les éléments vérifiés dans le dépôt et les validations CI. Une case cochée signifie que le travail existe dans le projet ; elle ne signifie pas automatiquement que le rendu a été inspecté sur le PC cible.

## 1. Base cartographique et identification
- [x] Emprise de travail définie autour de Libreville (boîte technique provisoire, pas une frontière administrative).
- [x] Extraction OpenStreetMap organisée en 16 secteurs avec cache et solution de repli Geofabrik ; 16/16 secteurs extraits et validés (4 503 routes, 49 359 bâtiments, 2 595 POI, 256 éléments environnementaux, 73 localités nommées).
- [x] Routes et empreintes de bâtiments OSM intégrées au prototype.
- [x] POI nommés et couches environnementales intégrés.
- [x] Couche séparée des localités OSM nommées (place=*) et affichage des étiquettes.
- [x] HUD de position du joueur : coordonnées et localité OSM la plus proche.
- [x] Extraction complète des 16 secteurs vérifiée et publiée sur `main` (workflow n°44149287481, 17/11/2026).
- [x] Comptes vérifiés : 4 503 routes, 49 359 bâtiments, 2 595 POI, 256 éléments environnementaux et 73 localités nommées ; 0 polygone de quartier fourni par OSM dans cette extraction.
- [ ] Vérifier visuellement les noms et leur placement dans la carte en jeu.
- [ ] Compléter les limites des quartiers avec une source administrative officielle ou vérifiable ; ne pas déduire de frontières depuis les points place=*.

## 2. Bâtiments et architecture
- [x] Volumes 3D extrudés à partir des empreintes OSM.
- [x] Hauteurs OSM utilisées lorsqu'elles sont disponibles ; estimation visuelle clairement utilisée en leur absence.
- [x] Première texture procédurale de tuiles sur les toitures.
- [x] Détails de façades regroupés en meshes : fenêtres et portes d'entrée stylisées, avec variation déterministe légère.
- [x] Validation Godot 4.3 du générateur de fenêtres/portes sur `main` (rendu Compatibility réussi).
- [x] Validation Godot 4.3 après ajout des balcons (PR n°13, rendu Compatibility réussi).
- [ ] Inspecter leur rendu en jeu sur la machine cible.
- [x] Première variété de matériaux procéduraux : tuiles, tôle nervurée et dalle béton, sélectionnés par typologie OSM (approximation visuelle).
- [x] Première toiture géométrique à deux pans sur les petites maisons OSM aux empreintes quadrilatérales convexes et allongées ; les bâtiments complexes conservent un toit plat.\n- [ ] Étendre et affiner les profils de toitures inclinées (4 pans, formes complexes) selon des références architecturales locales.
- [x] Première passe de balcons stylisés sur certains immeubles à plusieurs niveaux, regroupés dans le mesh des façades.
- [ ] Ajouter auvents, escaliers et autres détails seulement là où le type et la taille du bâtiment le permettent.
- [ ] Mieux gérer les cours intérieures et trous dans les empreintes polygonales.
- [ ] Affiner les typologies architecturales locales à partir de photos/références vérifiables ; ne pas uniformiser toutes les constructions.

## 3. Relief, mer et environnement
- [ ] Intégrer un modèle d'élévation adapté et vérifier son système de coordonnées, sa couverture et sa résolution.
- [ ] Distinguer relief du sol et hauteur des bâtiments ; un DSM ne doit pas être pris pour un terrain nu.
- [ ] Construire une surface mer/terre fiable à partir d'une géométrie côtière cohérente ; les lignes de côte seules ne suffisent pas.
- [ ] Ajouter plages, mangroves, rivières et zones humides lorsque les données sont vérifiées.
- [x] Première végétation 3D low-poly instanciée dans les espaces verts OSM (plafond 1 200, PR n°17 validée Godot 4.3) ; inspection visuelle et densité à confirmer.

## 4. Routes, mobilier et navigation
- [x] Hiérarchie de largeur et de couleur des routes selon leur catégorie OSM.
- [x] Étiquettes limitées des axes et des lieux importants.
- [ ] Vérifier les intersections, ponts, voies à sens unique et connexions des routes.
- [x] Première passe de trottoirs 3D regroupés sur les grands axes et lorsque les tags OSM indiquent leur présence (PR n°14 fusionnée, validation Godot 4.3 réussie).
- [x] Premier marquage axial discontinu sur les axes structurants et voies explicitement à plusieurs voies (PR n°16, approximation visuelle, validation Godot 4.3).
- [x] Première génération de passages piétons schématiques aux extrémités de routes OSM structurantes connectées à trois segments ou plus (approximation, validation Godot 4.3 en attente).\n- [ ] Ajouter carrefours détaillés, ponts, signalisation et mobilier urbain à partir de données ou d'approximations visuelles signalées.
- [x] Première mini-carte nord en haut : routes OSM rasterisées et repère de position du joueur (PR n°18 fusionnée, validation Godot 4.3 réussie).
- [x] Première superposition des POI importants sur la mini-carte (santé, écoles, services publics, commerces, tourisme ; validation Godot 4.3 en attente).\n- [ ] Ajouter la navigation avec itinéraires et découverte interactive des POI.

## 5. Performance et validation
- [x] Regroupement des routes et bâtiments en meshes pour réduire les draw calls.
- [x] Validation automatique Godot 4.3 sous rendu Compatibility déjà passée sur la version précédente.
- [x] Validation Godot 4.3 après fenêtres et portes (rendu Compatibility réussi).
- [x] Validation Godot 4.3 après les balcons (PR n°13, rendu Compatibility réussi).
- [x] Validation Godot 4.3 de l'atlas procédural de toitures (PR n°15 fusionnée).
- [ ] Mettre en place le chargement/déchargement spatial par secteurs.
- [ ] Mesurer FPS, mémoire et temps de chargement sur la machine cible (GT 730 2 Go) ; aucun chiffre ne doit être annoncé avant ce test.
- [ ] Vérifier les collisions et la circulation du joueur sur les routes et autour des bâtiments.
- [ ] Faire une inspection visuelle en jeu à plusieurs endroits reconnaissables de Libreville.

## 6. Finition et livraison
- [x] Attribution OpenStreetMap prévue dans la scène et les crédits.
- [ ] Vérifier les crédits et licences de chaque nouvelle source (relief, imagerie, bâtiments éventuels).
- [ ] Corriger les anomalies cartographiques repérées pendant la visite en jeu.
- [ ] Geler une version de la carte, avec rapport d'extraction, captures et résultats de tests.
- [ ] Faire valider que le joueur peut se repérer réellement : position, nom de localité, axes et lieux remarquables.

## Critère de fin de carte
La carte pourra être considérée comme prête pour la phase de jeu lorsque l'extraction est vérifiée, que les localités et les lieux remarquables sont identifiables, que mer/relief et bâtiments sont cohérents, que le joueur se repère en jeu et que les performances sont mesurées sur la machine cible. Les éléments non couverts par des données fiables devront rester explicitement présentés comme des approximations visuelles.