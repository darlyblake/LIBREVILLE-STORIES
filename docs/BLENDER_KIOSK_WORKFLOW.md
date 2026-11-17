# Premier kiosque 3D — Baie des Rois

## Génération avec Blender 5.3

Depuis la racine du dépôt, ouvrir PowerShell ou un terminal et exécuter :

```powershell
blender --background --python tools/blender/create_baie_des_rois_kiosk.py
```

Si la commande `blender` n'est pas reconnue, lancer Blender avec son chemin complet, par exemple :

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.3\blender.exe" --background --python tools\blender\create_baie_des_rois_kiosk.py
```

Le script crée automatiquement :

```text
assets/models/baie_des_rois/kiosque_baie_des_rois.glb
```

Godot importe ensuite le fichier GLB lorsqu'il est présent dans le dossier du projet. Il faudra encore créer son instance dans la scène et valider son échelle et son orientation en jeu.

## Contenu du prototype

- Dalle béton et sol intérieur
- Murs arrière et retours latéraux
- Comptoir de service
- Lames décoratives en bois
- Vitrages latéraux et cadres métalliques
- Poteaux et auvent
- Gouttière et descentes d'eau
- Enseigne « BAIE DES ROIS »

Les dimensions sont exprimées en mètres. La façade de service est orientée vers l'axe Y négatif.

## Limites connues

Ce modèle est un premier prototype de production, pas une reproduction certifiée d'un kiosque existant de la Baie des Rois. Il ne doit pas être positionné définitivement sur la carte avant validation des références photographiques, de la forme réelle de la promenade et des emplacements. Le script ne modifie pas automatiquement la scène Godot.

Le modèle est volontairement sobre en géométrie pour rester adapté à la cible matérielle ancienne (GT 730 2 Go). Les matériaux utilisent des couleurs simples ; des textures PBR et détails supplémentaires pourront être ajoutés après validation de la silhouette.
