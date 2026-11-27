# Système de profils et de physique des véhicules

Les véhicules proches du joueur utilisent des modèles 3D détaillés, pas les modèles low-poly de trafic. Les profils de conduite sont indépendants des meshes.

## Fichiers
- `data/vehicles/vehicle_profiles.json` : paramètres par véhicule, catégories, transmission, dimensions, pneus, charge et surfaces.
- `game/scripts/vehicle_controller.gd` : contrôleur physique qui charge le profil via `vehicle_profile_id`.

## Modèles réalistes retenus (GLB)
Source principale : Vinish.dev, modèles originaux détaillés, intérieurs complets, roues et volant séparés, dimensions réelles, 115k–176k triangles, 3–4.8 MB. Licence CC BY 4.0, attribution obligatoire.
- Berline : https://models.vinish.dev/realistic-cars/executive-sedan.glb
- Berline sportive : https://models.vinish.dev/realistic-cars/sport-sedan.glb
- 4x4 : https://models.vinish.dev/realistic-cars/boxy-off-roader.glb
- SUV : https://models.vinish.dev/realistic-cars/luxury-suv.glb
- Citadine : https://models.vinish.dev/realistic-cars/retro-city-car.glb
- Sportive : https://models.vinish.dev/realistic-cars/mid-engine-supercar.glb

Pickups/SUV détaillés : https://vinish.dev/free-3d-models/pickups-and-suvs
Camions détaillés : https://vinish.dev/free-3d-models/trucks

Les URLs de téléchargement sont identifiées, mais les binaires ne sont pas déclarés intégrés tant qu'ils ne sont pas présents et inspectés dans le dépôt. Les GLB détaillés sont réservés aux véhicules proches du joueur ; prévoir des LOD dérivés pour la circulation.

## Réalisme physique
Les valeurs de JSON sont des paramètres de simulation de départ, pas des données constructeur. Il faudra les calibrer sur la base de mesures documentées ou d'essais de conduite dans Godot. Le profil différencie masse, centre de gravité, accélération, freinage, frein moteur, direction, réponse, adhérence, suspension, rayon de roue, charge utile, transmission et rapports de boîte.
