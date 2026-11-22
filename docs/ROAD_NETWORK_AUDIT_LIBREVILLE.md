# Audit du réseau routier — Libreville Stories

Date de vérification : 22 novembre 2026

## Données réellement présentes dans le dépôt

Le jeu utilise `data/osm/roads.geojson`, extrait d'OpenStreetMap le 17 novembre 2026. Le rapport associé indique 4 503 entités routières dans une emprise de coordonnées `[0.355, 9.4, 0.445, 9.495]`, découpée en 4 × 4 cellules.

Répartition enregistrée dans `data/osm/extraction-report.json` :

| Classe OSM | Entités |
|---|---:|
| residential | 1 914 |
| service | 1 059 |
| secondary | 374 |
| primary | 145 |
| trunk | 67 |
| tertiary | 200 |
| trunk_link | 114 |
| primary_link | 151 |
| secondary_link | 102 |
| tertiary_link | 97 |
| unclassified | 44 |
| footway | 149 |
| path | 54 |
| construction | 27 |
| pedestrian | 1 |
| steps | 2 |
| track | 3 |
| **Total** | **4 503** |

Ces chiffres prouvent que les classes secondaires et les rues locales sont présentes dans l'extraction. Ils ne prouvent pas, à eux seuls, que chaque rue réelle de Libreville est cartographiée ni que chaque segment possède des tags de largeur et de nombre de voies.

## Vérifications sur des tronçons nommés

Des fiches publiques basées sur les données OSM donnent des exemples précis :

- Boulevard Triomphal Omar Bongo, way OSM 1330722297 : `highway=primary`, `lanes=2`, `lanes:forward=2`, `oneway=yes`, `width=5`, `surface=asphalt`.
- Boulevard de l'Indépendance, way OSM 1329845525 : `highway=primary`, `lanes=2`, `lanes:forward=2`, `oneway=yes`, `surface=asphalt`.

Le premier exemple montre pourquoi il ne faut pas accepter aveuglément `width=5` quand le même tronçon indique deux voies. Le générateur donne alors priorité au nombre de voies et calcule un gabarit cohérent. Les voies OSM à sens unique sont traitées comme des chaussées individuelles ; il ne faut pas leur dessiner une ligne centrale séparant artificiellement deux sens.

## Règles appliquées dans le générateur

Dans `game/scripts/world_map.gd` :

- Les tags `lanes:forward` et `lanes:backward` priment pour répartir les voies par sens.
- `lanes:both_ways` n'est pas additionné au total : il décrit une voie centrale partagée, pas une voie automobile supplémentaire dans chaque sens.
- `oneway=yes` et `oneway=-1` déclenchent le traitement d'une chaussée à sens unique.
- Les voies directionnelles reçoivent leurs séparations internes ; les routes bidirectionnelles conservent un marquage central.
- Quand le nombre impair de voies ne précise pas la répartition par sens, le générateur n'invente pas de répartition symétrique.
- Les routes secondaires, tertiaires, résidentielles et de service restent différenciées.

## Limites à ne pas masquer

La page locale OpenStreetMap de Libreville signale que de nombreuses routes résidentielles manquent encore, particulièrement en périphérie. L'extraction du dépôt ne peut donc pas être considérée comme un inventaire exhaustif de toutes les rues construites.

Les 4 503 entités sont des objets OSM, pas 4 503 rues distinctes. Une même rue peut être découpée en plusieurs segments et un boulevard à chaussées séparées peut avoir plusieurs entités.

La validation Godot headless vérifie le chargement et l'analyse du projet ; elle ne remplace pas un contrôle visuel des carrefours, terre-pleins, largeurs et raccords dans le jeu.

## Sources de référence

- Rapport d'extraction du dépôt : `data/osm/extraction-report.json`.
- Données cartographiques : OpenStreetMap, © contributeurs.
- Libreville — OpenStreetMap Wiki : https://wiki.openstreetmap.org/wiki/Libreville
- Inventaire des rues et classes OSM de Libreville : https://osm2cdr.com/en/map/gabon/estuaire/libreville-27565068/
- Boulevard Triomphal Omar Bongo, way OSM 1330722297 : https://ga.geoview.info/boulevard_triomphal_omar_bongo%2C11330722297w
- Boulevard de l'Indépendance, way OSM 1329845525 : https://ga.geoview.info/boulevard_de_lindependance%2C11329845525w

Les fiches de tronçons sont des instantanés OSM publiés par un service tiers ; elles peuvent évoluer si OpenStreetMap est modifié.
