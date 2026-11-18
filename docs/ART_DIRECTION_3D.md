# Direction artistique 3D — LIBREVILLE STORIES

## Objectif
Obtenir une direction artistique de jeu en monde ouvert inspirée de GTA San Andreas / GTA V : proportions crédibles, architecture variée, textures photographiques, végétation tropicale identifiable, chaussées détaillées, eau intégrée à une rive géographique correcte et éclairage cohérent.

Cette référence décrit une direction artistique, pas une promesse d'atteindre la fidélité technique de GTA V sur le PC cible.

## Logiciels à installer sur Windows
1. **Godot 4.3 Standard** — conserver la version utilisée par le projet. Importer les scènes 3D au format glTF 2.0 / GLB.
2. **Blender 4.5 LTS** — outil de création et d'édition des bâtiments, kiosques, palmiers, rochers, mobilier, passerelles et éléments de côte. La branche 4.5 LTS conserve une compatibilité avec des GPU NVIDIA plus anciens que les versions Blender récentes.
3. **GIMP ou Krita** — retoucher les textures, créer les atlases et corriger les couleurs.
4. **GitHub Desktop** (facultatif) — récupérer et synchroniser la branche main sans devoir utiliser les commandes Git.

Téléchargements officiels :
- Godot : https://godotengine.org/download/archive/4.3-stable/
- Blender 4.5 LTS : https://www.blender.org/download/lts/4-5/
- GIMP : https://www.gimp.org/downloads/
- Krita : https://krita.org/en/download/

## Bibliothèque d'assets et textures
- **Poly Haven** : https://polyhaven.com — matériaux PBR, modèles et HDRI publiés sous licence CC0. Vérifier la fiche de chaque ressource au moment du téléchargement.
- **ambientCG** : https://ambientcg.com — matériaux et textures ; vérifier la licence CC0 et les conditions indiquées sur chaque page.
- Les photographies de Libreville et de la Baie des Rois servent de références de modélisation. Elles ne doivent pas être copiées comme textures du jeu sans vérifier leurs droits.

## Configuration recommandée pour le PC cible
Configuration de référence : Core i7-2600, 12 Go de RAM, GeForce GT 730 2 Go.

### Godot
- Garder le renderer **Compatibility** dans project.godot tant que la GT 730 est la cible.
- Ne pas activer Forward+ par défaut : les effets avancés peuvent être trop coûteux ou incompatibles avec cette ancienne carte.
- Résolution de test initiale : 1280 × 720.
- Textures de décor : commencer en 1024 px ; réserver 2048 px aux éléments proches et importants.
- Limiter les matériaux transparents, les lumières dynamiques, les ombres coûteuses et les reflets temps réel.
- Utiliser des meshes regroupés, des LOD et des collisions simplifiées pour les objets éloignés.
- Tester chaque effet sur la GT 730 avant de le généraliser.

### Blender
- Installer Blender 4.5 LTS plutôt que la dernière version majeure si la version la plus récente refuse de démarrer sur la GT 730.
- Modéliser les objets à l'échelle réelle (mètres), appliquer les transformations et vérifier les normales.
- Préparer les UV et des textures PBR cohérentes : Base Color, Normal, Roughness et Ambient Occlusion lorsque disponibles.
- Exporter en glTF 2.0 / GLB, avec textures intégrées, unités en mètres et orientation vérifiée.
- Garder les scènes de travail .blend séparées des fichiers exportés vers Godot.

## Règles de production pour éviter l'aspect LEGO
- Ne pas construire un kiosque, un arbre ou un bâtiment uniquement avec des cubes superposés.
- Utiliser des silhouettes reconnaissables, des chanfreins, des épaisseurs réalistes et des détails à l'échelle.
- Créer plusieurs familles architecturales gabonaises à partir de références photographiques vérifiables ; ne pas appliquer une façade unique à toute Libreville.
- Les palmiers doivent avoir un tronc, une couronne et des palmes modélisées, pas une boîte verte au sommet.
- Les routes doivent suivre les axes géographiques, avec chaussée, bordures, trottoirs, marquages et raccords de carrefour.
- La mer ne doit jamais être une nappe rectangulaire posée sur la ville. Construire d'abord une limite terre/mer géoréférencée et vérifiée, puis générer la surface d'eau à partir de cette limite.
- Les kiosques de la Baie des Rois doivent être placés sur l'arc réel de la promenade, côté terre, à partir d'un relevé visuel/géographique contrôlé.
- Conserver un budget de polygones, textures et lumières compatible avec la GT 730.

## État actuel de la Baie des Rois
Les anciens générateurs procéduraux de la zone ont été désactivés dans game/scripts/baie_des_rois.gd car ils produisaient des nappes bleues rectangulaires, des kiosques cubiques et des éléments simplifiés mal positionnés. Ils ne doivent pas être réactivés avant la reconstruction géoréférencée et l'import de vrais modèles 3D.

Le projet reste sur Godot 4.3 et le renderer Compatibility. L'installation de Blender et des bibliothèques d'assets est nécessaire pour la prochaine étape de création, mais ne modifie pas automatiquement le rendu du jeu : les modèles et textures devront être produits/importés et intégrés explicitement.


## Végétation tropicale — évolution du 18 novembre 2026

Les arbres issus des polygones OSM ne doivent plus être représentés par une seule sphère lisse.
Le générateur de végétation de `game/scripts/world_map.gd` utilise désormais trois silhouettes
de couronnes assemblées à partir de plusieurs volumes de feuillage irréguliers, avec variations
de proportions et de teintes. Les meshes sont mutualisés dans des `MultiMeshInstance3D` pour
limiter les appels de rendu sur la configuration cible (GT 730 2 Go).

Cette étape améliore la silhouette générale, mais ne constitue pas encore une bibliothèque
botanique fidèle : les espèces de palmiers, cocotiers et arbres ornementaux doivent être
modélisées séparément à partir de références photographiques locales. Les emplacements restent
déduits des zones vertes OSM et doivent être contrôlés en jeu.


## Répartition des arbres — correction du 18 novembre 2026

Le placement aléatoire dans les polygones verts applique maintenant une distance minimale de 5,5 m entre les troncs générés. Cette règle réduit les superpositions et les amas visuellement artificiels, y compris lorsque plusieurs polygones verts sont voisins. Le nombre d'arbres reste plafonné globalement à 1 200 et la densité dépend toujours de la surface OSM.

Cette correction améliore la répartition, mais ne remplace pas une implantation botanique manuelle ni la validation des limites réelles des parcs. Le résultat doit être contrôlé dans Godot avant de considérer la végétation comme validée.
