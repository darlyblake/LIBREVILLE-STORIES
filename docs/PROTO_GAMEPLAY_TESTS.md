# Prototype gameplay — commandes et vérifications

## Personnage

- **ZQSD** : marcher et se déplacer.
- **Maj gauche** : courir.
- **Espace** : sauter ; si un rebord accessible est détecté devant le personnage, tenter de grimper.
- **Souris** : orienter la caméra et le personnage.
- **F** : entrer dans le véhicule proche ou en sortir lorsqu'il est presque arrêté.

Le personnage est chargé depuis `assets/models/characters/UAL1_Standard.glb` (Quaternius, CC0 1.0). Si le fichier n'est pas encore présent, `player_visual.gd` affiche un mannequin humanoïde de secours. Le téléchargement peut être lancé depuis GitHub Actions : **Import CC0 test character**.

## Jeep

- **W** : accélérer.
- **S** : freiner ; maintenir à l'arrêt pour engager la marche arrière.
- **A / D** : braquer.
- **C** : changer de caméra.
- **F** : ouvrir la porte conducteur, s'approcher, monter et refermer ; à l'arrêt, ouvrir pour descendre.

La Jeep utilise désormais `VehicleBody3D` et quatre `VehicleWheel3D` : traction intégrale, braquage sur l'essieu avant, rotation automatique des roues, suspension indépendante et friction des pneus. La carrosserie utilise une collision simple pour rester légère.

## Essais à effectuer dans Godot

1. Marcher en ligne droite, changer de direction et courir.
2. Sauter sur terrain plat puis essayer un rebord bas et un rebord trop haut.
3. Approcher la Jeep à pied : vérifier l'approche côté conducteur, l'ouverture, l'entrée et la fermeture de porte.
4. Accélérer progressivement, relâcher l'accélérateur, freiner puis passer en marche arrière.
5. Faire des virages lents puis rapides ; vérifier que le braquage diminue à vitesse élevée.
6. Rouler sur une pente, monter un trottoir et franchir une petite irrégularité pour observer les suspensions.
7. Vérifier que la sortie est refusée tant que la Jeep roule, puis ouvrir la porte et descendre à l'arrêt.

## Validation

Après récupération de `main`, ouvrir le projet avec Godot 4.3 ou supérieur et laisser l'import des ressources se terminer. La validation automatisée est définie dans `.github/workflows/validate-godot.yml`. Les essais physiques et les animations de porte doivent également être vérifiés en jeu : un parse réussi ne garantit pas le bon réglage de la suspension sur le modèle Jeep.
