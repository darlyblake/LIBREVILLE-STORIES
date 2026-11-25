# Véhicules

Voitures, taxis, bus, motos et véhicules utilitaires. Privilégier les modèles optimisés et les collisions simplifiées.

## Configuration commune des véhicules

Le contrôleur `game/scripts/vehicle_controller.gd` est générique. Chaque scène qui l'utilise choisit son modèle 3D avec `vehicle_model_path`, puis configure indépendamment l'essieu directeur et l'essieu moteur dans l'inspecteur Godot.

| Type de véhicule | Essieu directeur | Essieu moteur |
| --- | --- | --- |
| Voiture / taxi classique | Avant | Arrière (propulsion) |
| Véhicule à traction | Avant | Avant |
| 4x4 | Avant | Intégrale |
| Chariot élévateur contrebalancé courant | Arrière | Avant (à confirmer selon le modèle) |
| Transpalette électrique à roue motrice/directrice arrière | Arrière | Arrière |
| Véhicule sans motorisation | Selon le modèle | Aucun |

Ces exemples sont des configurations de départ : les essieux doivent correspondre au véhicule 3D réel. Les options sont indépendantes, car deux chariots n'ont pas nécessairement la même transmission.

### Propriétés à régler dans l'inspecteur

- `vehicle_model_path` : chemin du nœud racine du modèle 3D dans la scène.
- `steering_axle` : Avant, Arrière ou Aucun.
- `drive_axle` : Avant, Arrière, Intégrale ou Aucune.
- `front_track` et `rear_track` : largeur de voie utilisée pour l'angle différentiel des roues.
- `wheel_radius`, `wheel_spin_axis` et `wheel_steer_axis` : adaptation de l'animation aux axes et dimensions du modèle.
- `minimum_wheel_dimension` et `maximum_wheel_dimension` : seuils de taille pour reconnaître les pneus ; à réduire pour les petites roues de transpalette.

Le contrôleur identifie les roues à partir de leur hiérarchie et de leurs dimensions, puis les répartit entre l'avant et l'arrière selon leur position locale. Les modèles à trois roues sont acceptés ; les modèles à quatre roues sont vérifiés pour s'assurer qu'une roue est présente à chaque coin.

**Limite actuelle de la simulation :** le véhicule utilise un `CharacterBody3D` arcade. `drive_axle` décrit et classe les roues motrices, mais le couple n'est pas encore simulé individuellement par roue ; la vitesse et l'accélération restent calculées au niveau du châssis. Les roues non motrices tournent également visuellement lorsqu'elles roulent.
