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
- [x] Réduire la hauteur et la taille des étiquettes 3D pour limiter l'effet d'objets flottants ; inspection visuelle en jeu encore requise.
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
- [ ] Corriger les objets réellement flottants après inspection de leurs coordonnées et de leur ancrage (les étiquettes 3D ont déjà été abaissées, mais les autres cas restent à diagnostiquer).
- [x] Première variété de matériaux procéduraux : tuiles, tôle nervurée et dalle béton, sélectionnés par typologie OSM (approximation visuelle).
- [x] Première toiture géométrique à deux pans sur les petites maisons OSM aux empreintes quadrilatérales convexes et allongées ; les bâtiments complexes conservent un toit plat.
- [ ] Étendre et affiner les profils de toitures inclinées (4 pans, formes complexes) selon des références architecturales locales.
- [x] Première passe de balcons stylisés sur certains immeubles à plusieurs niveaux, regroupés dans le mesh des façades.
- [ ] Ajouter auvents, escaliers et autres détails seulement là où le type et la taille du bâtiment le permettent.
- [ ] Mieux gérer les cours intérieures et trous dans les empreintes polygonales.
- [ ] Affiner les typologies architecturales locales à partir de photos/références vérifiables ; ne pas uniformiser toutes les constructions.

## 3. Relief, mer et environnement
- [ ] Intégrer un modèle d'élévation adapté et vérifier son système de coordonnées, sa couverture et sa résolution.
- [ ] Distinguer relief du sol et hauteur des bâtiments ; un DSM ne doit pas être pris pour un terrain nu.
- [x] Première représentation visuelle du tracé côtier OSM par une bande littorale couleur sable ; validation Godot 4.3 réussie sur `main` (ce n'est pas encore une surface mer/terre).
- [ ] Construire une surface mer/terre fiable à partir d'une géométrie côtière cohérente ; les lignes de côte seules ne suffisent pas.
- [ ] Ajouter plages, mangroves, rivières et zones humides lorsque les données sont vérifiées.
- [x] Première végétation 3D low-poly instanciée dans les espaces verts OSM (plafond 1 200, PR n°17 validée Godot 4.3) ; inspection visuelle et densité à confirmer.

## 4. Routes, mobilier et navigation
- [x] Hiérarchie de largeur et de couleur des routes selon leur catégorie OSM.
- [x] Lecture des tags OSM `width`, `lanes` et `surface` pour adapter largeur et revêtement lorsque ces informations existent.
- [x] Première fermeture des trous aux carrefours avec des raccords de chaussée légers sur les nœuds OSM partagés ; géométrie encore schématique, pas un vrai dessin de carrefour.
- [x] Étiquettes limitées des axes et des lieux importants.
- [ ] Vérifier les intersections complexes, ponts, voies à sens unique et connexions des routes ; les raccords circulaires ajoutés ne remplacent pas une modélisation de carrefour.
- [x] Première passe de trottoirs 3D regroupés sur les grands axes et lorsque les tags OSM indiquent leur présence (PR n°14 fusionnée, validation Godot 4.3 réussie).
- [x] Premier marquage axial discontinu sur les axes structurants et voies explicitement à plusieurs voies (PR n°16, approximation visuelle, validation Godot 4.3).
- [x] Première génération de passages piétons schématiques aux extrémités de routes OSM structurantes connectées à trois segments ou plus (approximation, validation Godot 4.3 réussie sur `main`).
- [ ] Ajouter carrefours détaillés, ponts, signalisation et mobilier urbain à partir de données ou d'approximations visuelles signalées.
- [x] Première mini-carte nord en haut : routes OSM rasterisées et repère de position du joueur (PR n°18 fusionnée, validation Godot 4.3 réussie).
- [x] Première superposition des POI importants sur la mini-carte (santé, écoles, services publics, commerces, tourisme ; validation Godot 4.3 réussie sur `main`).
- [ ] Ajouter la navigation avec itinéraires et découverte interactive des POI.
- [x] Première prise en charge logicielle des manettes : stick gauche, croix directionnelle, bouton A pour sauter et stick droit pour la caméra ; test avec une manette physique encore requis.

## 5. Performance et validation
- [x] Regroupement des routes et bâtiments en meshes pour réduire les draw calls.
- [x] Validation automatique Godot 4.3 sous rendu Compatibility passée après les améliorations de largeur, surface et raccords routiers (workflow `44160434574`, commit de base `3cc0325`). Le dernier ajustement d'orientation des faces a été ajouté ensuite et reste à confirmer par un nouveau rendu.
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

## 7. Recherche documentaire et sources de référence (17/11/2026)
- [x] Documentation officielle Godot consultée pour les manettes : axes analogiques via Input.get_vector, zone morte et gestion des événements de manette.
- [x] Mairie de Libreville consultée : la commune comporte six arrondissements et publie des descriptions de délimitations ; ces descriptions doivent être converties en géométries vérifiables avant affichage.
- [x] Recherche complémentaire : la Banque mondiale décrit 89 unités de quartier numérotées issues d'un travail de superposition de cartes et de secteurs de recensement ; elles ne sont pas des limites officielles de quartiers nommés.
- [x] Références photographiques repérées : Wikimedia Commons (scènes de rues de Libreville) et Service audiovisuel de l'Union européenne (36 photos de Libreville).
- [x] Sources d'imagerie et de relief repérées : Sentinel-2 (10 m) et Copernicus DEM GLO-30 (30 m) ; résolution utile pour occupation du sol et relief général, insuffisante pour reconstruire les façades individuelles.
- [ ] Vérifier les licences image par image avant toute intégration dans le jeu ; les photos de référence ne sont pas automatiquement libres de réutilisation.
- [ ] Acquérir et intégrer une couche d'élévation, puis produire une surface mer/terre à partir d'une géométrie côtière fiable.
- [ ] Obtenir les géométries administratives des six arrondissements depuis la mairie ou une source officielle et documenter leur système de coordonnées.
- [ ] Définir des profils architecturaux distincts à partir des références visuelles (habitat individuel, habitat spontané, immeubles, commerces, bâtiments publics) plutôt que d'appliquer une texture unique à toute la ville.


### Références visuelles complémentaires consultées
- Wikimedia Commons, catégories Streets in Libreville et Street scenes in Libreville : photographies de rues, marché, boulevard du bord de mer et scènes urbaines ; vérifier chaque licence avant intégration.
- Service audiovisuel de l'Union européenne, reportage Libreville (P-060454, 27/02/2023) : 36 photographies de vues générales, rues, bâtiments officiels et religieux.
- Rapport ONU Gabon 2021 : vue aérienne montrant le mélange de bâtiments résidentiels/administratifs, végétation tropicale, grands axes et littoral.
- Étude sur les typologies d'habitat de l'agglomération : coexistence de villas, immeubles, logements sociaux et habitat spontané ; les styles doivent varier par secteur et non être uniformisés.
- Ces références guident la direction artistique, mais ne remplacent pas un relevé architectural géolocalisé ni une licence d'utilisation des photographies.
