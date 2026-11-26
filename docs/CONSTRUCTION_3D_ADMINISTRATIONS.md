# Construction 3D des administrations — LIBREVILLE STORIES

> Suivi de production. Une case « modèle 3D » ne sera cochée qu'après création du GLB, intégration dans Godot et contrôle visuel. Les images génériques servent uniquement à définir une famille de matériaux, jamais à prétendre représenter une façade réelle.

## Objectif

Construire progressivement les administrations déjà géolocalisées dans `docs/PLAN_BATIMENTS_LIBREVILLE.md`, en conservant leur implantation OSM et leurs empreintes physiques. Les bâtiments ne doivent pas être déplacés, redimensionnés arbitrairement ni doublonnés par des volumes génériques.

Le jeu utilise Godot 4.3, le renderer Compatibility et des modèles Blender exportés en glTF 2.0 / GLB. La configuration de référence inclut une GeForce GT 730 2 Go : optimiser les textures, matériaux, collisions et niveaux de détail.

## État de départ vérifié

- [x] Inventaire administratif existant dans `docs/PLAN_BATIMENTS_LIBREVILLE.md`.
- [x] Repères institutionnels et données OSM intégrés dans `game/scripts/facility_generator.gd`.
- [x] Empreintes physiques des bâtiments générées par la carte depuis `data/osm/extended/buildings.geojson`.
- [x] Matériaux PBR chargés par le générateur lorsque les fichiers sont disponibles.
- [x] Script de téléchargement CC0 présent : `tools/download_cc0_textures.py`.
- [ ] Modèles détaillés spécifiques aux administrations ci-dessous.
- [ ] Textures photographiques propres à chaque bâtiment, après collecte de références autorisées.
- [ ] Intégration des GLB dans Godot et vérification en jeu.
- [ ] Mesure des performances sur la configuration cible.

**Important :** le générateur actuel `facility_generator.gd` ajoute des repères et panneaux institutionnels. Il ne constitue pas encore une reconstruction architecturale détaillée de chaque administration. Les empreintes OSM sont générées séparément par la carte. La prochaine intégration devra enrichir ou remplacer visuellement le bâtiment OSM correspondant sans créer un second bâtiment superposé.

## Lot 1 — administrations déjà localisées à traiter en priorité

| Site | Référence connue dans le plan | Référence architecturale | Modèle détaillé | Textures dédiées | Test Godot |
|---|---|---|---|---|---|
| Cour constitutionnelle | OSM way 410343353 | Photos réelles à collecter | [ ] | [ ] | [ ] |
| DGDDI — Douanes | OSM node 12727052424 | Photos réelles à collecter | [ ] | [ ] | [ ] |
| AGASA | OSM node 12832789224 | Photos réelles à collecter | [ ] | [ ] | [ ] |
| Institut National de Cartographie | OSM way / POI 793967943 | Photos réelles à collecter | [ ] | [ ] | [ ] |
| Chambre de Commerce | OSM way 456350865 ; 0.38419 / 9.44697 | Photos réelles à collecter | [ ] | [ ] | [ ] |

Les références OSM et les coordonnées doivent être relues dans le plan vivant avant toute implantation. La coordonnée de la Chambre de Commerce est celle déjà documentée dans ce plan.

## Lot 2 — autres bâtiments administratifs géolocalisés

Après le lot 1, suivre l'ordre du tableau « Administrations prioritaires » de `docs/PLAN_BATIMENTS_LIBREVILLE.md`. Il comprend notamment la Présidence, le Palais Léon Mba / Assemblée nationale, le Sénat, la Maison Georges Rawiri / RTG, les ministères, les directions générales, les mairies et les organismes publics.

Les bâtiments qui partagent un même immeuble (par exemple plusieurs ministères hébergés dans l'Immeuble Arambo) doivent partager une seule géométrie physique. Les occupants peuvent avoir des panneaux distincts, mais pas des volumes superposés.

## Bibliothèque de matériaux à télécharger

### Source principale : Poly Haven — CC0

Catalogue : https://polyhaven.com/textures

Le dépôt contient déjà le script `tools/download_cc0_textures.py`. Depuis la racine du projet, lancer :

```bash
python3 tools/download_cc0_textures.py --resolution 2k
```

Le script télécharge les cartes PBR et les métadonnées dans `assets/textures/pbr/<asset_id>/` et la HDRI disponible dans `assets/sky/`. Les identifiants absents du catalogue sont ignorés sans interrompre les autres téléchargements.

Matériaux déjà prévus par le script et utiles aux administrations :
- `white_plaster_02` : enduit clair des façades.
- `concrete_wall_009` et `brushed_concrete` : béton et surfaces minérales.
- `concrete_floor_01` : dalles, cours et escaliers.
- `metal_plate_02` et `rusty_metal_05` : menuiseries, grilles et structures métalliques.
- `rusty_metal_02` : métal vieilli et portails secondaires.
- `red_bricks_04` : maçonnerie lorsque les références du bâtiment le justifient.
- `corrugated_iron_03` : couverture métallique lorsqu'elle existe réellement.
- `rough_wood` : portes, auvents et détails en bois.

Ne pas appliquer systématiquement la même matière à tous les bâtiments. La sélection finale dépendra des photos et des observations du site.

### Matériaux spécifiques à compléter

- Verre architectural : matériau Godot dédié avec transparence maîtrisée, teinte, rugosité et reflets économiques ; éviter les grandes surfaces transparentes coûteuses.
- Béton peint et enduits colorés : variantes de teinte basées sur des références photographiques.
- Pierre claire / granit : parvis, marches et soubassements lorsqu'ils sont présents.
- Aluminium thermolaqué : cadres de fenêtres et portes.
- Signalétique : panneaux et lettrages propres à chaque institution, sans logos inventés.

## Composants géométriques à modéliser dans Blender

Créer une bibliothèque réutilisable de composants, puis composer chaque bâtiment à partir de ses références :
- socles, fondations visibles, marches et rampes ;
- murs, poteaux, poutres et dalles d'étage ;
- fenêtres, cadres, vitrages et protections solaires ;
- portes, halls d'entrée, auvents et marquises ;
- balcons, garde-corps, coursives et escaliers ;
- toitures, acrotères, chéneaux et descentes d'eau ;
- climatiseurs, grilles de ventilation et équipements de toiture ;
- clôtures, portails, barrières, bornes et éclairage extérieur ;
- panneaux institutionnels et numéros d'adresse ;
- trottoirs, cours, parkings et bordures, uniquement si l'emprise et les références les confirment.

Les composants communs peuvent être mutualisés en meshes et matériaux. Les proportions, le nombre d'étages, les ouvertures, les couleurs et la silhouette doivent rester propres à chaque bâtiment.

## Chaîne de production

1. Vérifier le point GPS, l'empreinte OSM et l'identifiant de l'objet.
2. Collecter plusieurs vues réelles : façade principale, côtés, arrière si possible, toiture et environnement immédiat.
3. Relever les proportions, niveaux, accès, matériaux et détails visibles. Distinguer les mesures connues des estimations.
4. Créer le modèle Blender à l'échelle métrique, avec pivot et orientation documentés.
5. Déplier les UV et affecter les matériaux PBR CC0 ou les textures autorisées.
6. Exporter en GLB avec textures intégrées, collisions simplifiées et LOD si nécessaire.
7. Relier le GLB à l'empreinte OSM existante dans Godot sans doublon ni décalage géographique.
8. Contrôler l'échelle, l'orientation, les collisions, le rendu de jour et de nuit et les performances sur la GT 730.
9. Cocher les cases du présent document et du plan principal uniquement après validation.

## Logiciels et ressources

- Blender 4.5 LTS : https://www.blender.org/download/lts/4-5/
- Godot 4.3 : https://godotengine.org/download/archive/4.3-stable/
- GIMP : https://www.gimp.org/downloads/
- Krita : https://krita.org/en/download/
- Poly Haven : https://polyhaven.com/textures
- ambientCG : https://ambientcg.com/

## Règles de qualité et de licence

- Les textures Poly Haven utilisées doivent conserver leur métadonnée `asset.json` et leur provenance CC0.
- Vérifier la licence de chaque ressource externe avant intégration.
- Les photographies de bâtiments réels sont des références ; ne pas les intégrer directement comme textures sans autorisation ou licence adaptée.
- Ne jamais présenter une texture générique comme une photographie de l'administration.
- Ne pas cocher « Modèle détaillé » à la seule présence d'un marqueur, d'un panneau ou d'un volume cubique.
- Ne pas cocher « Test Godot » tant que le GLB n'a pas été importé et contrôlé dans la scène jouable.

## Historique

- 2026-11-26 : inventaire du générateur existant, des empreintes OSM, de la bibliothèque PBR et du script de téléchargement. Démarrage de la préparation de production des administrations ; aucun modèle détaillé n'est déclaré terminé à cette étape.
