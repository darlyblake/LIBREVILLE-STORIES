# Personnage de test — LIBREVILLE STORIES

Le personnage de test utilise le mannequin humanoïde riggé **UAL1_Standard.glb** de Quaternius, repris du dépôt OpenCity. Le modèle comprend un squelette et des animations de locomotion. Il est sous licence CC0 1.0 ; voir `LICENSE-Quaternius-UAL.txt`.

## Installation du modèle

Le fichier GLB est un binaire de 7,6 Mo. Il n'a pas été possible de transférer ce binaire avec l'éditeur de fichiers texte GitHub utilisé pour les corrections. Deux méthodes sont possibles :

- **Automatique (recommandé)** : ouvrir l'onglet GitHub **Actions**, choisir **Import CC0 test character**, puis cliquer sur **Run workflow** sur la branche `main`. Le workflow télécharge le modèle, vérifie son empreinte Git et le commit dans le dépôt.
- **Manuelle** : depuis la racine du dépôt, exécuter :

```bash
mkdir -p assets/models/characters
curl -L --fail "https://raw.githubusercontent.com/webgl-games/opencity/main/assets/characters/UAL1_Standard.glb" -o assets/models/characters/UAL1_Standard.glb
```

Ouvrir ensuite le projet avec Godot 4.3 ou supérieur et laisser l'import GLB se terminer. La scène principale charge automatiquement le mannequin et utilise Idle, Walk, Jog_Fwd/Sprint et Jump. En attendant le téléchargement, un mannequin humain provisoire est généré à la place du tube bleu.

Source du modèle : https://github.com/webgl-games/opencity
Licence : CC0 1.0 Universal.
