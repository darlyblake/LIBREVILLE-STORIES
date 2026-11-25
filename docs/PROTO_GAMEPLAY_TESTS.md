# Prototype gameplay — commandes et vérifications

## Personnage

- **ZQSD** : marcher et se déplacer.
- **Maj gauche** : courir.
- **Espace** : sauter ; si un rebord accessible est détecté devant le personnage, tenter de grimper.
- **Souris** : orienter la caméra et le personnage.
- **Clic droit maintenu** : viser à l'épaule.
- **Clic gauche maintenu pendant la visée** : tirer (tir hitscan avec portée limitée et délai entre les tirs).
- **F** : entrer dans le véhicule proche ou en sortir lorsqu'il est presque arrêté.
- **Manette** : gâchette gauche pour viser, gâchette droite pour tirer ; stick droit pour la caméra.

Le personnage est chargé depuis `assets/models/characters/UAL1_Standard.glb` (Quaternius, CC0 1.0). Si le fichier n'est pas encore présent, `player_visual.gd` affiche un mannequin humanoïde de secours. Les clips d'animation sont résolus par alias (Idle/Walk/Run/Jump/Fall/Aim/Shoot/Climb) selon les noms réellement présents dans le GLB ; les états sans clip compatible restent à compléter avec un pack d'animations adapté. Le téléchargement est automatisé par GitHub Actions : **Import CC0 test character**.

## Jeep

- **W** : accélérer.
- **S** : freiner ; maintenir à l'arrêt pour engager la marche arrière.
- **A / D** : braquer.
- **C** : changer de caméra.
- **F** : ouvrir la porte conducteur, s'approcher, monter et refermer ; à l'arrêt, ouvrir pour descendre.

La Jeep utilise désormais `VehicleBody3D` et quatre `VehicleWheel3D` : traction intégrale, braquage sur l'essieu avant, rotation automatique des roues, suspension indépendante et friction des pneus. La carrosserie utilise une collision simple pour rester légère.

## Essais à effectuer dans Godot

1. Marcher en ligne droite, changer de direction et courir ; écouter/observer les animations de locomotion.
2. Sauter sur terrain plat, vérifier la transition montée/chute/atterrissage, puis essayer un rebord bas et un rebord trop haut.
3. Maintenir le clic droit : vérifier le zoom, le décalage caméra à l'épaule, l'orientation du personnage et le réticule.
4. En visant, maintenir le clic gauche : vérifier le délai de tir, l'éclair de bouche et les impacts sur les objets/cibles du groupe `damageables`.
5. Approcher la Jeep à pied : vérifier l'approche côté conducteur, l'ouverture, l'entrée et la fermeture de porte.
6. Accélérer progressivement, relâcher l'accélérateur, freiner puis passer en marche arrière.
7. Faire des virages lents puis rapides ; vérifier que le braquage diminue à vitesse élevée.
8. Rouler sur une pente, monter un trottoir et franchir une petite irrégularité pour observer les suspensions.
9. Vérifier que la sortie est refusée tant que la Jeep roule, puis ouvrir la porte et descendre à l'arrêt.

## Validation

Après récupération de `main`, ouvrir le projet avec Godot 4.3 ou supérieur et laisser l'import des ressources se terminer. La validation automatisée est définie dans `.github/workflows/validate-godot.yml`. Les essais physiques et les animations de porte doivent également être vérifiés en jeu : un parse réussi ne garantit pas le bon réglage de la suspension sur le modèle Jeep.
