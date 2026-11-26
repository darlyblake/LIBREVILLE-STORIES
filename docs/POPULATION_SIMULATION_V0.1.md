# Simulation démographique persistante — Game Libreville

## Décision de conception (version 0.1)

Périmètre initial : Centre-ville, Louis, Glass, Nombakélé, Mont-Bouët, Nkembo et Akébé.

- Plafond dur : **10 000 habitants vivants**.
- Population de départ : **5 000 habitants**.
- Les habitants sont enregistrés comme données ; ils ne sont pas tous instanciés en 3D.
- La population visible dans le quartier est indépendante du nombre d'habitants enregistrés.
- Une naissance est refusée si le plafond est atteint.
- Un décès libère immédiatement une place ; une naissance ultérieure peut utiliser cette place.
- Les dossiers des personnes décédées sont conservés pour l'histoire, les liens familiaux, les héritages et les enquêtes.
- Les identifiants ne sont jamais réutilisés.

## Règle anti-explosion

À tout instant :

`0 <= habitants_vivants <= 10 000`

Une naissance augmente la population vivante de 1 uniquement si une place est libre. Un décès la diminue de 1. Les anciens dossiers restent dans l'historique, mais ne comptent plus dans la population vivante. Le nombre de dossiers historiques peut donc dépasser 10 000 au fil des générations ; il ne s'agit pas de PNJ actifs ni de modèles 3D.

## Architecture

- `population_manager.gd` : registre central, identifiants, naissances, décès, âge, sauvegarde.
- `population_config.cfg` : paramètres démographiques documentés.
- `user://population_state.json` : sauvegarde locale persistante.
- Le futur calendrier du jeu appellera `PopulationManager.advance_month()`.
- Le futur système de vie quotidienne lira les données et n'instanciera les modèles 3D que près du joueur.

## Limites de cette première fondation

Cette version crée une population initiale et fournit les opérations contrôlées de naissance, décès, vieillissement et sauvegarde. Elle ne génère pas encore automatiquement les couples, grossesses, décès naturels, emplois réels, familles complètes ou routines quotidiennes. Ces systèmes seront ajoutés progressivement et devront tous respecter le plafond.

## Performance

Le plafond de 10 000 concerne les fiches de données, pas 10 000 personnages visibles. La cible initiale est de n'instancier qu'un petit groupe de personnages proches du joueur. Les limites de rendu et de simulation active seront mesurées sur le Dell de développement avant d'être augmentées.
