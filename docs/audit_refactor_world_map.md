# Audit technique — refactorisation de world_map.gd

Date : 24 novembre 2026  
Moteur cible : Godot 4.3  
Branche d'audit : `chore/assainissement-godot`

## Décision

Ne pas réécrire le générateur de monde en une seule opération. Le script actuel contient déjà plusieurs mécanismes de limitation de charge : génération des routes et bâtiments en lots, limitation de rayon autour du joueur, terrain en chunks, file de construction du terrain et matériaux partagés. Toute extraction doit conserver ces mécanismes et leurs paramètres.

Ce document est un relevé d'architecture. Il ne modifie aucun comportement du jeu.

## Carte des responsabilités observées

| Zone approximative | Responsabilité | Fonctions / éléments principaux |
|---|---|---|
| 1–320 | Orchestration du monde et HUD de position | `_ready`, `_process`, `_create_location_hud`, `_update_location_hud` |
| 320–750 | Lecture du DEM, altitude et streaming du terrain | `_load_real_terrain`, `_terrain_height_at_world`, `_update_terrain_stream`, `_build_terrain_chunk`, limites et positionnement du joueur |
| 750–1025 | Sol, eau générale, matériaux et lecture GeoJSON | `_apply_ground_surface`, `_add_ocean_plane`, `_make_environment_material`, `_read_geojson`, outils SurfaceTool |
| 1025–1948 | Environnement, littoral, Baie des Rois et végétation | `_load_environment`, `_build_baie_des_rois_water`, `_build_baie_des_rois_seawall`, détails côtiers, arbres et instances |
| 1949–2323 | Quartiers et matériaux de chaussée | chargement des quartiers, géométrie polygonale, textures et matériaux de route |
| 2324–3798 | Réseau routier complet | chargement GeoJSON, découpage en surfaces, trottoirs, collisions, lampadaires, intersections, marquages et utilitaires routiers |
| 3799–4019 | Bâtiments et restaurants de la Baie des Rois | chargement, filtrage, assemblage des bâtiments et placement des scènes de restaurants |
| 4020–4217 | Localités, destinations et POI | chargement, priorités, labels et couleurs |
| 4218–4813 | Conversion géographique et construction détaillée des bâtiments | conversion coordonnées, filtrage spatial, dimensions, couleurs, toitures, fenêtres, balcons et portes |

## Dépendances transversales à préserver

- Le terrain lit les données de dégagement routier avant de créer les chunks : l'ordre de préparation est fonctionnel, pas arbitraire.
- Les collisions proches du terrain doivent être prêtes avant de réactiver la physique du joueur et du véhicule.
- Le réseau routier partage des grilles de proximité, des matériaux, des données de jonction et des fonctions d'altitude.
- Les bâtiments et les routes utilisent les mêmes conversions GeoJSON vers coordonnées du monde.
- Les objets de la Baie des Rois dépendent de zones géographiques explicites et de scènes d'assets existantes.
- Le HUD utilise les localités chargées pour afficher le nom de la zone proche.
- Les matériaux et les surfaces partagés doivent rester mutualisés pour ne pas multiplier les draw calls ou la mémoire GPU.

## Plan de refactorisation recommandé

### Étape 1 — sécurisation (sans changement de rendu)
1. Conserver une copie de référence du script et relever le SHA de départ.
2. Vérifier les scènes qui référencent directement `world_map.gd` et les méthodes publiques appelées depuis d'autres scripts.
3. Établir une liste des chemins de ressources chargés dynamiquement.
4. Ajouter un test de parse Godot 4.3 et une scène de test de démarrage avant chaque extraction.

### Étape 2 — extractions à faible couplage
1. Extraire les conversions géographiques et les fonctions mathématiques réellement pures dans un utilitaire `RefCounted` ou une classe statique, après vérification des appels.
2. Extraire ensuite le HUD de localisation dans un composant dédié, en conservant le même nom de nœud et le même affichage.
3. Garder les données et le chargement des localités dans le propriétaire du monde tant que le HUD en dépend.

### Étape 3 — sous-systèmes de génération
1. Extraire la génération des bâtiments dans un composant dédié, en lui passant explicitement matériaux, altitude, coordonnées et scènes nécessaires.
2. Extraire le réseau routier ensuite : c'est la partie la plus couplée (jonctions, trottoirs, collisions, lampadaires, matériaux et terrain).
3. Extraire l'environnement/littoral et la végétation dans une étape séparée.
4. Extraire le streaming du terrain en dernier parmi les grands sous-systèmes, car il contrôle les collisions et la disponibilité du sol sous le joueur.

## Contrôles obligatoires après chaque étape

- Le projet s'ouvre et les scripts passent le parseur Godot 4.3.
- La scène principale démarre sans erreur ni ressource manquante.
- Le joueur et le véhicule restent sur le relief, y compris près de la côte.
- Les routes, intersections, trottoirs, marquages et collisions sont conservés.
- Les bâtiments, toitures et scènes de restaurants de la Baie des Rois restent visibles.
- Le chargement des chunks et des lots reste progressif.
- Aucun rayon, quota de génération ou réglage graphique n'est modifié sans mesure préalable.
- Comparer les logs, le temps de démarrage et la mémoire sur la configuration de référence, notamment la machine équipée de GT 730.

## Hors périmètre de cette première passe

- Pas de modification des GeoJSON ou du DEM.
- Pas de déplacement/renommage des modèles 3D ni des textures.
- Pas de changement des coordonnées géographiques, des rayons, des tailles de lots ou du streaming.
- Pas de réécriture de l'historique Git ni de migration Git LFS sans décision dédiée.
- Pas d'ajout de licence avant confirmation du titulaire et du texte souhaité.

## Conclusion

`world_map.gd` est un orchestrateur et un générateur multi-sous-systèmes de 4 800 lignes environ. Le découpage doit se faire par étapes, avec injection explicite des dépendances, afin d'éviter les références implicites à `get_parent()`, les duplications de matériaux et les régressions sur le monde ouvert.
