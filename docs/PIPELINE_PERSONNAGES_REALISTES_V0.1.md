# Pipeline des personnages humains réalistes — v0.1

## Décision technique

Le projet adopte **Ara 3D Gen** comme générateur principal de personnages, basé sur les ressources graphiques MakeHuman CC0. Il produit des humains paramétriques, personnalisables, riggés et exportables en GLB. Le code d'Ara 3D Gen est MIT ; les données graphiques MakeHuman intégrées sont CC0 1.0 ; les animations CMU sont réutilisables commercialement sous réserve de ne pas revendre les données seules et de conserver l'avis de crédit correspondant. Vérifier les licences de tout contenu tiers ajouté séparément.

- Projet source : https://github.com/olatunde85/3d-gen
- Constructeur web : https://ara3dgen.com/app/
- Bibliothèque de personnages : https://ara3dgen.com/characters/
- Documentation export : https://github.com/olatunde85/3d-gen/blob/main/docs/exporting.md
- Documentation Godot : https://github.com/olatunde85/3d-gen/blob/main/docs/engines.md
- Licence des ressources MakeHuman : https://www.makehumancommunity.org/about/license.html

MakeHuman/MPFB reste une solution complémentaire pour les retouches manuelles dans Blender. Le code MPFB est GPL, mais ses ressources graphiques de base sont CC0. Les licences du code et des données doivent rester distinctes.

## Pourquoi ce choix

Ara 3D Gen annonce notamment :
- une base anatomique humaine MakeHuman ;
- plus de 900 morph targets et 219 contrôles détaillés ;
- 20 textures photographiques de peau couvrant plusieurs âges, origines et genres ;
- vêtements, chaussures, coiffures et accessoires ;
- un rig de jeu avec noms d'os compatibles Mixamo ;
- expressions faciales et formes de bouche ;
- export GLB riggé avec animations intégrées ou séparées ;
- niveaux de détail bas, moyen et élevé.

Ce générateur est beaucoup plus adapté que les primitives géométriques actuellement utilisées par `npc_character.gd`. Il ne garantit pas à lui seul un rendu AAA : les personnages doivent être sélectionnés, habillés, optimisés et testés dans l'éclairage réel du jeu.

## Première livraison : deux personnages étalons

Créer dans le constructeur Ara :
1. Un homme adulte civil de Libreville, peau brun foncé, cheveux afro courts/dégradé, polo bleu sobre, pantalon sombre et chaussures quotidiennes.
2. Une femme adulte civile de Libreville, peau brune, coiffure tressée ou afro naturelle, tenue urbaine quotidienne sobre.

Ne pas attribuer automatiquement une apparence à une nationalité. Les traits physiques doivent varier naturellement et ne doivent pas servir à déduire l'origine, la profession ou le statut social.

Pour chaque modèle :
- corps entier, pose A ;
- proportions anatomiques cohérentes ;
- rig de jeu activé ;
- export GLB ;
- animations limitées à idle, walk et run pour le premier test ;
- détail **Low** pour les foules et **Medium** pour les personnages proches ;
- conserver le fichier de paramètres `params.json` ou le ZIP d'export afin de pouvoir reconstruire le personnage.

Le générateur documente les exports GLB en mètres, avec +Y vers le haut, personnage orienté +Z, pieds au niveau y=0. Les clips peuvent être nommés avec le suffixe `-loop` pour que Godot les importe en boucle.

## Import dans le jeu

Placer les GLB dans :
- `assets/characters/base/` pour les modèles de référence ;
- `assets/characters/variants/` pour les variantes validées ;
- les fichiers sources de paramètres et crédits dans `data/characters/sources/`.

Ne pas committer les caches Node, les ressources brutes temporaires ni des exports non validés. Garder les fichiers GLB finaux seulement quand ils sont testés et utiles au jeu.

Dans Godot 4 :
1. Copier le GLB dans le dossier d'assets.
2. Laisser l'importeur glTF créer la scène.
3. Ouvrir la scène importée et vérifier l'échelle, l'orientation, le matériau, le squelette et les animations.
4. Vérifier que le rig contient bien les os et que les clips idle/walk/run existent.
5. Configurer les clips cycliques en boucle si leur nom ne porte pas `-loop`.
6. Tester avec le renderer GL Compatibility utilisé par le projet.
7. Tester le même modèle à 10 m, 25 m et 50 m pour décider du niveau de détail.

## Architecture de population visée

Les résidents ne sont pas les modèles. Un résident est une identité persistante, avec sa fiche et ses traits d'apparence. Un modèle GLB est une ressource graphique réutilisable.

- 100 modèles de base sont un catalogue de départ, pas 100 identités imposées.
- Plusieurs résidents peuvent partager une base graphique tout en ayant des variations de morphs, coiffure, vêtements, teint et visage.
- Le choix de modèle et les paramètres de morphologie sont sauvegardés dans la fiche du résident.
- Une naissance crée une nouvelle identité ; ses traits hérités devront être calculés à partir des parents, puis appliqués aux morphs du modèle. Ce mécanisme génétique n'est pas encore connecté.
- Les changements d'âge doivent modifier les paramètres d'apparence sans changer l'identité du résident.
- Les personnages éloignés restent simulés sans instancier un modèle 3D.

## Performance cible

Machine de référence : Intel Core i5-8350U, 16 Go RAM, Intel UHD 620.

- Ne jamais instancier toute la population en 3D.
- Réutiliser les meshes, matériaux et squelettes quand c'est possible.
- Utiliser Low pour les passants lointains et Medium pour les personnages proches.
- Réserver les morphs faciaux détaillés et animations coûteuses aux personnages proches.
- Tester les lots de personnages sur la machine de référence avant d'augmenter la densité.
- Les tailles de fichiers et le nombre de triangles doivent être mesurés sur les exports réels, pas supposés.

## État réel

Cette livraison documente et fixe le pipeline. Les fichiers GLB masculins et féminins ne sont pas encore présents dans le dépôt : ils doivent être exportés depuis Ara 3D Gen puis vérifiés dans Godot. Aucun modèle non testé ne doit être présenté comme intégré au jeu.
