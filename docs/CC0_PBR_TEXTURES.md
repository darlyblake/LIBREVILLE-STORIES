# Matériaux PBR photoréalistes — LIBREVILLE STORIES

Le projet utilise déjà des textures haute définition pour les routes, le sol, l'herbe et les rochers. Cette bibliothèque ajoute des matériaux de surface photographiés, avec cartes PBR (couleur, normale, rugosité et parfois AO/déplacement) pour les façades, toitures, chaussées, sols et marchés.

## Source principale : Poly Haven

Les ressources 3D de Poly Haven sont publiées sous **CC0**. La bibliothèque peut donc les intégrer et les redistribuer avec le jeu. La documentation de l'API demande toutefois un crédit visible lorsque le projet utilise son API en direct ; le menu du jeu mentionne donc « Matériaux CC0 : Poly Haven ».

- Catalogue : https://polyhaven.com/textures
- API et conditions : https://polyhaven.com/our-api
- Dépôt public de l'API : https://github.com/Poly-Haven/Public-API

## Matériaux ciblés

| Asset ID | Usage dans Libreville |
|---|---|
| asphalt_02 | bitume des rues et parkings |
| concrete_floor_01 | dalles, cours et trottoirs |
| white_plaster_02 | façades d'hôpitaux et bâtiments publics |
| red_bricks_04 | murs en briques et constructions locales |
| corrugated_iron_03 | tôles ondulées, auvents et toitures |
| rusty_metal_02 | tôles vieillies, portails et détails |
| rough_wood | étals, planches, portes et mobilier |
| coast_sand_01 | sable côtier |
| sand_02 | sable humide et zones de plage |
| gravel_01 | sols non goudronnés |
| dirt | pistes et cours en terre |
| grass | surfaces végétales |

Le script vérifie le catalogue en direct : si un identifiant a été renommé ou retiré, il l'ignore sans bloquer les autres téléchargements.

## Télécharger la bibliothèque

Depuis la racine du dépôt :

```bash
python3 tools/download_cc0_textures.py
```

Par défaut, il télécharge les cartes en 2K. Pour une bibliothèque de qualité supérieure :

```bash
python3 tools/download_cc0_textures.py --resolution 4k
```

Les fichiers sont rangés dans `assets/textures/pbr/<asset_id>/`. Le script conserve les cartes disponibles (diffuse, normal OpenGL, roughness, AO, metalness, displacement) et un fichier `asset.json` contenant la provenance, les auteurs et la licence.

## Règles d'intégration

- Les textures 2K/4K sont conservées comme sources ; les réglages du jeu décideront du niveau de filtrage et du niveau de détail.
- Les cartes de normales utilisent la convention OpenGL.
- Les matériaux retombent sur les matériaux de secours du jeu si une texture n'a pas encore été téléchargée.
- Ne pas intégrer d'assets d'un autre dépôt sans vérifier leur licence fichier par fichier.
- Ne pas confondre la licence CC0 des images Poly Haven avec la licence AGPL du code de leur API.

## Crédit dans le jeu

« Matériaux PBR CC0 : Poly Haven — polyhaven.com »
