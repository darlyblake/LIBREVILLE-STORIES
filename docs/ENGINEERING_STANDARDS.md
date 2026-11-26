# Règles de qualité technique — LIBREVILLE STORIES

Ce document adapte au projet Godot les pratiques utiles observées dans les dépôts NEXUS-CONTROL, ServiPro, Système Administratif Scolaire et LibreShop Lite.

## Principes repris

- **Validation automatisée avant intégration** : comme dans NEXUS-CONTROL et le projet scolaire, les changements importants doivent passer par des contrôles GitHub Actions.
- **Tests de comportement, pas seulement compilation** : NEXUS-CONTROL exécute des tests de relais et de sécurité. Pour le jeu, les systèmes de calendrier, population, sauvegarde et géographie doivent progressivement recevoir des tests de régression.
- **Gestion d'erreurs explicite** : retenir le principe d'un gestionnaire d'erreurs central observé dans ServiPro, mais utiliser les mécanismes Godot (`push_warning`, `push_error`, retours booléens et journaux structurés) plutôt que copier le code Android.
- **Contrôles de performance en amont** : retenir le suivi de performance et le chargement différé, adaptés au matériel cible (Intel UHD 620 / 16 Go RAM). Les habitants éloignés restent des données, pas des nœuds 3D actifs.
- **Checklist de vérification** : comme dans LibreShop Lite, chaque fonctionnalité doit avoir des étapes de vérification reproductibles.

## Règles propres à LIBREVILLE STORIES

1. Ne jamais inventer une coordonnée ou une empreinte de bâtiment : conserver la géométrie OSM et documenter séparément les éléments reconstitués depuis des photographies.
2. Séparer les données persistantes des objets 3D temporaires.
3. Faire communiquer les systèmes par des signaux ou interfaces définies, sans multiplier les références directes entre scènes.
4. Valider les fichiers JSON et les ressources avant d'exécuter la simulation.
5. Toute sauvegarde doit être versionnée, vérifiée à la lecture et protégée contre les données manquantes ou corrompues.
6. Toute modification de population doit préserver les invariants : plafond de 10 000 habitants vivants, identifiants uniques, relations familiales cohérentes.
7. Les systèmes dépendants du calendrier doivent utiliser exclusivement `WorldClock`, pas leur propre horloge.
8. Une modification n'est considérée comme validée qu'après réussite du contrôle automatisé et, lorsque nécessaire, un essai dans Godot.

## Contrôles déjà automatisés

- Import et analyse des scripts/ressources avec Godot 4.3 en mode headless.
- Inspection des clips d'animation des personnages.
- Validation indépendante du JSON du calendrier : structure, identifiants uniques, dates ISO, ordre des dates et types des champs.

## Contrôles à ajouter progressivement

- Tests de transitions jour/mois/année et des événements récurrents.
- Tests de sauvegarde/rechargement et migration de population.
- Vérification des liens parents/enfants/conjoints et du plafond de population.
- Tests de génération géographique sur des polygones simples, multipolygones et géométries invalides.
- Mesure du nombre de nœuds 3D actifs et du temps de frame dans les quartiers chargés.

Les dépôts de référence servent de source de méthodes, pas de code à copier. Les implémentations Android, web et backend ne sont pas transplantées dans Godot.
