# Test des manettes — Libreville Stories

## Commandes actuellement prévues

| Action | Clavier | Manette |
|---|---|---|
| Avancer / reculer | Z / W et S | Stick gauche vertical |
| Gauche / droite | Q / A et D | Stick gauche horizontal |
| Sauter | Espace | Bouton A (mappage Godot standard) |
| Orienter la caméra | Souris | Stick droit |
| Libérer/reprendre la souris | Échap / clic | À compléter |

Les touches clavier dépendent de la disposition utilisée : le projet conserve les actions existantes du clavier et ajoute les événements de manette au démarrage.

## Vérification sous Linux

1. Brancher la manette avant de lancer le jeu.
2. Dans un terminal, vérifier qu'Ubuntu la détecte avec `lsusb` (USB) ou les paramètres Bluetooth.
3. Lancer le projet Godot depuis l'éditeur ou le terminal.
4. Lire la console : le joueur doit afficher le nom et l'identifiant de la manette.
5. Tester le stick gauche, la croix directionnelle, le bouton A et le stick droit.
6. Débrancher puis rebrancher la manette pendant le jeu : les messages de connexion/déconnexion doivent apparaître.
7. Refaire le test dans une session de jeu exportée, pas seulement dans l'éditeur.

## Dépannage

- Si aucun périphérique n'est listé, vérifier la détection Linux avant d'accuser le jeu.
- Si le périphérique est détecté mais que les boutons ne correspondent pas, relever le modèle exact : certains contrôleurs ont des dispositions différentes (XInput, DirectInput ou Bluetooth).
- Ne pas considérer le support matériel comme validé tant qu'un test réel avec le modèle de manette utilisé n'a pas été effectué.

## Limites connues

- Les commandes de caméra du stick droit sont lues directement depuis le premier périphérique connecté.
- Les icônes de boutons affichées à l'écran et la reconfiguration des touches ne sont pas encore implémentées.
- La reconnexion et le mappage ont une validation automatisée du projet, mais nécessitent encore un test matériel.
