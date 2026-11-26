# Inventaire de travail — écoles et hôtels de Libreville

**Projet :** LIBREVILLE STORIES  
**Date de recherche :** 26 novembre 2026  
**Sources géographiques de production :** OpenStreetMap (ODbL) et empreintes bâtiments OSM  
**Sources de contrôle des noms/adresses :** sites officiels des établissements, annuaires gabonais, documents institutionnels.

## 0. Emprise de création validée — filtre obligatoire

**Emprise jouable à respecter pour tous les établissements :**
- latitude sud : **0.355**
- longitude ouest : **9.400**
- latitude nord : **0.445**
- longitude est : **9.495**

Cette emprise est celle de travail validée dans l'inventaire SIG des ponts. L'extraction OSM étendue peut contenir des objets situés en dehors ; ils restent des données de référence et ne doivent jamais devenir des bâtiments du jeu.

Règles d'instanciation :
- aucune limite arbitraire de huit écoles : tous les POI scolaires présents dans l'emprise sont considérés ;
- universités classées séparément des écoles ;
- hôtels et résidences hôtelières uniquement si leurs coordonnées sont dans l'emprise ;
- hôpitaux et centres de santé uniquement si leurs coordonnées sont dans l'emprise ;
- les POI extérieurs sont rejetés avant leur conversion en coordonnées 3D.

Le générateur parcourt tous les POI admissibles de l'emprise, sans plafond global de 100 établissements ni plafond de huit écoles. La déduplication spatiale de 18 m évite de créer plusieurs volumes superposés pour un même site. Il écrit les établissements effectivement retenus dans `user://libreville_facilities_gps.csv`, avec le type, le nom, l'identifiant OSM et les coordonnées GPS latitude/longitude. Il affiche aussi ces coordonnées dans la console Godot. Ce relevé permet de contrôler précisément les objets placés en jeu.

## 1. Règle de construction

Les établissements ne doivent pas être placés à la main sur une coordonnée approximative. La production utilise les POI nommés de `data/osm/extended/pois.geojson` et les empreintes de `data/osm/extended/buildings.geojson` quand elles sont disponibles.

Le générateur reconnaît maintenant les catégories OSM :
- écoles : `amenity=school|kindergarten|college|university`, ainsi que les bâtiments explicitement étiquetés école/collège/université ;
- hébergements : `tourism=hotel|guest_house|hostel|motel` et bâtiments explicitement étiquetés hôtel/maison d'hôtes.

Les coordonnées OSM déterminent le placement. Les textures PBR CC0 déjà téléchargées depuis Poly Haven habillent les matériaux. Les volumes de façade ajoutés par le générateur restent des **blockouts de gameplay**, pas des relevés architecturaux certifiés. Un nom retrouvé dans un annuaire ne suffit pas à créer un bâtiment : il faut un objet géographique OSM localisé.

## 1 bis. Comptage réel de l'extraction OSM du 26 novembre 2026

L'artefact géographique produit par l'extraction Geofabrik/OSM contient **3 302 POI** dans l'emprise étendue (0,300–0,500° N ; 9,370–9,550° E). Le rapport d'extraction donne les catégories suivantes :
- 173 objets classés « school » ;
- 33 objets classés « college » ;
- 53 objets classés « hotel » ;
- 3 objets classés « hostel » ;
- 12 objets classés « guest_house » ;
- 30 objets classés « motel ».

Après application du rayon actuel du générateur (2 600 m autour du centre de la carte, 0,400° N / 9,4475° E), le contrôle spatial des géométries POI trouve **63 candidats scolaires** et **26 candidats d'hébergement**. Ce sont des objets OSM, pas 89 bâtiments reconstruits à l'échelle réelle : certains POI sont des points sans empreinte bâtie, certains noms sont absents, et plusieurs établissements peuvent avoir plusieurs objets OSM.

Le générateur limite toujours l'ensemble des équipements à 100 sites pour préserver les performances. Depuis le commit de priorité, les catégories « school » et « hotel » sont triées avant les autres équipements ; les plus proches du centre sont retenus en premier dans chaque catégorie. Le nombre réellement instancié peut donc être inférieur aux candidats si des objets sont trop proches (déduplication de 18 m) ou si la géométrie est invalide.

**Source de données :** extraction OpenStreetMap / Geofabrik du 26-11-2026, licence ODbL 1.0. Attribution : © OpenStreetMap contributors. Les fichiers GeoJSON complets sont conservés dans l'artefact GitHub Actions « libreville-osm-extended » du dépôt.

## 2. Établissements scolaires repérés dans les sources

| Établissement | Secteur / repère publié | Référence |
|---|---|---|
| Lycée français Blaise Pascal | Carrefour des Charbonnages, BP 20150 | Site officiel : https://www.lyceefrancaislibreville.org/ |
| Lycée d'Application Nelson Mandela | Secteur Université Omar Bongo, plus code CCCW+X6P | Fiche cartographique / établissement |
| Lycée et Collège Notre-Dame de Quaben | Quartier Louis, Montée Louis, plus code CC6J+P2Q | Fiche cartographique / établissement |
| Lycée Franco-Britannique — École Internationale du Gabon | Batterie IV, BP 159 | Fiche cartographique / établissement |
| Lycée Paul Indjendjet Gondjout (Lycée d'État de l'Estuaire) | Libreville | Fiche cartographique / établissement |
| Université Omar Bongo | Avenue / boulevard Léon Mba | Fiche cartographique / établissement |
| Lycée Technique National Omar Bongo | Owendo, Grand Libreville | Fiche cartographique / établissement |
| École Supérieure d'Hôtellerie de Libreville | Angodjé, Cité Sherko, BP 25144 | Fiche cartographique / établissement |

Les repères ci-dessus servent au contrôle de cohérence des noms et secteurs. Ils ne remplacent pas les coordonnées OSM et ne sont pas convertis en positions de jeu.

## 3. Hôtels et résidences hôtelières répertoriés

| Établissement | Secteur / adresse publiée | Référence |
|---|---|---|
| Radisson Blu Okoumé Palace | 5, boulevard de Nice, bord de mer | ANAC/OACI : https://www.icao.int/es/filebrowser/download/23600?fid=23600 |
| Park Inn by Radisson | 7, boulevard de Nice, bord de mer | ANAC/OACI : https://www.icao.int/es/filebrowser/download/23600?fid=23600 |
| Hôtel Le Cristal | Centre-ville, place de l'Indépendance | Le Pratique du Gabon |
| Fly Hotel Gabon | Aéroport international Léon-Mba | Le Pratique du Gabon |
| Hôtel Akewa | Batterie IV, face à l'école Gros Bouquet II | Le Pratique du Gabon |
| Hôtel Le Jomonia | 727, avenue Emma Adande Akéré Odidi, Bas de Gué-Gué | Le Pratique du Gabon |
| Hôtel Glass / Les Orchidées | Glass, entrée Michel Marine | Annuaire local |
| Hôtel Hibiscus | Boulevard Omar Bongo Ondimba / Louis | Le Pratique du Gabon |
| Hôtel Leet Dorian | Montagne Sainte, rue d'Alsace-Lorraine | Le Pratique du Gabon |
| Nomad Hôtel / Résidence Nomad | La Sablière / secteur de l'aéroport | Le Pratique du Gabon |
| Onomo Libreville | La Sablière | Le Pratique du Gabon |
| Hôtel de la Sablière | La Sablière, front de mer | Le Pratique du Gabon |
| Résidence Hôtelière du Phare | La Sablière | Le Pratique du Gabon |
| Hôtel Les 9 Provinces | Owendo, face à COMILOG | Le Pratique du Gabon |

Annuaire de référence consulté : https://lepratiquedugabon.devovianet.com/rubrique/libreville/  
Autre annuaire consulté : https://www.miboue.com/hotels-2/

Les annuaires peuvent être incomplets ou conserver des fiches anciennes. Les établissements listés sont des candidats de contrôle, pas une déclaration qu'ils sont tous actuellement ouverts.

## 4. Références visuelles et textures

### Textures utilisées dans le jeu

Le générateur utilise les matériaux PBR déjà présents dans `assets/textures/pbr/` :
- enduit clair : `white_plaster_02` ;
- béton de structure : `concrete_wall_009` ;
- béton brossé : `brushed_concrete` ;
- tôle / éléments métalliques : `metal_plate_02` ;
- toiture métallique ondulée : `corrugated_iron_03` ;
- enrobé des accès : `asphalt_03`.

Sources et licences :
- https://polyhaven.com/a/white_plaster_02
- https://polyhaven.com/a/concrete_wall_009
- https://polyhaven.com/a/brushed_concrete
- https://polyhaven.com/a/metal_plate_02
- https://polyhaven.com/a/corrugated_iron_03
- https://polyhaven.com/a/asphalt_03

Ces textures sont des matériaux génériques CC0, pas des scans photographiques des façades gabonaises. Les façades propres à chaque établissement devront être affinées à partir de photos de terrain ou de vues aériennes récentes, avec vérification des droits d'utilisation.

### Références photographiques

- Le lycée Blaise Pascal publie des photographies de son établissement sur son site officiel, notamment dans ses actualités et la page « Entrées et sorties des usagers » : https://www.lyceefrancaislibreville.org/entrees-et-sorties-des-usagers/
- Les hôtels Radisson publient des photos officielles sur leurs pages de marque : https://www.radissonhotels.com/
- Pour les autres établissements, rechercher des photos géolocalisées ou des visites de terrain avant de reproduire une façade particulière.

Les photos trouvées en ligne ne sont pas copiées dans les fichiers du jeu sans licence explicite. Elles servent à guider les proportions, les couleurs et les détails, pas à être redistribuées comme textures.

## 5. État de l'implémentation

Le script `game/scripts/facility_generator.gd` reconnaît désormais les écoles et les hôtels à partir des catégories OSM et leur attribue des silhouettes distinctes :
- écoles : volume bas/étendu, entrée et signalétique scolaire ;
- hôtels : volume plus vertical, bandeau de toiture, entrée couverte et vitrage.

Le placement dépend du POI OSM et de la hauteur terrain. Les écoles et hôtels passent désormais en priorité dans la limite de 100 équipements, puis les autres services sont ajoutés avec les places restantes. Les dimensions générées sont des dimensions de représentation provisoire, pas les dimensions réelles des bâtiments. Les établissements non présents dans la couche OSM locale ne sont pas artificiellement créés.

**Contrôle à effectuer dans la prochaine validation Godot :** vérifier le nombre d'écoles et d'hôtels effectivement détectés dans les données extraites, puis corriger les objets OSM manquants ou mal classés avant de détailler chaque façade.
