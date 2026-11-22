# Textures côtières à ajouter — LIBREVILLE STORIES

Le littoral fonctionne actuellement avec des matériaux procéduraux. Ils donnent du relief visuel, mais **ils ne remplacent pas des textures photographiques PBR**. Pour obtenir un rendu nettement plus réaliste, ajouter les packs ci-dessous.

## 1. Sable côtier humide — prioritaire

Source : Poly Haven — Sand 02  
https://polyhaven.com/a/sand_02

Télécharger en **2K** (pas 8K) et conserver ces cartes :
- Diffuse / Base Color : `sand_02_diff_2k.jpg`
- Normal OpenGL : `sand_02_nor_gl_2k.exr`
- Roughness : `sand_02_rough_2k.exr`
- Displacement : `sand_02_disp_2k.png` (facultatif, pour relief léger)

Licence annoncée : CC0. Le matériau est décrit comme sable côtier granuleux, avec zones humides et petites rides.

## 2. Sable sec / sable de plage — prioritaire

Source : Poly Haven — Coast Sand 01  
https://polyhaven.com/a/coast_sand_01

Télécharger en **2K** :
- Diffuse / Base Color
- Normal OpenGL
- Roughness
- Displacement (facultatif)

Licence annoncée : CC0. Il servira à différencier le sable sec de la bande humide près de l'eau.

## 3. Rochers de côte et affleurements — prioritaire

Source : ambientCG — Rock 060  
https://ambientcg.com/view?id=Rock060

Télécharger le pack **2K JPG**. Conserver :
- Color / Diffuse
- Normal OpenGL si proposé
- Roughness
- Ambient Occlusion (facultatif)

Licence annoncée : CC0. Texture de rocher/cliff photographique, adaptée aux amas rocheux et aux bords de côte.

## 4. Rochers usés, moussus et humides — recommandé

Source : ambientCG — Rock 063  
https://ambientcg.com/view?id=Rock063

Télécharger le pack **2K JPG** et conserver Color, Normal OpenGL, Roughness et AO si disponibles.

Licence annoncée : CC0. À utiliser avec parcimonie dans les zones rocheuses et humides.

## Réglages de téléchargement

- Résolution recommandée : **2K** pour commencer, afin de préserver les performances sur Intel UHD 620.
- Format : JPG pour Color, PNG/JPG pour les cartes de données si disponibles ; EXR est acceptable si c'est le format proposé, mais nous pourrons convertir les cartes de données si nécessaire.
- Ne télécharge pas les versions 8K.
- Ne prends pas de captures d'écran des textures : il faut les fichiers originaux.

## Où déposer les fichiers

Quand tu seras devant l'ordinateur, tu peux déposer les ZIP téléchargés à la racine du dépôt GitHub `LIBREVILLE-STORIES`, sans les renommer. Préviens-moi ensuite : je ferai le tri et préparerai leur intégration dans `assets/models/coastal/textures/`, avec les licences et crédits correspondants.

**État actuel :** le sable et les rochers du jeu sont encore générés avec des couleurs et des matériaux procéduraux. Les textures PBR ci-dessus ne sont pas encore intégrées.
