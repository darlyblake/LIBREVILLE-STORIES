# Audit technique — refactorisation de world_map.gd

Date : 24 novembre 2026  
Moteur cible : Godot 4.3

## Décision

Ne pas réécrire le générateur de monde en une seule opération. Le script contient déjà plusieurs mécanismes de limitation de charge : génération des routes et bâtiments en lots, limitation de rayon autour du joueur, terrain en chunks, file de construction du terrain et matériaux partagés. Toute extraction doit conserver ces mécanismes et leurs paramètres.

Ce document est un relevé d'architecture. Il ne modifie aucun comportement du jeu.

## Carte des responsabilités observées

| Zone approximative | Responsabilité |
|---|---|
| 1–320 | Orchestration du monde et HUD de position |
| 320–750 | Lecture du DEM, altitude et streaming du terrain |
| 750–1025 | Sol, eau générale, matériaux et lecture GeoJSON |
| 1025–1948 | Environnement, littoral, Baie des Rois et végétation |
| 1949–2323 | Quartiers et matériaux de chaussée |
| 2324–3798 | Réseau routier : surfaces, trottoirs, collisions, lampadaires, intersections et marquages |
| 3799–4019 | Bâtiments et restaurants de la Baie des Rois |
| 4020–4217 | Localités, destinations et POI |
| 4218–4813 | Conversion géographique et construction détaillée des bâtiments |

## API inter-scripts à préserver

L'inspection de la scène principale et des scripts associés a révélé trois méthodes publiques consommées par d'autres scripts :

| Méthode | Consommateur | Usage |
|---|---|---|
| `is_terrain_ready()` | `baie_des_rois.gd` | Attend la construction du relief avant de placer les éléments du front de mer |
| `terrain_height_at_world(x, z)` | `baie_des_rois.gd`, `libreville_landmarks.gd` | Récupère l'altitude pour placer les objets |
| `get_locality_destinations()` | `teleport_panel.gd` | Fournit les destinations du panneau de téléportation |

Le nœud `WorldMap` est référencé dans `game/scenes/main.tscn`. Ces méthodes forment une API inter-scripts : elles ne doivent ni être renommées ni disparaître. Si leur logique est déplacée, conserver des méthodes relais sur `WorldMap`.

## Dépendances transversales

- Le terrain lit les données de dégagement routier avant de créer les chunks.
- Les collisions proches du terrain doivent être prêtes avant de réactiver la physique du joueur et du véhicule.
- Le réseau routier partage des grilles de proximité, des matériaux, des données de jonction et des fonctions d'altitude.
- Les bâtiments et les routes utilisent les mêmes conversions GeoJSON vers coordonnées du monde.
- Les objets de la Baie des Rois dépendent de zones géographiques explicites et de scènes d'assets existantes.
- Le HUD utilise les localités chargées pour afficher le nom de la zone proche.
- Les matériaux et surfaces partagés doivent rester mutualisés pour limiter les draw calls et la mémoire GPU.

## Ordre de refactorisation recommandé

1. Sécuriser les contrats publics et relever les ressources chargées dynamiquement.
2. Extraire les conversions géographiques et fonctions mathématiques réellement pures.
3. Extraire le HUD de localisation sans changer son affichage.
4. Extraire la génération des bâtiments avec injection explicite des matériaux, altitudes, coordonnées et scènes.
5. Extraire le réseau routier ensuite : c'est la partie la plus couplée.
6. Extraire l'environnement, le littoral et la végétation.
7. Extraire le streaming du terrain en dernier, car il contrôle les collisions et la disponibilité du sol sous le joueur.

## Contrôles obligatoires

- Parse des scripts sous Godot 4.3 et démarrage de la scène principale.
- Joueur et véhicule restent sur le relief, y compris près de la côte.
- Routes, intersections, trottoirs, marquages et collisions sont conservés.
- Bâtiments, toitures et restaurants de la Baie des Rois restent visibles.
- Le chargement des chunks et des lots reste progressif.
- Aucun rayon, quota de génération ou réglage graphique n'est modifié sans mesure préalable.
- Comparer les logs, temps de démarrage et mémoire sur la machine de référence, notamment la configuration GT 730.

## Hors périmètre

- Pas de modification des GeoJSON ou du DEM.
- Pas de déplacement ou renommage des modèles 3D et textures.
- Pas de changement des coordonnées, rayons, tailles de lots ou paramètres de streaming.
- Pas de réécriture de l'historique Git ni de migration Git LFS sans décision dédiée.
- Pas d'ajout de licence sans confirmation du titulaire et du texte souhaité.

## Conclusion

`world_map.gd` est un orchestrateur et générateur multi-sous-systèmes d'environ 4 800 lignes. Le découpage doit se faire progressivement avec injection explicite des dépendances pour éviter les références implicites, les duplications de matériaux et les régressions sur le monde ouvert.
