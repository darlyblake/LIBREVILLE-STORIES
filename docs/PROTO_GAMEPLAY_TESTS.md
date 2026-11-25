# Prototype gameplay — commandes et vérifications

## Personnage

- **ZQSD** : marcher et se déplacer.
- **Maj gauche** : courir.
- **Espace** : sauter ; si un rebord accessible est détecté devant le personnage, tenter de grimper.
- **Souris** : orienter la caméra et le personnage.
- **Clic droit maintenu** : viser à l'épaule.
- **Clic gauche maintenu pendant la visée** : tirer (tir hitscan, chargeur de 12 balles et délai entre les tirs).
- **R** : recharger ; le compteur de munitions est affiché en bas à droite.
- **F** : entrer dans le véhicule proche ou en sortir lorsqu'il est presque arrêté.
- **Manette** : gâchette gauche pour viser, gâchette droite pour tirer ; stick droit pour la caméra.

Le personnage actif est chargé depuis `assets/models/characters/UAL1_Standard.glb` (Quaternius, CC0 1.0). Un pistolet de test est construit en géométrie simple et attaché à l’os de la main droite lorsque le squelette expose un nom d’os compatible ; sinon il utilise un placement provisoire sur le modèle. Si le fichier n'est pas encore présent, `player_visual.gd` affiche un mannequin humanoïde de secours. UAL1 fournit notamment `Idle_Loop`, `Walk_Loop`, `Jog_Fwd_Loop`, `Sprint_Loop`, `Jump_Start`, `Jump_Loop`, `Jump_Land`, `Pistol_Aim_Neutral`, `Pistol_Shoot` et `Pistol_Reload`, associés aux états du gameplay. La bibliothèque complémentaire `assets/models/characters/UAL2_Standard.glb` est également importée (Quaternius, CC0 1.0), mais elle n'est pas encore utilisée en jeu : le diagnostic Godot compare ses clips et son squelette à UAL1 avant toute intégration, afin d'éviter des animations incompatibles. Le téléchargement initial du personnage est automatisé par GitHub Actions : **Import CC0 test character**.

## Jeep

- **W** : accélérer.
- **S** : freiner ; maintenir à l'arrêt pour engager la marche arrière.
- **A / D** : braquer.
- **C** : changer de caméra.
- **F** : ouvrir la porte conducteur, s'approcher, monter et refermer ; à l'arrêt, ouvrir pour descendre.

La Jeep utilise désormais `VehicleBody3D` et quatre `VehicleWheel3D` : traction intégrale, braquage sur l'essieu avant, rotation automatique des roues, suspension indépendante et friction des pneus. La carrosserie utilise une collision simple pour rester légère. Les roues visuelles du modèle sont classées par essieu, leur braquage est animé et leur rotation suit la vitesse, y compris en marche arrière. Les portes détectées dans le GLB reçoivent maintenant un pivot calculé au bord avant de leur géométrie, dans le repère local du véhicule ; si aucune porte n'est reconnue, une porte de test est générée.

## Essais à effectuer dans Godot

1. Marcher en ligne droite, changer de direction et courir ; écouter/observer les animations de locomotion.
2. Sauter sur terrain plat, vérifier la transition montée/chute/atterrissage, puis essayer un rebord bas, un rebord trop haut, un mur non franchissable et un rebord avec plafond bas : l'escalade doit être refusée si la face du mur ou la surface supérieure n'est pas valide, ou si l'espace au-dessus du point d'arrivée est obstrué.
3. Maintenir le clic droit : vérifier le zoom, le décalage caméra à l'épaule, l'orientation du personnage et le réticule.
4. En visant, maintenir le clic gauche : vérifier que chaque coup relance l'animation de tir et le recul du pistolet, avec le délai de tir, l'éclair de bouche et les impacts sur les objets/cibles du groupe `damageables`.
5. Dépenser les 12 balles : vérifier que le chargeur vide est signalé, que le rechargement affiche un compte à rebours et qu'aucun tir ne part pendant cette opération. Vérifier le retour à 12 / 12 à la fin du rechargement.
6. Tourner vers la cible d’entraînement placée à droite du point de départ et tirer plusieurs fois : vérifier les PV affichés, l’effet d’impact et la réapparition après destruction.
7. Approcher la Jeep à pied : vérifier l'approche côté conducteur, l'ouverture, l'entrée et la fermeture de porte.
8. Accélérer progressivement, relâcher l'accélérateur, freiner puis passer en marche arrière.
9. Faire des virages lents puis rapides ; vérifier que le braquage diminue à vitesse élevée.
10. Rouler sur une pente, monter un trottoir et franchir une petite irrégularité pour observer les suspensions.
11. Vérifier que la sortie est refusée tant que la Jeep roule, puis ouvrir la porte et descendre à l'arrêt.

## Validation

Après récupération de `main`, ouvrir le projet avec Godot 4.3 ou supérieur et laisser l'import des ressources se terminer. La validation automatisée est définie dans `.github/workflows/validate-godot.yml`. Les essais physiques, la position de l’arme sur la main et l’animation des portes doivent également être vérifiés en jeu : un parse réussi ne garantit pas le bon réglage de la suspension ni l’alignement des pivots sur le modèle Jeep.

## Références techniques étudiées

Ces dépôts ont servi à comparer les architectures et les comportements attendus. Leurs interfaces, personnages et univers ne sont pas repris dans LIBREVILLE STORIES.

- [GDQuest — Godot 4 Third Person Controller](https://github.com/gdquest-demos/godot-4-3d-third-person-controller) : référence pour la visée à l'épaule, le réticule, le tir, les projectiles, le délai de tir et l'organisation des animations. Le code est MIT, mais les modèles et textures sont CC-BY-NC-SA 4.0 ; ils ne sont donc pas importés dans notre jeu.
- [Godot Engine — TPS Demo](https://github.com/godotengine/tps-demo) : référence pour l'AnimationTree, le root motion, les animations de saut et de déplacement, le point de tir attaché au squelette, le flash de bouche et le recul caméra. Code MIT ; assets CC-BY 3.0.
- [Jeh3no — Godot Third Person Controller](https://github.com/Jeh3no/Godot-Third-Person-Controller) : référence pour la machine à états, les transitions marche/course/saut, les sons de pas et les effets de saut/atterrissage. Code MIT. Le projet vise surtout Godot 4.4 à 4.7 ; adaptation nécessaire pour notre projet Godot 4.3.
- [OpenCity](https://github.com/webgl-games/opencity) : référence antérieure pour la locomotion et les véhicules. Le modèle de test Quaternius est importé séparément et accompagné de son attribution/licence.

### Limites actuelles du prototype de tir

Le tir actuel est un tir instantané (hitscan) : il lance un rayon depuis le centre de la caméra, applique les dégâts aux objets du groupe damageables qui exposent une méthode damage, et affiche un flash lumineux, un réticule et un compteur de chargeur avec rechargement. Le pistolet visible est un modèle géométrique provisoire, pas une arme finale avec modèle artistique. Il n'y a pas encore de système complet d'inventaire d'armes, de projectiles physiques, d'ennemis avec IA, ni d'effets d'impact avancés. L'animation d'escalade reste un remplacement par une animation aérienne : UAL1 ne fournit pas de clip de grimpe directement exploitable. Ces éléments seront développés avec les missions et les PNJ.