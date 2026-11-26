# Fiche de relevé — échangeur des Charbonnages

Mise à jour : 26 novembre 2026  
Projet : LIBREVILLE STORIES — carte jouable de Libreville

## 1. Identification et périmètre

- Ouvrage : échangeur des Charbonnages.
- Type cartographique OSM : way 1443840888, tag `man_made=bridge`.
- Repère publié par Mapcarta : 0.43650 N, 9.44087 E.
- Secteur de gameplay : Charbonnages.
- Statut : ouvrage existant ; aménagement de ses abords engagé en août 2026.
- Le repère publié est un point de localisation de l'objet OSM, pas une géométrie complète du tablier. Il ne doit pas servir à dessiner un rectangle ou à fixer les dimensions du pont.

Sources cartographiques :
- https://mapcarta.com/fr/W1443840888
- https://www.openstreetmap.org/way/1443840888

## 2. État des abords documenté en 2026

L'article de L'Union du 28 août 2026 indique que les travaux d'aménagement des abords ont commencé moins de trois semaines auparavant et sont annoncés pour neuf mois. Les objectifs décrits sont la fluidification de la circulation, la réduction des difficultés de stationnement et la réorganisation des arrêts des transporteurs informels et des occupations commerciales.

Les éléments de chantier explicitement documentés comprennent :
- un mur de sécurisation en cours de construction ;
- une réorganisation des voies et du stationnement ;
- le traitement des abords occupés par les commerçants et les transporteurs informels.

Cette information décrit les abords et le chantier de 2026. Elle ne donne pas les dimensions du tablier, le nombre de piles, la hauteur libre, les pentes des bretelles ou les rayons de courbure.

Source :
- L'Union, « Voiries : vers un nouveau look à l'échangeur des Charbonnages », 28 août 2026 : https://union.sonapresse.com/index.php/fr/node/27547
- Biba241, « Charbonnages : un nouveau visage se dessine autour de l'échangeur », 28 août 2026 : https://www.biba241.com/charbonnages-un-nouveau-visage-se-dessine-autour-de-l-changeur

## 3. Références visuelles datées

- L'Union, 11 mars 2021 : photographie des espaces sous le pont, montrant des appuis, des passages piétons et des occupations commerciales de cette période. Cette image est une référence d'observation uniquement ; elle ne constitue pas une texture libre de droits et ne décrit pas automatiquement l'état de 2026.
  https://lunion-archives.org/web.11/dmdocuments/N13571-11-03-2021-006.pdf
- Gabon Télévisions, 5 avril 2025 : reportage sur l'aménagement paysager sous l'échangeur.
  https://www.youtube.com/watch?v=AAjzBr1c2X4
- L'Union, 28 août 2026 : photographie du mur de sécurisation en chantier.
  https://union.sonapresse.com/sites/default/files/articles/Traveaux_Charbonnages_Gabon_Lunion.webp

## 4. Découpage à relever avant la modélisation

Le modèle final doit distinguer des composants séparés :
1. tablier(s) routier(s) ;
2. piles et culées ;
3. voies et bretelles de raccordement ;
4. murs de soutènement et mur de sécurisation lié au chantier 2026 ;
5. espace circulable sous l'ouvrage ;
6. cheminements piétons ;
7. aménagement paysager et stationnement des abords.

Aucun de ces composants ne doit recevoir de dimensions supposées à partir du seul point OSM.

## 5. Données encore nécessaires

- Géométrie complète du way 1443840888, avec ordre des coordonnées et nœuds OSM.
- Ways des voies supérieures, inférieures et bretelles de raccordement.
- Intersection SIG de chaque emprise avec le polygone de gameplay Charbonnages.
- Profil altimétrique du tablier et des rampes, mesuré sur une source géographique ou technique fiable.
- Nombre, position et section des piles ; géométrie des culées et murs.
- Photographies supplémentaires prises depuis les quatre côtés et sous le tablier, avec date.
- Statut exact des travaux à la période représentée dans le jeu.

## 6. Décision de production

**État : retenu pour relevé détaillé ; reconstruction 3D finale non autorisée tant que la géométrie complète et les profils ne sont pas vérifiés.**

Le chantier de 2026 doit être traité comme un état temporel distinct des photographies de 2021 et 2025. Les éléments visibles dans une ancienne archive ne doivent pas être figés dans la version 2026 sans contrôle.

Les matériaux intégrés au jeu doivent provenir de textures CC0 ou de licences compatibles déjà présentes dans le dépôt. Les photographies de presse et les vidéos restent des références visuelles, non des textures à copier.

## 7. Attribution

Les données OSM sont © contributeurs OpenStreetMap, sous licence ODbL 1.0. Les sources de presse et vidéos sont citées comme références d'observation ; leurs contenus ne sont pas redistribués dans le jeu.


## 8. Carrefour giratoire associé — objet distinct du pont

Une seconde géométrie OSM identifie le **Rond-point Charbonnages** :
- way OSM : `251206404` ;
- position publiée : 0.43772 N, 9.44126 E ;
- longueur de la ligne fermée : environ 71 m ;
- type : voie secondaire, giratoire ;
- deux voies (`lanes=2`), sens unique (`oneway=yes`), éclairage (`lit=yes`) ;
- surface déclarée : asphalte ;
- dernière modification indiquée par la source : 3 novembre 2024.

Cette donnée est utile pour contrôler le carrefour au sol, mais elle ne décrit **pas** le tablier de l'échangeur. Le giratoire et le pont doivent rester deux objets séparés dans la fiche et dans la scène 3D. La longueur OSM est celle de la ligne du giratoire, pas son diamètre extérieur ni la largeur de sa chaussée.

Source cartographique secondaire exposant les tags OSM :
- https://ga.geoview.info/rondpoint_charbonnages%2C10251206404w

Contrôle de cohérence : le repère du giratoire (0.43772, 9.44126) est distinct du repère cartographique de l'échangeur (0.43650, 9.44087). Il ne faut donc pas fusionner leurs coordonnées ni déduire le centre du tablier depuis le giratoire.


## 9. Géométries routières du tablier extraites de la couche OSM (26 novembre 2026)

L'extraction régionale identifie deux lignes routières portant le nom de l'échangeur :

| Way OSM | Tags utiles | Sommets | Longueur du tracé calculée |
|---|---|---:|---:|
| `1443840889` | `highway=trunk`, `bridge=yes`, `bridge:structure=beam`, `layer=1`, sens unique | 2 | environ 57,4 m |
| `1443840890` | `highway=trunk`, `bridge=yes`, `bridge:structure=beam`, `layer=1`, `lanes=2`, `surface=concrete`, sens unique | 4 | environ 57,4 m |

Les deux tracés sont proches et parallèles. Ils représentent deux lignes de circulation OSM associées à l'ouvrage ; leurs longueurs ne doivent pas être additionnées pour annoncer la longueur du pont. Elles ne décrivent pas non plus les bretelles, les piles ou la totalité du tablier. Les deux lignes n'ont que deux et quatre sommets : la géométrie est donc trop simplifiée pour produire directement une maquette détaillée.

**Attention à la provenance :** les deux objets portent le tag OSM `source=Bing`. Cela indique une source de cartographie déclarée dans les tags, pas un relevé topographique ni un plan d'exécution.

Source : couche `data/osm/extended/bridges.geojson`, © OpenStreetMap contributors, ODbL 1.0. Les longueurs sont calculées en projection locale approximative à partir des coordonnées géographiques.

## 10. Repère historique d'ingénierie — portée limitée

La page du ministère des Travaux publics consacrée aux échangeurs de la Voie Express indique un marché global de 41,3 milliards FCFA TTC et un linéaire cumulé de 1 140 mètres pour les ponts et rampes d'accès de l'ensemble des échangeurs concernés. Elle précise que l'échangeur des Charbonnages était alors entièrement achevé, tandis que des travaux restaient à réaliser sur les autres échangeurs.

Le chiffre de 1 140 m est **un total agrégé pour plusieurs échangeurs**. Il ne peut en aucun cas être attribué au seul échangeur des Charbonnages ni servir à fixer ses dimensions.

Source officielle : https://www.infrastructures.gouv.ga/387-travaux-publics/390-projets/391-projets-realises-et-mis-en-service-depuis-janvier-2010/

## 11. Conséquence pour la maquette

Le jeu peut désormais placer deux axes de circulation sur l'emprise du pont avec une orientation issue des tracés OSM. En revanche, la géométrie 3D détaillée reste bloquée jusqu'à obtention d'une source permettant de relever les largeurs, le profil en long, les piles, les culées et les bretelles. Les aménagements du jardin sous l'ouvrage et le chantier des abords en 2026 restent des objets temporels séparés du pont.


## 12. Écart entre le repère Mapcarta et les deux voies extraites

La fiche initiale cite le way `1443840888`, référencé par Mapcarta comme `man_made=bridge`. En revanche, la couche régionale extraite le 26 novembre 2026 contient les deux ways routiers `1443840889` et `1443840890`, mais ne contient pas le way `1443840888`.

Cet écart doit être résolu en comparant l'historique OSM et la version source Geofabrik utilisée par l'extraction. Il ne faut pas supposer que le way 888 est le contour géométrique des ways 889/890, ni fusionner ces identifiants. Pour le moment :
- way 888 : repère cartographique secondaire, géométrie non récupérée dans notre export ;
- ways 889/890 : deux lignes routières OSM extraites, chacune longue d'environ 57,4 m ;
- aucune emprise polygonale certifiée du tablier n'est disponible dans la couche extraite.

La maquette reste donc au stade du tracé routier de référence, pas du tablier 3D final.
