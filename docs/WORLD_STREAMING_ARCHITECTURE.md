# Streaming spatial du monde — architecture actuelle

## Objectif

Le monde jouable est organisé en secteurs de 800 m sur les axes X/Z. Le
gestionnaire active les contenus proches du joueur et désactive ceux qui sont
éloignés, sans détruire les nœuds ni leurs ressources. Les générateurs restent
responsables de produire les données géographiques et les objets du monde.

## Gestionnaire central

- Script : `game/scripts/world_streaming_manager.gd`
- Scène : `game/scenes/main.tscn`, nœud `WorldStreamingManager`
- Taille par défaut : 800 m, alignée sur les tuiles routières OSM.
- Rayon d'activation : 2 secteurs.
- Rayon de désactivation : 3 secteurs.
- Fréquence de mise à jour : 0,20 s.
- Coordonnées : secteur calculé depuis X/Z avec `floori`.
- Enregistrement : `register_node(node, category, world_position)`.
- Le reparentage conserve le transform global.
- Désactivation : visibilité, traitement du secteur et couches de collision.
- Les collisions d'origine sont mémorisées dans les métadonnées puis
  restaurées à la réactivation.

### Géométrie des rayons

Les rayons sont circulaires en distance euclidienne entre coordonnées de
secteurs, et non carrés. Avec un rayon de 2, les secteurs diagonaux situés à
plus de deux unités de distance ne sont pas activés. Le rayon de sortie plus
large apporte une hystérésis et évite les basculements répétés à la limite.

### Anticipation du déplacement

Le gestionnaire distingue maintenant deux situations :
- À pied : anticipation réglable par `on_foot_preload_seconds`, 2 secondes
  par défaut, déclenchée au-dessus de 1,5 m/s.
- Au volant : le contrôleur du véhicule doit confirmer `player_driving = true`.
  La vitesse réelle du `VehicleBody3D` est alors utilisée avec
  `vehicle_preload_seconds`, 6 secondes par défaut.

Dans les deux cas, l'anticipation est plafonnée à deux tailles de secteur.
Le simple fait de marcher près d'une voiture ne déclenche donc plus le
préchargement longue distance. Ces valeurs restent à mesurer en jeu et pourront
être ajustées selon la densité et les performances.

## Contenus déjà intégrés

### Routes et voirie

- Chaque lot routier est contenu dans un nœud `RoadTile_x_z`.
- L'affectation du lot se fait maintenant au milieu de sa longueur cumulée,
  plutôt qu'à son premier sommet : les longs tronçons ne sont plus ancrés
  systématiquement à une extrémité.
- Chaussée, bordures, trottoirs, marquages et collisions restent groupés.
- Le conteneur est enregistré dans le secteur correspondant à cet ancrage médian.
- Les tronçons routiers partagés sont désormais rattachés à tous les secteurs
  traversés (avec une marge liée à leur demi-largeur), sans dupliquer leurs
  meshes ni leurs collisions. Le gestionnaire garde le lot visible et actif
  tant qu'au moins un secteur couvert reste dans le rayon chargé ; l'hystérésis
  de sortie est conservée. La géométrie n'est pas encore découpée en meshes
  physiques par secteur : elle reste un lot unique à activation multi-secteurs.
- Un utilitaire pur `split_polyline_by_sectors` découpe maintenant une ligne X/Z
  aux frontières exactes des secteurs et retourne les morceaux avec leur clé
  sectorielle. Les sommets de frontière sont partagés sans intervalle vide ;
  les croisements simultanés X/Z ne créent pas de secteurs diagonaux fictifs.
- Des tests headless couvrent les traversées positives/négatives, les coins,
  le sens inverse et la continuité des extrémités. Cet utilitaire n'est pas
  encore branché au générateur de routes : les intersections, trottoirs,
  marquages et collisions doivent être migrés ensemble avant activation.
- Une tuile hors rayon est masquée et ses collisions sont désactivées.
- Les transitions entre tuiles, intersections et trottoirs doivent encore être
  testées en jeu pour détecter les discontinuités.
- Au chargement, `line_sector_span` mesure les tronçons OSM dont la boîte
  englobante traverse plusieurs secteurs et journalise le nombre ainsi que la
  portée maximale. C'est un diagnostic, pas encore un découpage géométrique.
- Limite connue : un tronçon est actuellement affecté à la tuile de son premier
  point ; un long tronçon peut donc dépasser cette tuile. Il faut le découper
  en segments cohérents (chaussée, trottoirs, marquages et collision) avant de
  distribuer ses morceaux entre secteurs, sans dupliquer les surfaces.

### Bâtiments

- Les lots de bâtiments sont triés et regroupés par secteur.
- Un lot est limité à 1 200 empreintes.
- Les murs, toitures et détails d'un lot restent dans le même conteneur.
- Les bâtiments spéciaux de la Baie des Rois sont également enregistrés.
- Limite connue : une empreinte de bâtiment est affectée au secteur de son
  centre. La géométrie d'un grand bâtiment qui traverse une frontière n'est
  pas encore découpée/clippée entre plusieurs secteurs.

### Végétation et herbe

- Les lots d'arbres (troncs et canopées) sont regroupés sous des conteneurs
  sectoriels `VegetationTile_x_z`.
- Les MultiMesh d'herbe utilisent une grille alignée sur 800 m et sont
  enregistrés comme catégorie `Vegetation`.
- Les lots sont désactivés avec leur secteur, sans supprimer les ressources.

### Éclairage public

- Les lots de lampadaires sont regroupés sous des conteneurs
  `LampBatch_x` et enregistrés dans la catégorie `Streetlights`.

### Littoral de la Baie des Rois

- L'eau est enregistrée dans la catégorie `Coastline`.
- Le mur de soutènement, ses collisions, les garde-corps et les rochers sont
  regroupés dans l'infrastructure côtière.
- Les écumes et instances de rochers sont également rattachées au streaming
  côtier.
- Il reste à tester la continuité visuelle et physique du rivage lors des
  transitions de secteurs.

### Environnement et relief

- Les éléments d'environnement sont triés par secteur puis par distance.
- Les lots sont limités à 900 éléments.
- Surface visuelle et collision de relief sont rangées dans le même conteneur
  `EnvironmentBatch_x_y_nnn`.
- Limite connue : chaque élément est affecté au secteur de son centre. Les
  grandes géométries traversant une frontière ne sont pas encore découpées.

## Limites et prochaines étapes

1. Mesurer les valeurs de préchargement à pied et en véhicule, notamment lors
   des changements de direction et des arrêts brusques.
2. Évaluer le voisinage circulaire sur les diagonales, les routes et les limites
   du périmètre géographique validé avant toute modification de sa géométrie.
3. Exploiter les diagnostics des routes et surfaces pour découper réellement
   les géométries aux frontières de secteurs : chaussées, trottoirs, marquages
   et collisions doivent partager exactement les mêmes limites, sans trous ni
   doublons. Ne pas déplacer un tronçon uniquement selon son premier point.
4. Vérifier qu'aucune collision de route, de trottoir ou de bâtiment ne reste
   désactivée après réactivation.
5. Mesurer le coût mémoire et le temps de génération sur plusieurs secteurs.
6. Tester le chargement/déchargement à pied et en véhicule dans Godot 4.3.
7. Vérifier que les secteurs générés restent strictement dans le périmètre
   validé du projet Libreville Stories.

## Validation

Le workflow GitHub Actions valide séparément les données de calendrier et de
simulation, puis importe le projet avec Godot 4.3 et inspecte les animations et
les modèles GLB. Un contrôle des données réussi ne signifie pas que l'import
Godot ou le démarrage de la scène principale a réussi : ces étapes doivent
être confirmées indépendamment.
