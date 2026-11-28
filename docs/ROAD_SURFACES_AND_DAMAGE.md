# Surfaces routières et dégradations — LIBREVILLE STORIES

## Règle de représentation

Le type de chaussée et son état sont deux informations différentes. Le jeu ne
doit pas inventer du goudron là où OSM indique de la terre, ni ajouter des
nids-de-poule à toutes les routes sans information.

- `surface=asphalt` ou `paved` : bitume normal, sauf si le tag
  `smoothness` indique explicitement un état mauvais.
- `smoothness=bad|very_bad|horrible|very_horrible|impassable` sur une
  surface goudronnée : matériau d'asphalte dégradé.
- `surface=gravel|fine_gravel|ground|dirt|earth|compacted|sand|mud` :
  route non goudronnée, rendue en gravier/terre compactée.
- `tracktype=grade2..grade5` : piste de qualité inférieure, classée non
  goudronnée pour le rendu.
- Tags absents : état inconnu. Le rapport les conserve comme inconnus ; il
  ne les transforme pas arbitrairement en routes goudronnées ou cassées.

## Textures PBR CC0 prévues

Les textures sont récupérées par `tools/download_cc0_textures.py` depuis
l'API officielle Poly Haven. La résolution recommandée pour le dépôt de jeu
est 2K ; le 4K est réservé aux plans rapprochés et aux captures haute qualité.

| Usage | Asset Poly Haven | Dossier du jeu |
|---|---|---|
| Bitume courant | asphalt_02, asphalt_03 | `assets/textures/pbr/` |
| Bitume usé/fissuré | road_damaged_2, road_damaged_clean | `assets/textures/pbr/` |
| Route en gravier/terre | gravel_road | `assets/textures/pbr/` |
| Sol terreux existant | dirt, gravel_01 | `assets/textures/pbr/` |

Les cartes couleur, normales, rugosité, AO et déplacement sont conservées
lorsqu'elles existent. Les fichiers sources sont CC0 ; les métadonnées de
l'auteur et de la source sont enregistrées avec chaque matériau.

Sources :
- https://polyhaven.com/a/road_damaged_2
- https://polyhaven.com/a/road_damaged_clean
- https://polyhaven.com/a/gravel_road
- https://polyhaven.com/a/asphalt_03

## Audit des données OSM

Exécuter depuis la racine du dépôt :

```bash
python3 tools/audit_road_surfaces.py
```

Le rapport `data/analysis/road_surface_audit.json` sépare les routes
non goudronnées, les surfaces goudronnées explicitement dégradées, les
indications de mauvaise planéité et les surfaces inconnues. Les longueurs
sont des estimations géographiques, pas un relevé topographique. L'audit
n'altère jamais les tracés ni ne raccorde automatiquement les routes.
