# Limites de gameplay — Libreville

## Fichiers générés

- `neighbourhoods.geojson` : 72 polygones de secteurs jouables.
- `arrondissements.geojson` : 6 regroupements de secteurs de gameplay.
- `localities.geojson` : points OSM d'origine, conservés comme repères et destinations.

## Méthode actuelle

1. Les 72 points de localité OSM (le point général « Libreville » est exclu) servent de centres de secteurs.
2. Une partition de Voronoï est calculée en coordonnées métriques locales, puis convertie en WGS84 / EPSG:4326.
3. Les frontières partagées entre deux cellules sont comparées aux routes OSM, aux cours d'eau et aux lignes de côte.
4. Lorsqu'une ligne OSM est suffisamment proche, parallèle et couvre une longueur compatible, le bord commun est déformé pour suivre son tracé. Les deux quartiers voisins utilisent exactement la même ligne corrigée.
5. Les six regroupements d'arrondissement conservent la correspondance des quartiers définie dans les propriétés des fichiers.

## Résultat du dernier ajustement

- 72 cellules de quartiers/secteurs.
- 6 regroupements d'arrondissement.
- 187 frontières communes analysées.
- 13 frontières alignées sur des routes OSM.
- 2 frontières alignées sur des éléments naturels OSM (cours d'eau / côte).
- Les autres frontières restent des séparations procédurales, faute de route ou de ligne naturelle suffisamment proche et compatible.

## Correspondance des secteurs de gameplay

- **1er arrondissement** : Louis, Vallée Sainte-Marie, Plaine Orety, Quaben, Akémindjogoni, Batterie 4, Baie des Rois, Derrière la Prison, Bas de Gué-Gué, Haut de Gué-Gué, Trois quartiers, Camp des Boys, Charbonnages, Montagne Sainte, Centre-Ville.
- **2e arrondissement** : Atong Abe, Atong-Abe, Atsib-tchoss, Cocotiers, Sotega, Ancien Sobraga, N'kembo, Avea, Cité Mébiame, Cité de la Démocratie, Campagne.
- **3e arrondissement** : Akébé Plaine, Akébé-Ville, Likouala-Moussaka, Petit Paris, Belle-Vue, Derrière l'Hôpital, Mont Bouet, Sorbonne, Venez-Voir, Peyrie, STFO, Akébé-Kinguélé, Kosmoparc.
- **4e arrondissement** : Glass, Plaine Niger, Michel Marine, London, Nombakele, Toulon, Ambilambani, Batavéa, Awendjé, Baraka-Mission, Oloumi, Zone Industrielle d'Oloumi, Akébé Frontière-Baraka.
- **5e arrondissement** : Lalala-Dakar, Lalala-Droite, Lalala-Gauche, Mindoube 1, Institut des Sports, Smag, I.A.I-Golf, Ozangué, Beau-Séjour, Cité Damas, Plein-ciel, Mindoubé 2, RIO, PK5, Bassin du PK5.
- **6e arrondissement** : Sibang, Terre-Nouvelle, Cité de la Caisse, Nzeng Ayong, Cité des Ambassadeurs.

## Règles et limites connues

- Ce sont des **limites de gameplay**, pas des limites administratives officielles.
- Les lieux particuliers (Baie des Rois, Institut des Sports, Zone Industrielle d'Oloumi, Centre-Ville, RIO, etc.) restent des secteurs jouables même s'ils ne sont pas tous des quartiers administratifs.
- Les variantes OSM « Atong Abe » et « Atong-Abe » sont conservées comme deux points distincts ; elles partagent une indication d'alias dans les propriétés.
- Les limites non appuyées par une route ou un élément naturel restent provisoires.
- L'enveloppe extérieure est basée sur l'enveloppe des points OSM et doit encore être comparée au littoral, aux bâtiments et à la zone réellement jouable.
- Le rendu des polygones doit être vérifié dans QGIS puis dans Godot. La géométrie n'a pas encore été déclarée validée visuellement ou en jeu.

## Téléportation

Le moteur associe chaque point OSM à son polygone de quartier via `osm_id`. Avant de proposer une destination, il vérifie que le point se trouve dans son secteur ; si ce n'est pas le cas, il utilise le centroïde du polygone. Les destinations hors de la marge de sécurité de la carte ou hors de l'emprise du modèle numérique de terrain sont écartées. Le téléporteur convertit ensuite la position locale de `WorldMap` en position globale du joueur et affiche aussi l'arrondissement associé.

Le calcul des données confirme que les 72 points de localité utilisés sont à l'intérieur de l'emprise actuelle du modèle de terrain. Le déplacement réel du personnage doit toutefois être contrôlé dans Godot.

## Champs importants

`arrondissement_id`, `arrondissement`, `boundary_status`, `official_boundary`, `confidence`, `boundary_type`, `road_aligned_shared_edges` et `source` permettent d'identifier le secteur, sa méthode de génération et son niveau de certitude.

## Attribution

Les données de base proviennent d'OpenStreetMap : © OpenStreetMap contributors, ODbL 1.0.
