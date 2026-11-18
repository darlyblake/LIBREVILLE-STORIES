# Reconstruction de la première partie de la Baie des Rois — référence vidéo

## Herbe 3D procédurale

Un générateur dédié `game/scripts/grass_generator.gd` instancie de petites touffes d'herbe géométriques sur les parcelles identifiées comme herbeuses dans `environment.geojson`. Chaque touffe contient trois brins triangulés croisés, avec variation de hauteur, largeur, orientation et teinte. Les touffes sont regroupées dans un seul `MultiMeshInstance3D` afin de limiter les appels de rendu.

Le placement est déterministe à partir de l'identifiant OSM. La densité est plafonnée à 3 200 touffes au total et à 900 par parcelle. Les surfaces explicitement pavées, en béton ou en asphalte sont exclues. Le niveau des touffes suit le relief calculé des parcelles vertes.

Cette première version utilise une géométrie simple et légère, adaptée au renderer GL Compatibility et à la cible GT 730. Elle ne constitue pas encore une simulation botanique détaillée : pas de vent animé ni de textures de brins photographiques. Le rendu doit être contrôlé dans Godot avant d'ajuster densité et hauteur.

## Placement des props 3D

Le placement du mobilier est maintenant isolé dans `game/scripts/baie_des_rois_props_placement.gd` (`BaieDesRoisPropsPlacement`). Le script charge les GLB du palmier, du banc et du lampadaire, puis calcule les positions depuis les deux axes GPS de `BaieDesRoisSurvey`.

- Palmiers : progressions 0,18 / 0,50 / 0,82 sur chaque rangée.
- Lampadaires : progressions 0,08 / 0,36 / 0,64 / 0,92 sur chaque rangée.
- Bancs : progressions 0,28 / 0,72 sur chaque rangée.
- Les décalages extérieurs sont respectivement 7,2 m, 5,7 m et 6,0 m depuis les axes des kiosques.

Le module est appelé par `baie_des_rois.gd`. Les coordonnées longitudinales proviennent du relevé GPS, tandis que les décalages latéraux restent des paramètres de mise en scène provisoires. Le placement n'a pas encore été validé visuellement dans Godot : il faudra contrôler que chaque objet repose bien dans une pelouse et ne mord ni sur le trottoir ni sur la chaussée.

## Périmètre

La vidéo aérienne fournie le 18 novembre 2026 devient la référence visuelle principale pour la reconstruction de la première partie de la Baie des Rois. Le périmètre s'arrête à l'extrémité de la promenade visible avant la zone du pont. La partie située au niveau du pont est explicitement hors périmètre pour cette étape.

Ordre de travail obligatoire :
1. Finaliser la carte et la géométrie du site (sol, littoral, mer, promenade et espaces verts).
2. Ajouter les éléments architecturaux et paysagers par scripts de génération dédiés.
3. Contrôler l'implantation et les collisions dans Godot avant d'étendre la zone.

## Observations directement visibles dans la vidéo

La vidéo montre une vue aérienne oblique et progressive de la promenade.

- Une grande surface d'eau bleu foncé borde directement le cheminement piéton.
- La promenade est constituée d'un dallage clair gris à beige, visiblement découpé en grandes dalles rectangulaires. Elle suit le contour du rivage et s'élargit localement.
- De larges îlots de pelouse occupent le côté intérieur de la promenade. Leurs contours sont géométriques et séparés par des cheminements pavés.
- Plusieurs pavillons/kiosques en bois brun-orangé sont implantés dans les espaces verts. Plusieurs ont une toiture à deux pans de couleur vert foncé, d'aspect tôle.
- Un autre pavillon possède une couverture claire de type chaume ou fibres végétales.
- Des palmiers sont plantés de façon espacée dans les pelouses, avec quelques plantations plus petites.
- Des bancs, des lampadaires et du mobilier urbain ponctuent les cheminements.
- Une aire de jeux colorée rouge et jaune apparaît dans un îlot vert.
- À l'extrémité visible de la promenade, le rivage comporte une avancée ou bordure rocheuse/enrochement.
- Des bâtiments et aménagements urbains apparaissent au-delà de l'eau et à l'arrière-plan, mais leur détail n'est pas assez lisible pour être modélisé à partir de cette seule vidéo.

Ces observations décrivent ce qui est visible ; elles ne donnent pas les dimensions métriques exactes des dalles, pelouses, pavillons ou équipements.

## Position de la mer dans le repère du jeu

Dans la vidéo, l'eau se trouve à droite du cheminement dans le cadrage aérien. Cette indication droite/gauche dépend de l'orientation de la caméra et ne doit pas être convertie directement en axe X ou Z du monde.

Le relevé géographique déjà documenté dans le dossier d'implantation GPS situe la ligne OSM way/443854943 (natural=coastline) à environ 29 à 38 m des repères GPS des kiosques, du côté +Z du monde. Cette donnée cartographique constitue actuellement le repère spatial à utiliser pour localiser l'eau. La ligne OSM est une référence de littoral, pas la limite exacte du dallage.

## État technique existant à corriger ou compléter

- world_map.gd crée actuellement un grand plan d'eau générique de 16 km × 11 km, centré approximativement en (-2600, 100). Il n'épouse pas le contour local du rivage.
- Le traitement OSM de coastline crée actuellement une bande de rendu de largeur fixe ; ce n'est pas une véritable surface d'eau découpée selon le rivage.
- Les surfaces de végétation OSM sont déjà triangulées. Les contours existants doivent être conservés lorsqu'ils correspondent aux îlots visibles.
- Les chemins OSM sont rendus avec le système routier générique. La promenade de la vidéo demande un matériau et un traitement de dalles plus adaptés, sans transformer toutes les routes de la ville.
- Les anciens générateurs décoratifs dans baie_des_rois.gd ne constituent pas une base topographique fiable. Ne pas réactiver leurs grands rectangles ou leurs plantations arbitraires.

## Première passe de relief paysager intégrée

Le script `game/scripts/world_map.gd` applique un relief léger aux polygones OSM de type `green_space` et `vegetation` :

- les espaces verts principaux montent progressivement jusqu'à environ 0,65 m ;
- les zones de végétation secondaire montent jusqu'à environ 0,38 m ;
- les bords restent proches du niveau du terrain pour créer une transition douce ;
- une ondulation déterministe de faible amplitude casse l'aspect parfaitement régulier des bosses ;
- les arbres générés dans ces polygones reçoivent la même hauteur de sol ;
- une collision trimesh dédiée permet au joueur de marcher sur ces surfaces surélevées.

Une erreur de calcul du centroïde des polygones a également été corrigée : le centre est désormais calculé après l'accumulation de tous les sommets, ce qui évite de décaler artificiellement les bosses vers le dernier sommet du contour.

Ces valeurs sont des hauteurs de mise en scène provisoires, et non un relevé altimétrique de la Baie des Rois. Cette passe améliore les îlots verts déjà présents dans les données OSM ; elle ne constitue pas encore un modèle altimétrique continu du terrain naturel, des niveaux du dallage ou du profil du rivage. Les chemins et les bâtiments restent à leur niveau actuel. Le contrôle dans Godot reste nécessaire pour vérifier les raccords, les normales et le déplacement du joueur.

## Architecture prévue des scripts

Les éléments seront générés en modules indépendants, avec une racine de scène commune à la zone. Les géométries seront regroupées et les matériaux réutilisés pour rester compatibles avec la cible graphique modeste du projet.

| Module prévu | Responsabilité |
|---|---|
| baie_des_rois_site.gd | Orchestration de la zone, chargement des modules et ordre de génération |
| baie_des_rois_shoreline.gd | Lecture des données géographiques, délimitation du rivage et raccord terre/eau |
| baie_des_rois_ocean.gd | Surface de mer locale, teinte, reflets et animation légère à faible coût |
| baie_des_rois_promenade.gd | Dallage clair, grandes dalles, bordures et raccords de cheminements |
| baie_des_rois_landscape.gd | Pelouses suivant les polygones existants, terre nue et transitions de sol |
| baie_des_rois_vegetation.gd | Palmiers et végétation basse, implantés dans les espaces verts |
| baie_des_rois_pavilions.gd | Pavillons en bois, kiosques et toitures métalliques vert foncé |
| baie_des_rois_furniture.gd | Bancs, lampadaires et petits équipements |
| baie_des_rois_playground.gd | Aire de jeux visible dans la référence |
| baie_des_rois_coastal_edge.gd | Enrochements, bordures et garde-corps là où ils sont réellement visibles |

Les noms ci-dessus sont une architecture cible, pas encore des fichiers créés. Les dimensions et positions des objets ne seront pas inventées : elles seront déduites des géométries OSM/GPS disponibles, des proportions observables dans la vidéo et des points de contrôle déjà fournis.

## Règles de réalisation

1. Ne pas déplacer les kiosques GPS sans raison géométrique documentée.
2. Garder le passage central des kiosques libre et les façades commerciales tournées vers les clients.
3. Construire la mer à partir du littoral local, pas d'un plan d'eau qui recouvre indistinctement terre et mer.
4. Faire suivre au dallage la forme réelle de la promenade et ses élargissements.
5. Conserver les contours des îlots de pelouse existants ; compléter seulement les surfaces manquantes.
6. Ne pas planter de palmiers sur le dallage, les chemins ou les zones de circulation.
7. Construire les pavillons avec des matériaux bois et des toitures vert foncé en tôle, conformément aux modèles visibles.
8. Reproduire le pavillon à couverture végétale comme un type distinct, sans transformer tous les kiosques en bâtiments identiques.
9. Ajouter l'aire de jeux et le mobilier uniquement dans les espaces où la vidéo les montre.
10. Optimiser les meshes, matériaux et instances ; éviter les milliers d'objets individuels et les ombres coûteuses.
11. Ne pas commencer la zone du pont avant validation complète de cette première partie.

## Critères de validation de cette étape

- La mer est du bon côté du rivage et sa surface épouse le littoral local.
- La promenade est une bande pavée continue, avec des dalles lisibles et des raccords propres.
- Les pelouses ont des contours crédibles et restent séparées des cheminements.
- Les kiosques et pavillons sont dans les espaces prévus, hors chaussée et hors trottoir.
- Les palmiers, bancs, lampadaires et jeux ne bloquent pas les cheminements.
- La vue aérienne générale rappelle la disposition de la vidéo avant tout travail de détail.
- La scène reste fluide sur la configuration minimale ciblée du projet.

## Prochaine étape

Examiner et exploiter les géométries locales déjà présentes dans environment.geojson et roads.geojson, puis définir le polygone de terre/eau et le tracé exact de la promenade dans le repère du jeu. Ce travail de carte doit précéder la génération des pavillons, de la végétation et du mobilier.

## Pavillons de restauration à toiture verte

Le générateur Blender `tools/blender/create_baie_des_rois_restaurants.py` produit trois variantes GLB (compacte, standard et grande) de pavillons de restauration : charpente bois, toiture métallique verte à deux pans avec nervures, gouttières, comptoir de service, arrière-cuisine, claustras, tables, chaises, suspensions et jardinières.

Exécution depuis la racine du dépôt sous Windows :

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.3\blender.exe" --background --python tools/blender/create_baie_des_rois_restaurants.py
```

Fichiers générés dans `assets/models/baie_des_rois/` :
- `restaurant_pavillon_baie_des_rois_compact.glb`
- `restaurant_pavillon_baie_des_rois.glb`
- `restaurant_pavillon_baie_des_rois_large.glb`

Ces modèles sont des assets, pas encore des bâtiments implantés dans la scène. Leur remplacement devra reprendre les centres, orientations et empreintes des anciens composants OSM identifiés dans `buildings.geojson`. Aucun nouvel emplacement GPS n'est introduit par ce générateur.


## Nouveaux assets autonomes — éléments absents de la première zone

Le générateur `tools/blender/create_baie_des_rois_missing_assets.py` ajoute cinq familles de modèles 3D qui n'étaient pas encore disponibles dans le dépôt :

| Asset GLB | Contenu |
|---|---|
| `pavillon_chaume_baie_des_rois.glb` | Pavillon ouvert en bois avec toiture à fibres végétales/chaume, comptoir et claustras latéraux |
| `aire_jeux_baie_des_rois.glb` | Module compact d'aire de jeux avec balançoires, toboggan, échelle et bascule, couleurs rouge/jaune/bleu |
| `table_pique_nique_baie_des_rois.glb` | Table extérieure en bois avec deux bancs longitudinaux |
| `fontaine_baie_des_rois.glb` | Fontaine circulaire basse en pierre avec bassin et colonne centrale |
| `massif_tropical_baie_des_rois.glb` | Jardinière avec feuillage tropical varié et petites fleurs |

Exécution sous Windows depuis la racine du dépôt :

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.3\blender.exe" --background --python tools/blender/create_baie_des_rois_missing_assets.py
```

Les fichiers sont exportés dans `assets/models/baie_des_rois/`. Ce commit ajoute le générateur, pas les fichiers binaires GLB : ils seront créés localement par Blender puis ajoutés au dépôt par l'utilisateur. Aucun emplacement géographique n'est codé en dur. L'aire de jeux, le pavillon, la fontaine et les massifs devront être implantés uniquement dans les îlots et emplacements confirmés par les données du site et la référence visuelle. La fontaine est un asset disponible, pas la preuve qu'une fontaine est présente dans le cadrage vidéo de référence.

Les cheminements secondaires et les éclairages supplémentaires ne sont pas fabriqués comme objets isolés : ils dépendent des tracés réels des chemins et des besoins d'éclairage, qui devront être dérivés des données cartographiques plutôt que placés arbitrairement.
