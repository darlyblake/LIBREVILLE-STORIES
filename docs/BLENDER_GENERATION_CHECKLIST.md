# Inventaire des générations Blender — LIBREVILLE STORIES

Dernière vérification du dépôt : 22 novembre 2026.

Ce document distingue les scripts existants, les GLB déjà versionnés et les éléments qui attendent encore les textures. Un script présent dans Git n'implique pas que l'utilisateur l'a exécuté localement ; les fichiers GLB listés comme présents sont ceux réellement visibles dans le dépôt.

## 1. Nouveau générateur unique des monuments

Script à lancer :
`tools/blender/generate_libreville_landmarks.py`

Commande depuis la racine du dépôt :

```bash
blender --background --python tools/blender/generate_libreville_landmarks.py
```

Il exporte dans `assets/models/landmarks/` :

- `eglise_saint_michel_nkembo.glb` — volume de l'église, toiture à deux pans, bandeau de mosaïque, entrée, piliers en bois sculpté stylisés et structure de cloche.
- `cathedrale_sainte_marie_libreville.glb` — nef, façade jaune, vitraux, contreforts, charpente apparente et clocher.
- `mission_protestante_baraka_site.glb` — bâtiments de l'ancienne école, galeries en bois, église, toiture métallique ancienne et clôture.

**Important :** ces modèles sont une première reconstruction géométrique à partir des descriptions et photographies documentées. Les détails sculptés, mosaïques exactes, proportions de relevé et matériaux PBR devront être affinés avec des références photographiques supplémentaires. Le générateur ne place pas les modèles sur la carte : l'implantation GPS sera une étape séparée, après vérification des emprises OSM.

Références consultées :
- Saint-Michel : https://www.libreville-accueil-bal.org/pages/archives/nos-activites/culturelles/eglises-st-michel-et-nd-de-lourdes.html
- Saint-Michel, photographies et détails : https://lunion-archives.org/web.11/dmdocuments/N12058-16-02-2016-024.pdf
- Sainte-Marie, aspect restauré : https://union.sonapresse.com/fr/cathedrale-sainte-marie-ouverture-officielle-des-portes
- Mission Baraka : https://www.union.sonapresse.com/fr/node/19830

## 2. Baie des Rois — scripts à exécuter / régénérer

Lancer chaque script depuis la racine du dépôt, avec Blender 5.3 :

```bash
blender --background --python tools/blender/create_baie_des_rois_kiosk.py
blender --background --python tools/blender/create_baie_des_rois_kiosk_type_b.py
blender --background --python tools/blender/create_baie_des_rois_props.py
blender --background --python tools/blender/create_baie_des_rois_restaurants.py
blender --background --python tools/blender/create_baie_des_rois_missing_assets.py
```

| Script | GLB attendu | État dans Git au dernier contrôle |
|---|---|---|
| `create_baie_des_rois_kiosk.py` | `kiosque_baie_des_rois.glb` | Présent |
| `create_baie_des_rois_kiosk_type_b.py` | `kiosque_baie_des_rois_type_b.glb` | Présent |
| `create_baie_des_rois_props.py` | `palmier_baie_des_rois.glb`, `banc_baie_des_rois.glb`, `lampadaire_baie_des_rois.glb` | Les 3 présents |
| `create_baie_des_rois_restaurants.py` | `restaurant_pavillon_baie_des_rois_compact.glb`, `restaurant_pavillon_baie_des_rois.glb`, `restaurant_pavillon_baie_des_rois_large.glb` | Absents |
| `create_baie_des_rois_missing_assets.py` | `pavillon_chaume_baie_des_rois.glb`, `aire_jeux_baie_des_rois.glb`, `table_pique_nique_baie_des_rois.glb`, `fontaine_baie_des_rois.glb`, `massif_tropical_baie_des_rois.glb` | Absents |

Les cinq modèles déjà présents ne doivent pas être régénérés obligatoirement : ils sont déjà dans le dépôt. Les scripts restent disponibles pour les reconstruire si nécessaire.

Après génération, inspecter les pivots, l'échelle, les matériaux et les collisions dans Blender/Godot. Le script crée les ressources, pas leur implantation géographique. Le placement doit suivre les empreintes et les aménagements réels.

Références de l'aménagement : https://aivp-rufenacht-prize.org/projets/la-baie-des-rois/ et https://www.voaafrique.com/a/gabon-loisirs-la-promenade-de-la-baie-des-rois-enfin-ouverte-aux-librevillois/6710716.html

## 3. Éléments volontairement en attente des textures

Ne pas considérer ces éléments comme terminés :

- **Complexe mémoriel Léon Mba** : attendre les textures et références que l'utilisateur ajoutera. Le site comprend mausolée, musée, bibliothèque, statue de cire, jardins et cascade. Source officielle : https://presidence.ga/2026/08/14/inauguration-du-complexe-memoriel-leon-mbahommage-au-pere-de-la-nation-et-valorisation-de-notre-histoire/
- **Tribune de l'Indépendance** : attendre les textures de façade, toiture et matériaux avant la finition. Le modèle et ses gradins ne doivent pas être déclarés terminés sur la seule base du script.
- **Monument / Esplanade Georges-Damas-Aleka** : une reconstruction procédurale existe déjà dans `game/scripts/libreville_landmarks.gd`. Elle décrit l'arc, les huit pavillons provinciaux, le musée et le parvis. Ne pas créer un doublon Blender ; reprendre la finition après réception des textures. Sources : https://presidence.ga/2026/08/08/esplanade-georges-damas-aleka-le-president-de-la-republique-presente-sa-vision-memorielle-a-la-famille-du-defunt/ et https://agpgabon.ga/gabon-independance-an-66-oligui-nguema-inaugure-la-place-georges-damas-aleka/

## 4. Textures côtières à recevoir

Le détail des téléchargements est conservé dans `docs/COAST_TEXTURES_TO_DOWNLOAD.md`. Les lots attendus, en 2K :

1. Sable humide — Poly Haven, Sand 02.
2. Sable sec — Poly Haven, Coast Sand 01.
3. Rochers et falaises — ambientCG, Rock 060.
4. Rochers humides / moussus — ambientCG, Rock 063.

Télécharger les archives originales et les déposer à la racine du dépôt, sans les renommer. À réception, les extraire, classer dans `assets/models/coastal/textures/`, vérifier les licences, puis connecter les maps Base Color, Normal OpenGL, Roughness et éventuellement AO/Displacement. Ces textures serviront aux côtes, affleurements rocheux, plages et transitions eau/terre.

## 5. Ordre conseillé quand l'utilisateur sera devant son ordinateur

1. Faire `git pull origin main`.
2. Déposer les archives de textures à la racine du dépôt.
3. Exécuter les cinq scripts Baie des Rois ci-dessus (les kiosques et props déjà présents sont optionnels à régénérer).
4. Exécuter `generate_libreville_landmarks.py`.
5. Vérifier les GLB dans Blender, puis importer dans Godot.
6. Envoyer le commit contenant les textures et les nouveaux GLB ; l'équipe pourra alors corriger les matériaux, les modèles du mémorial Léon Mba et de la Tribune, les côtes rocheuses et les implantations.

Ne pas lancer une génération massive à l'aveugle : inspecter les GLB exportés et conserver une sauvegarde avant toute régénération.
