# Environnement 3D — références, ressources et intégration

Ce document décrit les ressources et techniques utilisées pour améliorer Libreville : ciel tropical, lumière solaire, océan, végétation, façades, chaussées, trottoirs et signalisation.

## Références techniques étudiées

| Projet / bibliothèque | Apport étudié | Licence / compatibilité |
|---|---|---|
| [LesusX/Water-Shader](https://github.com/LesusX/Water-Shader) | Vagues de Gerstner, écume, caustiques, coloration selon la profondeur | MIT ; projet annoncé/testé avec Godot 4.5, donc techniques adaptées sélectivement à Godot 4.3 |
| [spicyhaydenc/Godot-4-Realistic-Water](https://github.com/spicyhaydenc/Godot-4-Realistic-Water) | Portage Godot 4 du shader Realistic Water | MIT ; base utile mais port de travail |
| [Brandt-J/WaterShader](https://github.com/Brandt-J/WaterShader) | Shader d'eau 3D simple | MIT ; Godot 4.2.1 |
| [Poly Haven](https://polyhaven.com/textures) | Matériaux PBR photographiés, cartes de normales, rugosité et HDRI | CC0 |
| [Poly Haven — API](https://polyhaven.com/our-api) | Téléchargement automatisé des ressources et métadonnées | API ouverte ; les ressources sont CC0 |

Les shaders MIT ont été étudiés comme références. Le projet conserve son propre shader d'océan et son pipeline Godot 4.3 ; aucun dossier complet d'un dépôt tiers n'est copié aveuglément.

## Ressources CC0 intégrées ou téléchargées

Le pipeline `tools/download_cc0_textures.py` récupère les cartes PBR et les métadonnées depuis l'API Poly Haven. Le workflow GitHub `.github/workflows/download-cc0-textures.yml` automatise le téléchargement et le commit des fichiers.

Matériaux ciblés :
- bitume et chaussées ;
- béton de trottoir et dalles ;
- crépi de façade et briques ;
- tôle ondulée et métal rouillé ;
- bois brut pour les étals ;
- sable côtier, sable sec, terre et gravier ;
- herbe et écorce pour les espaces verts.

Les sources 2K/4K sont conservées comme ressources maîtres. Le niveau de qualité affiché se règle dans le jeu.

## Ciel, soleil et mer

- Le ciel visible est un shader procédural avec gradient atmosphérique, nuages tropicaux animés, halo solaire et brume de littoral.
- La DirectionalLight3D représente le soleil et fournit les ombres dynamiques.
- L'océan utilise des vagues géométriques longues, deux couches de normales animées, Fresnel, reflets spéculaires et crêtes claires.
- Les cartes PBR d'océan disposent désormais de mipmaps ; la carte de normale est importée comme une vraie normale.
- Une HDRI côtière Poly Haven CC0 est ajoutée à la bibliothèque pour les essais d'éclairage et les profils de rendu.

## Routes, trottoirs et mobilier

- Les routes restent alignées sur les données OSM et le relief DEM.
- Les marquages de voies, lignes d'arrêt, passages piétons, bordures, îlots et rampes sont construits dans le pipeline routier.
- Les trottoirs utilisent désormais un matériau PBR de béton, en plus des joints et variations de dalles.
- Les intersections OSM servent à placer des panneaux STOP, des plaques de rue et des feux tricolores.
- La signalisation procédurale est originale ; les panneaux du pack GLB conservé dans `assets/models/road_signs/` ne sont pas utilisés tant que sa provenance et sa licence ne sont pas documentées.

## Architecture des bâtiments et végétation

- Les façades publiques utilisent le crépi PBR ; les toitures et auvents reçoivent des matériaux de tôle ondulée.
- Les étals du marché Mont-Bouët utilisent béton, bois, métal et tôle texturés.
- Les espaces verts OSM reçoivent des arbres regroupés en MultiMesh ; des silhouettes de palmiers à palmes triangulées complètent les arbres tropicaux à couronne large.
- Les arbres et les surfaces sont regroupés spatialement pour conserver le culling par secteur.

## Licence et provenance

- Les matériaux téléchargés par le pipeline sont enregistrés avec leur source, leurs auteurs et leur licence dans chaque dossier `asset.json`.
- Les dépôts de shaders tiers cités ci-dessus conservent leurs licences propres ; leurs fichiers ne sont pas recopiés dans le jeu sans besoin et vérification de compatibilité.
- Les ressources déjà présentes dans le dépôt mais sans provenance documentée restent identifiées comme telles ; leur présence historique ne vaut pas preuve de licence.
