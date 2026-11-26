# Premier inventaire SIG des ponts dans l'emprise jouable

Mise à jour : 26 novembre 2026

## Résultat de l'extraction

La couche `data/osm/extended/bridges.geojson` a été produite par l'extraction Geofabrik/OpenStreetMap et validée par le workflow SIG GitHub Actions.

- 103 ways OSM explicitement balisés `bridge=*` ou `man_made=bridge` dans l'emprise élargie (0.300–0.500 N, 9.370–9.550 E).
- 84 ways ont au moins une coordonnée dans l'emprise de travail du jeu (0.355–0.445 N, 9.400–9.495 E).
- Ces 84 ways ne correspondent **pas à 84 ponts distincts** : certains ouvrages sont représentés par deux ways parallèles, certains sont des passerelles, des franchissements de petits cours d'eau ou des objets cartographiques très courts.
- La couche contient des tracés et emprises OSM, pas de profils altimétriques ni de modèles structurels.

Source et licence : © OpenStreetMap contributors, ODbL 1.0. Extraction datée du 26 novembre 2026.

## Ouvrages prioritaires identifiables dans la carte

Les coordonnées ci-dessous sont des repères approximatifs calculés à partir des géométries OSM ; elles ne sont pas des coordonnées d'implantation topographique certifiées.

| Ouvrage / repère OSM | Way(s) OSM | Repère approx. (lat, lon) | Lecture SIG et statut |
|---|---|---|---|
| Échangeur de l'Aéroport | 43157373, 43157376 | 0.4417, 9.4184 | Deux branches `trunk_link`, `bridge=viaduct`, `bridge:structure=beam`; à distinguer de l'échangeur Camp de Gaulle |
| Gué-Gué | 47290112, 47290115 | 0.4362, 9.4174 | Deux voies `primary`, viaduc ; ne pas confondre avec le futur/actuel Fly-over Camp de Gaulle |
| Échangeur Charbonnages | 1443840889, 1443840890 | 0.4365, 9.4409 | Deux ways `trunk`, `bridge=yes`, structure beam ; correspondance à recouper avec le dossier travaux |
| Échangeur Cité de la Démocratie | 448337123, 448836549 | 0.4255, 9.4560 | Deux ways nommés comme échangeur, `bridge=viaduct`; géométrie OSM à comparer aux bretelles réelles |
| Échangeur Nzeng-Ayong | 169184393, 169184394 | 0.4212, 9.4658 | Deux ways `trunk`, `bridge=viaduct/yes`; la longueur d'un way routier ne suffit pas à reconstruire le tablier complet |
| Échangeur PK5 | 1435847292 | 0.4079, 9.4691 | Emprise polygonale OSM `man_made=bridge`, `bridge=viaduct`, structure beam |
| Échangeur IAI | 170924097, 170924101 | 0.3709, 9.4761 | Deux ways `trunk`, `bridge=yes`; à confronter aux photos des glissières et à l'historique de drainage |
| Passerelle Plein-Ciel | 1435847294 | 0.3960, 9.4776 | Emprise polygonale OSM `man_made=bridge`, viaduc ; dimensions historiques publiées dans la fiche générale des ouvrages |
| Pont Awendjé | 1435825401 | 0.3864, 9.4747 | Emprise polygonale ; tag OSM inhabituel `bridge=aqueduct` avec `man_made=bridge`. À vérifier : ne pas corriger le tag sans preuve |
| Pont de la Caisse | 1395147722 | 0.41447, 9.46781 | Polygone OSM fermé, `man_made=bridge`, `bridge=viaduct`, structure beam ; dimensions non publiées |
| Pont de la RTG | 208495051 | 0.4203, 9.4532 | Way routier `secondary`, `bridge=yes`, structure beam ; identification à confirmer par photos |
| Pont d'Akébé | 1358983759 | 0.39287, 9.45889 | Way `secondary`, `bridge=yes`, structure beam |
| Pont M'pirah | 1328745502 | 0.38258, 9.44847 | Way `primary`, `bridge=viaduct`, structure beam |

## Contrôle de périmètre

Le pont Nomba (ways 92358873 et 92358874, repère autour de 0.3428 N, 9.4762 E) apparaît dans l'extraction régionale, mais se trouve au sud de la limite sud de l'emprise de travail 0.355 N. Il est donc exclu de cet inventaire de construction tant que l'emprise jouable n'est pas officiellement élargie.

Le pont du marché d'Oloumi n'apparaît pas sous ce nom dans la liste extraite. Sa fiche documentaire reste séparée ; il faudra rechercher l'objet OSM exact et vérifier son axe, sans assimiler un pont voisin à celui du marché.

## Sources externes de recoupement

- Charbonnages : L'Union, 28 août 2026, chantier de réaménagement des abords, durée annoncée de neuf mois : https://union.sonapresse.com/fr/voiries-vers-un-nouveau-look-lechangeur-des-charbonnages
- Charbonnages : marché public N°90/MTPC/SG/2025, réhabilitation de la Voie Express entre échangeurs Charbonnages et Lalala à droite : https://lejmp.com/marches_approuves/11/
- Camp de Gaulle : Gouvernement gabonais, 29 octobre 2025, projet Fly-over, pont et giratoire de 108 m : https://gouvernement.ga/2025/10/29/terrain/
- IAI : Gabon Media Time, 17 décembre 2025, état des glissières de sécurité : https://gabonmediatime.com/libreville-echangeur-diai-le-danger-permanent/
- Réseau des ouvrages et passerelles dans la zone nord/centre : appel d'offres public décrivant des lots d'intervention autour de PK5, Awendjé, IAI, Lalala, Charbonnages, Démocratie et Nzeng-Ayong : https://www.lejmp.ga/public/file_dossier/676143ae94db7.pdf

## Priorité de reconstruction

1. **Priorité A — ouvrages avec sources techniques et/ou dimensions publiées** : passerelle Plein-Ciel, passerelles ECOWOOD déjà documentées dans `docs/INVENTAIRE_OUVRAGES_ART_LIBREVILLE.md`, échangeurs Charbonnages, PK5, Nzeng-Ayong et IAI.
2. **Priorité B — ponts OSM identifiés mais dimensions insuffisantes** : Pont de la Caisse, Pont de la RTG, Pont d'Akébé, Pont M'pirah, Pont Awendjé.
3. **Priorité C — petits franchissements sans nom** : les inventorier par secteur et les rapprocher des cours d'eau avant toute modélisation.

Pour chaque ouvrage, l'étape suivante est d'associer le way OSM aux voies adjacentes, au cours d'eau éventuel, aux images datées et aux sources techniques. La modélisation 3D ne doit commencer qu'avec une orientation fiable ; la hauteur, les piles, les rampes et les largeurs restent des champs distincts à documenter.


## Mesures planimétriques des polygones OSM

Les géométries polygonales de la couche permettent de calculer une enveloppe et une aire cartographique approximatives. Le script reproductible `tools/map-generator/report_bridge_geometry.py` produit `data/osm/extended/bridge-geometry-report.json` à chaque extraction.

| Objet OSM | Enveloppe approximative | Aire cartographique | Interprétation prudente |
|---|---:|---:|---|
| Échangeur PK5 — way 1435847292 | 52,7 × 40,5 m | 952,1 m² | Polygone d'emprise OSM ; ne représente pas nécessairement le tablier seul |
| Pont de la Caisse — way 1395147722 | 44,3 × 11,1 m | 394,7 m² | Polygone OSM fermé ; à confronter au terrain et à l'imagerie |
| Pont Awendjé — way 1435825401 | 46,3 × 28,5 m | 439,6 m² | Polygone OSM ; tag `bridge=aqueduct` inhabituel, non interprété comme preuve d'aqueduc |
| Passerelle Plein-Ciel — way 1435847294 | 42,9 × 22,5 m | 174,9 m² | Emprise polygonale OSM ; à vérifier par relevé et photos |

**Important :** ces valeurs sont des métriques de la géométrie cartographique OSM, calculées dans une projection locale approximative. L'enveloppe n'est pas la longueur/largeur certifiée du tablier ; l'aire peut inclure des surfaces adjacentes ou une emprise simplifiée. Elles ne donnent ni la hauteur libre, ni l'épaisseur du tablier, ni les dimensions des piles, ni la pente des rampes. Elles servent à contrôler la cohérence spatiale et à préparer le relevé, pas à figer une maquette 3D métrique.

Le rapport est généré automatiquement avec la méthode et les avertissements dans son en-tête. Attribution : © OpenStreetMap contributors, ODbL 1.0.


## 9. État réel de l'intégration dans le moteur Godot (26 novembre 2026)

Le chargeur `game/scripts/world_map.gd` privilégie la couche régionale `data/osm/extended/roads.geojson` lorsqu'elle existe. Les tronçons routiers sont convertis par `_geo_to_road_point()`, qui échantillonne le MNT et place chaque point sur la surface du terrain. Ainsi, un way portant `bridge=yes` ou `bridge=viaduct` est actuellement rendu comme un tracé routier posé sur le relief, et non comme un pont surélevé.

Ce comportement est volontairement conservateur : les tags OSM `layer=1` et `bridge:structure=beam` indiquent une relation de niveau et un type structurel déclaré, mais ne donnent pas la cote du tablier, le profil des rampes, la hauteur libre, les piles ni les culées. Les utiliser pour inventer une élévation produirait une fausse reconstruction.

Le code a été instrumenté pour compter les objets portant un tag `bridge` dans la zone chargée et afficher explicitement au lancement que ces tracés restent provisoires au niveau du MNT. Cette ligne de diagnostic ne signifie pas que les ouvrages 3D sont construits.

### Conditions préalables à une reconstruction 3D

- relever les lignes d'axe et les emprises exactes de chaque ouvrage ;
- récupérer des profils en long et en travers, ou un modèle altimétrique suffisamment précis ;
- vérifier les cotes par rapport au MNT et aux voies inférieures ;
- identifier les piles, culées, murs de soutènement, joints et garde-corps sur des plans ou des photographies géolocalisées ;
- construire séparément le tablier, les rampes et les voies au sol ;
- valider la continuité des chaussées et les collisions dans Godot.

**Décision :** ne pas générer de pont surélevé automatique à partir du seul tag OSM. La couche OSM sert actuellement à positionner les axes et à guider le relevé, pas à certifier la géométrie structurelle.
