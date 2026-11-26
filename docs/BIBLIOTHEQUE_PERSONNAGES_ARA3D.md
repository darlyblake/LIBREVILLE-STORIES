# Bibliothèque automatique de personnages Ara 3D

## Objectif

Nous ne créons pas chaque habitant à la main. Ara 3D Gen fournit des personnages prêts à l'emploi, des tenues de métiers et des modèles humains modifiables. Le pipeline exporte ces personnages en GLB pour Godot, puis ajoute des civils générés avec des graines aléatoires reproductibles.

## Génération depuis GitHub

1. Ouvrir l'onglet **Actions** du dépôt.
2. Sélectionner **Build Ara 3D character library**.
3. Cliquer sur **Run workflow**.
4. Choisir 50, 100 ou 200 civils supplémentaires et le niveau de détail.
5. Attendre la fin du workflow.
6. Télécharger l'artefact **libreville-stories-ara3d-characters** depuis la page du workflow.

Le premier lancement télécharge les données Ara 3D (environ 50 Mo selon sa documentation). Les lancements suivants réutilisent le cache GitHub Actions.

## Contenu généré

- `presets/` : tous les presets Ara 3D disponibles au moment de l'exécution, avec animations idle, walk et run. Le catalogue comprend notamment des profils médicaux, police/militaire, travail et vie quotidienne.
- `crowd/` : 50 à 200 personnages aléatoires, sans animations, pour réduire la taille et la mémoire des foules.
- `metadata/` : catalogue du projet et rappel des licences.

Les presets ne sont pas tous des métiers gabonais. Ils constituent des bases visuelles : nous adapterons les tenues, couleurs, accessoires et rôles au contexte de Libreville. La profession doit être associée aux données du résident, pas déduite de son apparence.

## Intégration Godot

Les exports GLB sont compatibles avec Godot 4. Le format Ara utilise les mètres, +Y vers le haut et +Z vers l'avant. Les modèles proches du joueur peuvent utiliser un détail moyen ; les foules éloignées doivent utiliser le détail bas et partager meshes/matériaux quand possible.

Ne pas committer toute la bibliothèque générée dans Git : les GLB peuvent alourdir le dépôt. L'artefact Actions est conservé 14 jours. Après validation, seuls les modèles retenus et leurs paramètres/licences seront ajoutés à `assets/characters/` ou conservés dans un stockage d'assets versionné.

## Licences

- Ara 3D Gen : code MIT.
- Données de personnages MakeHuman : CC0.
- Animations : CMU Graphics Lab Motion Capture Database ; conserver les mentions et fichiers de licence fournis.
- Garder les paramètres, README et licences accompagnant chaque export.
- Vérifier les licences incluses avant redistribution séparée des modèles sources.

Documentation officielle :
- https://ara3dgen.com/characters/
- https://ara3dgen.com/docs/cli/
- https://ara3dgen.com/docs/exporting/
- https://ara3dgen.com/docs/engines/
