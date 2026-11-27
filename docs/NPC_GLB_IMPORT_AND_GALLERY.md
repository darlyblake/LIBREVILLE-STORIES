# Import GLB et galerie de personnages

## Fonctionnement actuel

La scène `res://game/scenes/npc_gallery.tscn` affiche jusqu'à 100 résidents présents dans `PopulationManager.residents`.

Pour chaque résident, `NPCModelLibrary` choisit de façon déterministe un modèle GLB à partir de son identifiant, puis contrôle sa racine `Node3D`, son squelette et son animation idle. Si aucun modèle valide n'est disponible, `npc_gallery.gd` utilise `npc_character.tscn`, le personnage procédural de secours.

Les dossiers scannés sont `assets/characters/library/` et `assets/characters/base/`. Les fichiers GLB doivent être placés directement dans ces dossiers (pas dans des sous-dossiers). L'animation idle peut s'appeler `idle-loop`, `Idle`, `idle`, `Idle_Loop`, `mixamo.com` ou commencer par `idle`.

## Export depuis Ara 3D Gen

Pour chaque personnage :
- choisir un personnage complet, en pose A ;
- activer le rig de jeu ;
- exporter en GLB ;
- demander le niveau Low pour les foules et conserver une variante Medium si elle est réellement nécessaire ;
- inclure au minimum une animation d'attente (`idle`) ; walk et run seront validées ensuite ;
- conserver les paramètres de génération et les informations de licence dans `data/characters/sources/`.

Copier les fichiers GLB directement dans `assets/characters/library/`.

## Vérification dans Godot

1. Ouvrir le projet dans Godot 4.3 et attendre la fin de l'import glTF.
2. Ouvrir `game/scenes/npc_gallery.tscn` et lancer la scène (F6).
3. Vérifier que les modèles sont à la bonne échelle, debout sur le sol, orientés vers l'avant et correctement éclairés.
4. Vérifier dans la sortie de débogage le nombre de GLB détectés, rejetés et utilisés, ainsi que les prototypes de secours.
5. Vérifier que les animations sont présentes dans l'`AnimationPlayer` et que l'animation idle joue.
6. Contrôler les déformations du squelette, les mains, les pieds, les cheveux et les vêtements.

## Limites connues

- Les fichiers GLB ne sont pas encore livrés dans le dépôt ; le fallback procédural reste donc utilisé.
- Le choix du modèle est pour l'instant basé sur le genre enregistré, pas sur la morphologie individuelle.
- Le contrôle runtime vérifie la présence d'un squelette non vide et d'une animation idle ; il ne garantit pas encore la qualité des poids, des matériaux, des proportions ou des déformations.
- La galerie est un outil de contrôle, pas le système final de streaming des PNJ.
- Les animations walk/run ne sont pas encore reliées au déplacement des personnages.
- Le chargement des modèles doit être testé avec Godot sur la machine cible avant d'augmenter le nombre de PNJ visibles.

## Utiliser la bibliothèque de 200 modèles

Le workflow `.github/workflows/characters.yml` produit l'artefact GitHub Actions
`libreville-stories-ara3d-characters`. Il exporte les presets disponibles et les
variantes aléatoires demandées au lancement du workflow. Le nombre de variantes
aléatoires est un paramètre du workflow : ne pas confondre ce nombre avec le total
des fichiers GLB, car les presets sont ajoutés en plus.

### Récupération de l'archive

1. Ouvrir l'onglet **Actions** du dépôt GitHub.
2. Choisir le workflow **Build Ara 3D character library**.
3. Ouvrir l'exécution réussie correspondante.
4. Dans **Artifacts**, télécharger `libreville-stories-ara3d-characters`.
5. Extraire l'archive localement. Ne pas committer le ZIP de 1 Go dans le dépôt.

### Installation locale

Copier les fichiers GLB extraits dans :

```text
assets/characters/library/
```

Garder les fichiers de métadonnées et licences avec l'archive source. Ne pas supprimer
les sous-dossiers de métadonnées. Le dossier `library` est prévu pour les modèles
réutilisables, tandis que `base` conserve les modèles de référence.

### Attribution aux habitants

Le singleton `NPCModelLibrary` scanne les dossiers `library` et `base` au démarrage.
Il trie les chemins de façon déterministe, puis attribue un modèle à chaque résident
en fonction de son identifiant persistant. Ainsi, un même résident retrouve le même
gabarit après rechargement, même si l'ordre de création des habitants change.

Avant utilisation, chaque GLB est contrôlé : racine `Node3D`, squelette avec au moins
un os, `AnimationPlayer` et animation idle. Les modèles invalides sont ignorés.
Si aucun GLB valide n'est disponible, la galerie utilise le personnage procédural
de secours.

Les 200 GLB ne correspondent pas à 200 identités de résidents : les modèles sont des
gabarits visuels partagés. Les identités, familles, professions et apparences
individuelles restent stockées dans `PopulationManager`.

### Limites actuelles

- Le scan porte sur les fichiers GLB placés directement dans `library` et `base`,
  pas sur leurs sous-dossiers.
- Le modèle choisi est stable par identifiant, mais les vêtements, morphologies,
  cheveux et accessoires ne sont pas encore appliqués comme modifications du mesh.
- Le système est branché sur la galerie de test ; le streaming des PNJ dans le monde
  ouvert reste une étape distincte.
- Les modèles GLB ne sont pas embarqués dans Git. Chaque machine doit recevoir la
  bibliothèque localement ou via un paquet d'assets.
