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
- Les lots restent triés par secteur d'ancrage, mais leur nœud unique est
  enregistré dans tous les secteurs couverts par les boîtes englobantes des
  empreintes (avec une petite marge). Le mesh et ses collisions ne sont ni
  dupliqués ni découpés ; le lot reste actif tant qu'un secteur couvert est
  chargé. La couverture est conservative et peut inclure quelques secteurs
  voisins supplémentaires pour les formes concaves.

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
- Les lots sont enregistrés dans l'union des secteurs couverts par les boîtes
  englobantes des polygones et lignes (largeur comprise pour les lignes). Le
  mesh visuel et la collision de relief restent regroupés dans le même lot,
  activé tant qu'un secteur couvert est chargé.
- Les triangles des surfaces polygonales sont maintenant découpés contre les
  rectangles exacts des secteurs de 800 m avant leur subdivision pour suivre
  le relief. Les polygones convexes issus du clipping sont triangulés en éventail.
  Le même triangle découpé et les mêmes sommets sont envoyés au mesh visuel et
  à la collision du relief, ce qui évite une divergence entre les deux.
- Les rubans générés depuis les LineString (cours d'eau, plans d'eau
  linéaires et autres lignes environnementales) sont eux aussi découpés par
  l'emprise réelle de leur quad, largeur comprise. Les deux triangles du quad
  sont traités séparément. L'altitude est interpolée le long du segment source
  afin de préserver le niveau d'eau/du cours d'eau au lieu de le plaquer sur le
  relief DEM.
- Limite actuelle : les morceaux découpés par secteur sont encore réunis dans
  le lot environnemental d'origine ; ils ne sont pas encore stockés dans un
  nœud/mesh indépendant par secteur. Les chemins de côte servent à la sélection
  et au placement du littoral ; leur représentation spécifique sera traitée
  séparément.
- La couverture conservative peut inclure des secteurs que la forme concave
  ne touche pas réellement.
- Les tests géométriques couvrent la conservation d'aire, les deux sens de
  parcours des triangles, les coordonnées négatives et le contact simultané
  avec quatre secteurs autour d'un coin de grille. Ils valident la primitive,
  pas encore l'import complet ni le rendu de la scène Godot.

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


## Interpolation des attributs lors du découpage des meshes

Le clipping triangle/rectangle dispose maintenant d'une variante qui retourne,
pour chaque sommet découpé, ses coordonnées barycentriques dans le triangle
source. Ces poids permettent de reconstruire exactement la position et
d'interpoler les attributs attachés aux sommets (UV, couleur, normale,
tangente et altitude) au lieu de recalculer ces valeurs à partir de la seule
position XZ.

Cette primitive est une fondation pour le futur découpage des meshes routiers :
les routes comportent plusieurs matériaux, des UV continus, des marquages et
des collisions. Leur séparation en meshes autonomes par secteur n'est pas
encore réalisée. Les tuiles routières existantes restent partagées entre les
secteurs qu'elles couvrent. Les tests géométriques vérifient la somme des poids,
la reconstruction des positions et la conservation de l'aire.


### Interpolation des attributs de sommets

La primitive `interpolate_triangle_attribute(values, weights)` applique les coordonnées barycentriques conservées par le clipping aux attributs d'un triangle source. Elle prend en charge les scalaires, `Vector2`, `Vector3`, `Vector4` et `Color` (y compris l'alpha). Pour les meshes routiers, cela couvre notamment UV/UV2, position, normales, tangentes et couleurs de sommets.

Les normales interpolées doivent être renormalisées par le constructeur du mesh ; les tangentes peuvent nécessiter une réorthogonalisation. Les attributs de peau/bones ne sont pas encore pris en charge. Cette primitive et ses tests sont une étape préparatoire : les meshes routiers sont toujours regroupés en tuiles partagées, le découpage réel des surfaces et la reconstruction des collisions par secteur restent à implémenter.


### Découpage effectif des meshes routiers

Les surfaces routières triangulaires sont maintenant découpées dans leur rectangle de secteur au moment de leur validation. Les intersections de triangles interpolent les positions, UV/UV2, couleurs, normales et tangentes à partir des poids barycentriques. Chaque secteur reçoit ses propres MeshInstance3D et ses propres collisions ; le gestionnaire les enregistre comme nœuds sectoriels indépendants au lieu de garder une tuile routière partagée.

Le découpage est appliqué aux surfaces de chaussée, trottoirs, bordures et marquages produits par les lots de routes. Les surfaces et collisions sont toutes découpées depuis leur géométrie source ; aucun mesh de tuile entier n'est réutilisé dans plusieurs secteurs. Les attributs de skinning (bones/weights) restent volontairement refusés par l'utilitaire, car les routes sont des meshes statiques.


## Continuité des axes routiers au rayon de chargement

Le filtrage spatial des routes ne doit pas utiliser uniquement le centre géométrique
d'une entité OSM : une longue route peut traverser la zone jouable alors que son
centre et ses extrémités se trouvent à l'extérieur. Les LineString et MultiLineString
sont donc conservées dès qu'un segment intersecte le disque de chargement. Les
bâtiments et autres objets surfaciques gardent le filtrage par centre. Un test
géométrique vérifie le cas d'une route traversante, d'une route extérieure et d'un
contact exact avec la limite du rayon.
