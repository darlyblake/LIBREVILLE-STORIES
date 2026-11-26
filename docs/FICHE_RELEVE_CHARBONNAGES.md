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
