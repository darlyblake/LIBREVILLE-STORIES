# LIBREVILLE STORIES

Jeu PC 3D en monde ouvert inspiré de Libreville, au Gabon.

## Vision

Créer progressivement une ville explorable en 3D, avec une ambiance semi-réaliste et une carte inspirée des quartiers de Libreville. Le projet démarre par une première zone à pied, avant l'ajout des véhicules, missions et autres systèmes de jeu.

## Technologie

- **Moteur :** Godot 4
- **Rendu initial :** Compatibility, pour privilégier la compatibilité avec les cartes graphiques modestes
- **Plateforme de développement et de test :** Windows
- **Cible de performance initiale :** réglages modestes, textures optimisées et chargement progressif des zones

## Première zone prévue

- Centre-ville
- Louis
- Glass
- Nombakélé
- Mont-Bouët
- Nkembo
- Akébé

Ces noms définissent le périmètre de travail initial. Les limites géographiques précises devront être vérifiées avant de présenter la carte comme une reproduction exacte des quartiers.

## Feuille de route

1. Préparer la structure du projet et les conventions de travail.
2. Construire une scène Godot 4 minimale et un personnage contrôlable.
3. Importer les données géographiques et générer une première carte jouable.
4. Ajouter progressivement bâtiments, végétation, éclairage et ambiance sonore.
5. Tester les performances sur le PC cible et optimiser.
6. Ajouter ensuite véhicules, interactions et missions.

## Données cartographiques

Les données OpenStreetMap pourront servir de base pour les routes, bâtiments et points d'intérêt. Toute utilisation devra respecter les conditions de la base de données et afficher l'attribution : **© OpenStreetMap contributors**. Les données devront être vérifiées et adaptées au jeu ; elles ne constituent pas à elles seules une représentation complète du terrain.

## Organisation

Le développement se fera par étapes, avec des commits lisibles sur la branche `main`. Chaque livraison devra être testée dans Godot avant d'ajouter de nouveaux systèmes.

## État du projet

**Phase 0 — Initialisation.** Le dépôt est créé ; la première version jouable n'est pas encore disponible.
