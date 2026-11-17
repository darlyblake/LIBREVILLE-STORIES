# Périmètre cartographique — version 0.2

## Objectif
Construire une première zone de jeu inspirée du Centre-ville, de Louis, Glass, Nombakélé, Mont-Bouët, Nkembo et Akébé.

## Emprise provisoire
L'extraction initiale utilise la boîte géographique sud/ouest/nord/est suivante : 0.355, 9.400, 0.445, 9.495. C'est une emprise technique rectangulaire autour de Libreville et de ses environs, pas une limite officielle des quartiers. Elle devra être affinée après inspection de la carte.

## Extraction contrôlée
Une première extraction OpenStreetMap terminée avec succès a produit :
- 4 503 géométries de voies (LineString).
- 49 359 empreintes de bâtiments (Polygon).
- Deux fichiers GeoJSON et un rapport d'extraction.
- Les types de voies et de bâtiments sont conservés dans les propriétés.

Une seconde version du processus découpe la zone en 9 tuiles, met en cache les réponses et réessaie plusieurs serveurs Overpass. Le workflow GitHub Actions doit aussi déposer les fichiers extraits dans le dépôt.

## Génération 3D
Le script `game/scripts/world_map.gd` :
- convertit longitude/latitude en coordonnées locales métriques ;
- construit un réseau routier à partir des lignes OSM ;
- extrude les empreintes de bâtiments en volumes simples ;
- regroupe les géométries en meshes pour réduire le nombre d'objets de rendu.

Les hauteurs des bâtiments sont approximatives lorsqu'aucune hauteur fiable n'est fournie. Les bâtiments sont des volumes de prototype, pas des modèles architecturaux fidèles.

## Couches à compléter
- Relief et pente du terrain
- Littoral, cours d'eau et zones humides
- Végétation et espaces verts
- Points d'intérêt et mobilier urbain
- Bâtiments détaillés et enseignes locales
- Découpage et chargement progressif par secteurs

## Sources et attribution
Source : OpenStreetMap contributors, licence ODbL 1.0. Afficher « © OpenStreetMap contributors » dans le jeu et les crédits. Contrôler les données et respecter les obligations de partage à l'identique applicables à la base dérivée.

## Tests restant à effectuer
Le script de génération doit encore être ouvert et exécuté dans Godot 4 sur la machine cible. La scène n'a pas encore fait l'objet d'un test réel de rendu, de collision ni de performance.
