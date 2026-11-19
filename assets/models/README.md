# Bibliothèque 3D — LIBREVILLE STORIES

Cette bibliothèque rassemble les ressources visuelles du monde ouvert. Les fichiers sources téléchargés sont conservés séparément des modèles spécifiques fabriqués pour les lieux réels.

## Organisation

```text
assets/models/
├── baie_des_rois/       # Kiosques et mobilier propres à la Baie des Rois
├── buildings/           # Maisons, immeubles, commerces et bâtiments publics
├── vegetation/          # Palmiers, arbres tropicaux, arbustes et plantes
├── urban_furniture/     # Bancs, poubelles, abribus, lampadaires, fontaines
├── road_signs/          # Panneaux de signalisation et leurs variantes
├── road_markings/       # Marquages, balises et équipements de chaussée
├── vehicles/            # Voitures, taxis, bus, motos et véhicules utilitaires
├── characters/          # Piétons et personnages
├── coastal/             # Rochers, quais, digues, plages et éléments marins
├── props/               # Objets de décor génériques
└── materials/            # Textures et matériaux PBR réutilisables
```

## Règles de classement

- Un modèle va dans le dossier correspondant à son usage principal.
- Les ressources propres à un site réel restent dans un sous-dossier du site (ex. `baie_des_rois/`).
- Conserver le nom d'origine dans le dossier `source/` ou dans le nom du fichier lorsqu'il aide à retrouver la ressource.
- Ajouter pour chaque pack un fichier `README.md` précisant la provenance, l'auteur, la licence, le format, les dépendances et les limites connues.
- Ne jamais supposer qu'un modèle est libre : vérifier sa licence avant de le publier dans le dépôt.
- Préférer GLB/glTF avec textures intégrées. Éviter les archives de travail, doublons et textures inutilisées.
- Cible matérielle : Godot 4.3, renderer Compatibility, 720p, Core i7-2600 / 12 Go RAM / GeForce GT 730 2 Go. Prévoir des textures raisonnables, des collisions simples et des LOD si nécessaire.

## Signalisation routière — premier pack reçu

Le pack `road_signs/road_signs_pack_revamped.glb` est le premier lot de signalisation reçu. Il est conservé comme scène-source complète. Son contenu interne (noms des panneaux, orientations, échelle, pivots, matériaux et organisation des objets) doit être inspecté dans Blender avant de créer les instances individuelles sur les routes.

**Important :** le pack est classé, mais ses panneaux ne sont pas encore placés dans la carte. Aucun placement aléatoire ou géographique n'est inventé. Les panneaux seront implantés à partir des intersections, sens de circulation et règles de signalisation vérifiables, après audit de la scène GLB.
