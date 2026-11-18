# Implantation GPS — kiosques de la Baie des Rois

## Références prioritaires

- Les captures `Capture7.PNG`, `Capture8.PNG` et `Capture9.PNG` du dossier `assets/models/image geographique/` restent les références prioritaires pour l'implantation des kiosques. La capture 7 représente notamment les deux rangées qui se font face.
- Les photos publiques de la promenade de la Baie des Rois servent de références architecturales et paysagères : dallage clair, pelouses en îlots, palmiers espacés, mobilier urbain discret, garde-corps ajourés et kiosques/pavillons en bois.
- Les données `data/osm/environment.geojson` du projet apportent des géométries locales du littoral et des espaces verts. Elles doivent primer sur les anciens placements décoratifs approximatifs lorsqu'elles couvrent la zone.

## Coordonnées GPS communiquées

Les trois coordonnées sont exprimées en latitude, longitude (WGS84).

| Repère | Latitude | Longitude | Rôle |
|---|---:|---:|---|
| P1 | 0.40392567507842964 | 9.431029723961437 | Premier kiosque de la rangée A |
| P2 | 0.4038486056410187 | 9.430125017741204 | Dernier kiosque communiqué de la même rangée A |
| P3 | 0.403847888849537 | 9.431017268453365 | Point supposé sur la rangée opposée |

## Conversion avec le repère de world_map.gd

La conversion reprend exactement les constantes du projet : `CENTER_LAT = 0.400`, `CENTER_LON = 9.4475` et `METERS_PER_DEG_LAT = 111320.0`.

| Repère | X monde (m) | Z monde (m) |
|---|---:|---:|
| P1 | -1833.43 | -437.01 |
| P2 | -1934.14 | -428.43 |
| P3 | -1834.81 | -428.35 |

**Correction importante :** ces valeurs recalculées remplacent les conversions erronées données dans un précédent message.

## Géométrie des deux rangées

- La distance P1–P2 est d'environ **101,1 m**.
- L'axe de la rangée A est presque ouest-est, avec une légère composante nord-sud.
- P3 est à environ **8,77 m** de P1.
- En projetant P3 perpendiculairement à l'axe P1–P2, l'écartement indicatif entre les axes des rangées est d'environ **8,51 m**.
- Cette valeur est une estimation issue du point P3, pas une mesure certifiée de la largeur de la chaussée.
- Après analyse du rapport routier local, le helper applique désormais des reculs provisoires différenciés : **6,5 m pour la rangée A** (côté route secondaire) et **4,5 m pour la rangée B**. Le calcul tient compte du gabarit actuellement utilisé par le jeu (chaussée 9 m, trottoir 1,55 m et bordure 0,22 m de chaque côté) et de la profondeur de 3,6 m des kiosques. Ces valeurs de largeur sont des hypothèses de rendu, pas des mesures de terrain ; le contrôle visuel dans Godot reste obligatoire.

## Premiers constats issus du GeoJSON environnemental

Le fichier `data/osm/environment.geojson` a été examiné autour des coordonnées P1, P2 et P3, avec le même repère métrique que `world_map.gd`.

- Le segment de littoral OSM le plus proche est l'entité `way/443854943` (`natural=coastline`, source indiquée : Mapbox + Landsat8).
- La distance minimale calculée entre ce littoral et les trois repères est d'environ **29 à 38 m**. Les points de littoral les plus proches se trouvent dans la direction du **+Z monde** par rapport aux kiosques.
- Plusieurs polygones OSM de type `vegetation` / `landuse=grass` sont présents à proximité. Le fichier comprend notamment les entités `way/1070652050`, `way/1070652051`, `way/1070652052`, `way/1070652053` et `way/1070652055`.
- Ces polygones sont déjà chargés par `world_map.gd` dans `_load_environment()`. Il faut donc éviter de créer par-dessus des rectangles de pelouse inventés qui pourraient masquer ou contredire les formes cartographiées.
- Le littoral OSM est une ligne de référence cartographique, pas une mesure de la limite exacte du dallage ou de la promenade. Il ne suffit pas à déterminer la largeur des trottoirs.

## Détail géométrique des espaces verts au droit des kiosques

Une extraction ciblée de `data/osm/environment.geojson` autour de P1–P3 confirme plusieurs surfaces végétalisées cartographiées. Les surfaces ci-dessous sont calculées avec la conversion exacte de `world_map.gd` (axe Z inversé par rapport à la latitude) :

| Entité OSM | Type OSM | Surface approximative | Emprise monde X/Z (m) |
|---|---|---:|---|
| `way/1070652050` | bande de gazon | 455 m² | X -1838 à -1802 ; Z -418 à -403 |
| `way/1070652051` | bande de gazon | 363 m² | X -1898 à -1869 ; Z -416 à -401 |
| `way/1070652052` | bande de gazon | 362 m² | X -1940 à -1912 ; Z -411 à -394 |
| `way/1070652053` | bande de gazon | 296 m² | X -1787 à -1764 ; Z -415 à -399 |
| `way/1070652054` | bande de gazon | 348 m² | X -1736 à -1708 ; Z -407 à -387 |
| `way/1070652055` | grand espace végétalisé | 1 768 m² | X -1942 à -1696 ; Z -429 à -403 |

Ces surfaces sont déjà triangulées et affichées par `world_map.gd`. La grande entité 1070652055 forme une bande allongée à proximité du côté +Z des rangées GPS ; les cinq autres entités sont des îlots/bandes plus petites. Il faut conserver leurs contours OSM et ne pas les remplacer par des rectangles de pelouse.

**Limite des données :** le fichier `roads.geojson` est présent dans le dépôt, mais son contenu n'a pas pu être lu via l'interface GitHub utilisée pour cette inspection. Je ne peux donc pas en déduire ici le bord exact de la chaussée, des trottoirs ou du dallage. Aucun mesh de promenade ne doit être posé à partir d'une largeur supposée.

## Extraction locale des routes et trottoirs

Le GeoJSON des routes est trop volumineux pour être inspecté directement depuis l'interface GitHub. Un outil de diagnostic local a donc été ajouté : `tools/python/analyze_baie_des_rois_roads.py`.

Depuis la racine du dépôt, exécuter :

```powershell
python tools/python/analyze_baie_des_rois_roads.py
```

Le script lit `data/osm/roads.geojson`, reprend la conversion GPS de `world_map.gd` et les règles de largeur/trottoirs du moteur, puis écrit `data/analysis/baie_des_rois_roads_report.json`. Il affiche aussi les axes routiers les plus proches des deux rangées.

Le rapport sert à identifier les routes candidates et les largeurs de trottoir actuellement générées par le jeu. **Ce n'est pas un relevé topographique** : les largeurs OSM absentes sont des valeurs de représentation du jeu, et les limites de bordure restent estimatives. Le dallage spécifique de la promenade ne sera créé qu'après examen de ce relevé.

## État actuel du code à surveiller

- `game/scripts/baie_des_rois.gd` instancie actuellement quatre kiosques par rangée, soit huit au total, aux progressions `[0.08, 0.36, 0.64, 0.92]`.
- Les rotations de façade ont été inversées pour essayer d'orienter les ouvertures vers le passage central. Cette orientation reste à confirmer visuellement dans Godot.
- Les reculs extérieurs provisoires sont différenciés : 6,5 m pour la rangée A et 4,5 m pour la rangée B. Le journal de démarrage affiche les deux valeurs.
- Le mobilier est actuellement placé par décalages fixes : palmiers à 7,2 m, lampadaires à 5,7 m et bancs à 6 m des axes de rangée. Ces valeurs sont provisoires et ne prouvent pas que les objets sont hors de la chaussée ou du trottoir.
- Les anciens générateurs de promenade, d'eau, de pelouse et de mobilier dans `baie_des_rois.gd` sont des placeholders historiques. Ils ne doivent pas être réactivés sans reconstruction géométrique adaptée.

## Règles de reconstruction

1. Conserver les coordonnées GPS et l'alignement longitudinal des deux rangées.
2. Garder le passage client central entièrement libre ; les façades commerciales doivent être tournées vers ce passage.
3. Reculer les kiosques vers les emplacements réellement occupés sur le terrain, sans les poser sur la route ni sur le trottoir.
4. Construire séparément chaussée, trottoirs/dallage, pelouses et bordures. Ne pas utiliser un grand rectangle unique pour toute la promenade.
5. Utiliser les polygones OSM existants pour les pelouses lorsqu'ils correspondent à la zone ; compléter uniquement les manques confirmés.
6. Placer palmiers, bancs et lampadaires dans les espaces paysagers ou les bandes extérieures, jamais au milieu du cheminement piéton.
7. Garder des garde-corps ajourés près du bord d'eau lorsque les références photographiques et la géométrie locale le justifient.
8. Distinguer les éléments réellement visibles sur les photos de la zone des projets ou aménagements annoncés pour d'autres secteurs de la Baie des Rois.
9. Optimiser les meshes et matériaux pour la cible modeste du projet (GT 730 2 Go) : peu de matériaux, géométries groupées et végétation légère.

## Ce qui reste à confirmer avant de figer les positions

- La limite exacte de la route et des trottoirs au droit des kiosques.
- Le côté précis de chaque bande paysagère et la largeur des zones pavées.
- L'orientation finale des façades des GLB dans le jeu.
- La correspondance définitive de P3 avec le centre du kiosque opposé.
- La position exacte des bancs, lampadaires et arbres par rapport aux cheminements.

## Prochaine étape technique

Contrôler dans Godot les reculs provisoires différenciés (6,5 m pour A et 4,5 m pour B), puis délimiter une première section de promenade autour des deux rangées à partir des coordonnées GPS et des contours OSM, sans poser de mobilier dans le passage. Le contrôle visuel dans Godot reste indispensable avant de considérer les positions comme validées.


## Résultats de l'analyse locale des axes routiers (18 novembre 2026)

Le script a été exécuté sur le fichier local `data/osm/roads.geojson`. Il a trouvé **21 entités routières/piétonnes** à moins de 65 m des rangées GPS. Les résultats les plus importants sont :

| Entité | Type OSM | Rangée la plus proche | Distance entre axes |
|---|---|---:|---:|
| Promenade zone nord | footway | A | 0,00 m |
| `way/1070652022` à `way/1070652026` | footway | B | 0,00 m |
| `way/1085115438` | footway | B | 0,00 m |
| `way/708322894` | secondary | A | 1,84 m |
| `way/1070652021` | footway | B | 6,69 m |
| `way/1070652027` | footway | A | 8,12 m |
| `way/1070652020` | footway | B | 14,19 m |
| Promenade zone nord | path | B | 15,57 m |

### Interprétation et conséquence pour l'implantation

- Les distances de **0,00 m** indiquent que les axes GPS de référence des rangées se superposent à des axes de chemins OSM. Cela ne prouve pas que les kiosques doivent occuper le chemin : cela montre au contraire que les coordonnées de rangée et les cheminements cartographiés doivent être distingués avant de figer les positions.
- La route secondaire `way/708322894` est très proche de la rangée A : son axe est à **1,84 m**. Le jeu lui attribue une largeur de 9 m et le mode de trottoirs `both`, mais ces valeurs sont des règles de rendu/fallback du jeu, pas des mesures de terrain. On ne peut donc pas en déduire la limite réelle de la chaussée.
- Les axes des chemins OSM sont des lignes centrales. La largeur de 1,8 m affichée par le script est également la largeur par défaut utilisée par le jeu pour un `footway` ou un `path`, pas une largeur relevée sur place.
- Le rapport complet local contient les coordonnées X/Z des lignes candidates. Il faut examiner ces géométries pour déterminer de quel côté des rangées se trouvent les chemins, puis confronter cela aux références photographiques et aux captures du dépôt.

**Décision intermédiaire :** le rapport complet a maintenant été partagé pour la promenade nord et la route secondaire. Le gabarit actuellement utilisé par le jeu justifie un recul A plus important (6,5 m) et le maintien de 4,5 m pour B. Les largeurs restant des hypothèses de rendu, cette implantation doit être vérifiée dans Godot avant toute reconstruction des dalles.


### Vérification géométrique du gabarit routier au droit de la rangée A

Le rapport détaillé fourni depuis la machine locale confirme trois lignes utiles :

- `way/1070652019`, « Promenade zone nord » (`footway`) : axe à 0,00 m de la rangée A.
- `way/708322894` (`secondary`) : axe à 1,84 m de la rangée A. Le modèle du jeu lui applique une chaussée de 9 m, des trottoirs de 1,55 m et des bordures de 0,22 m de chaque côté.
- `way/709255549`, autre « Promenade zone nord » (`path`) : axe à 15,57 m de la rangée B.

Avec le gabarit théorique du jeu, le bord extérieur chaussée + trottoir + bordure se trouve à 6,27 m de l'axe de la route secondaire. Le centre de la rangée A, après un recul de 4,5 m à l'opposé de la route, se trouverait à 6,34 m de cet axe. Pour un kiosque de 3,6 m de profondeur, son bord le plus proche de la route serait encore à environ 4,54 m de l'axe routier : le trottoir théorique pourrait donc empiéter d'environ 1,73 m sur son emprise. Un recul de 6,5 m place ce bord à environ 6,54 m de l'axe routier, soit une marge théorique d'environ 0,27 m au-delà du gabarit trottoir/bordure.

La rangée B est du côté opposé à la route secondaire. Avec son recul conservé à 4,5 m, son bord le plus proche de cette route est à environ 9,37 m de l'axe routier, au-delà du gabarit théorique de 6,27 m.

**Décision provisoire appliquée au code :** recul A = 6,5 m ; recul B = 4,5 m. Cela évite de déplacer inutilement la rangée B et limite l'élargissement du passage client. Ce calcul reste fondé sur les largeurs de rendu du jeu ; il ne remplace pas une mesure de terrain ni le contrôle visuel dans Godot.
