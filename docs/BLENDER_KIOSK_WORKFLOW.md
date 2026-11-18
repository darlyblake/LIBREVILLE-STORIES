# Kiosques 3D — Baie des Rois

## Générer les deux modèles avec Blender 5.3

Depuis la racine du dépôt, dans PowerShell :

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.3\blender.exe" --background --python tools\blender\create_baie_des_rois_kiosk.py
& "C:\Program Files\Blender Foundation\Blender 5.3\blender.exe" --background --python tools\blender\create_baie_des_rois_kiosk_type_b.py
```

Les deux fichiers attendus sont :

- `assets/models/baie_des_rois/kiosque_baie_des_rois.glb` — type A, toiture verte à deux pans.
- `assets/models/baie_des_rois/kiosque_baie_des_rois_type_b.glb` — type B, auvent plat débordant, claustra bois et grandes surfaces vitrées.

Le type A est généré par `tools/blender/create_baie_des_rois_kiosk.py`; le type B par `tools/blender/create_baie_des_rois_kiosk_type_b.py`.

## Implantation GPS dans Godot

Le script `game/scripts/baie_des_rois.gd` instancie huit kiosques : quatre sur chaque rangée. Il utilise les coordonnées calculées dans `game/scripts/baie_des_rois_survey.gd`.

- Rangée A : du point GPS P1 au point GPS P2.
- Rangée B : décalage transversal calculé à partir de P3, environ 8,51 m entre les axes des rangées.
- Les quatre kiosques de chaque rangée sont répartis régulièrement sur environ 101,07 m.
- Les deux rangées sont orientées pour que leurs façades se regardent vers le passage central.

La répartition 4 + 4 est un placement initial de travail. Elle doit encore être comparée aux captures 7, 8 et 9 et validée dans Godot. L'orientation de façade doit aussi être confirmée sur le rendu importé du GLB.

## Dimensions et limites

Les dimensions des deux prototypes sont exprimées en mètres. Ils ont une emprise voisine de 5 m × 3,8 m, ce qui laisse un espace théorique d'environ 4,7 à 4,9 m entre les façades si les axes sont bien espacés de 8,51 m.

Ces deux modèles sont des variantes de travail distinctes, pas encore des reproductions certifiées des kiosques réels. Les matériaux sont principalement des matériaux simples ; les textures PBR et les détails fins pourront être améliorés après comparaison avec les photographies du site.

## Export et intégration

Après génération, vérifier les deux GLB dans Blender ou Godot, puis les ajouter au dépôt :

```powershell
git add assets/models/baie_des_rois/kiosque_baie_des_rois.glb assets/models/baie_des_rois/kiosque_baie_des_rois_type_b.glb
git commit -m "Add two Baie des Rois kiosk 3D variants"
git push origin main
```

Godot ne pourra instancier les huit kiosques que lorsque les deux fichiers GLB seront présents dans le projet.
