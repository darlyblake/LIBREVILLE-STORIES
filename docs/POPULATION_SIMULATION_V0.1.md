# Simulation démographique persistante — Game Libreville

## Décisions de conception

Périmètre de prototype : Centre-ville, Louis, Glass, Nombakélé, Mont-Bouët, Nkembo et Akébé.

- Population initiale : **5 000 habitants vivants**.
- Plafond dur : **10 000 habitants vivants**.
- Les habitants sont des fiches de données ; les modèles 3D sont chargés séparément, à proximité du joueur.
- Une naissance est refusée si le plafond est atteint.
- Un décès libère immédiatement une place.
- Les dossiers des personnes décédées sont conservés pour l'arbre généalogique, les héritages et les événements historiques.
- Les identifiants ne sont jamais réutilisés.

Ces valeurs sont des paramètres de conception du jeu, pas un recensement officiel de Libreville.

## Règle anti-prolifération

À tout instant :

`0 <= habitants_vivants <= 10 000`

Le nombre de fiches historiques peut dépasser 10 000 sur plusieurs générations. Cela ne signifie pas que plus de 10 000 PNJ sont vivants ou instanciés : les morts restent des archives de données, sans personnage 3D actif.

## Version 0.2 — Familles et démographie

Le gestionnaire sait maintenant :

- Générer des identités avec sexe, âge, quartier et profession de départ.
- Former une partie des adultes en couples.
- Relier certains enfants existants à deux parents compatibles en âge.
- Conserver les identifiants des conjoints, parents et enfants.
- Enregistrer un mariage entre deux adultes célibataires.
- Enregistrer une amitié réciproque.
- Enregistrer une naissance avec deux parents vivants, un couple valide, une mère de 18 à 42 ans, un intervalle minimal de 18 mois et un maximum de quatre enfants par couple.
- Faire vieillir la population mois par mois.
- Appliquer une probabilité de décès naturel dépendant de l'âge.
- Marquer le conjoint survivant comme veuf ou veuve.
- Conserver la cause et la date du décès.
- Charger les anciennes sauvegardes de version 1 et compléter les champs manquants.
- Refuser toute naissance qui ferait dépasser le plafond.

Les probabilités de naissance et de mortalité sont des paramètres de simulation provisoires. Elles devront être calibrées pendant les tests de jeu, et ne sont pas présentées comme des statistiques officielles du Gabon.

## Paramètres actuels

- Chance mensuelle de naissance par couple éligible : 0,8 %.
- Âge de fertilité simulé : 18 à 42 ans pour la mère.
- Intervalle minimal entre deux naissances d'une même mère : 18 mois.
- Maximum : 4 enfants enregistrés par couple.
- Mortalité naturelle mensuelle : progressive selon l'âge, de 0,008 % chez les 1–14 ans à 1,2 % à partir de 80 ans.

## API principale

- `PopulationManager.get_population_stats()` : population vivante, capacité, places libres, naissances et décès du mois.
- `PopulationManager.get_resident(id)` : copie des données d'un habitant.
- `PopulationManager.get_family(id)` : habitant, parents, conjoint et enfants.
- `PopulationManager.register_marriage(id_a, id_b)` : enregistre un couple marié.
- `PopulationManager.add_friend(id_a, id_b)` : crée une amitié réciproque.
- `PopulationManager.register_birth(mother_id, father_id)` : enregistre une naissance si toutes les conditions sont réunies.
- `PopulationManager.register_death(id, cause)` : enregistre un décès.
- `PopulationManager.advance_month()` : fait avancer l'âge et les événements démographiques d'un mois de jeu.
- `PopulationManager.save_population()` : sauvegarde manuelle.

## Sauvegarde et performance

- Script : `game/scripts/population_manager.gd`.
- Autoload : `PopulationManager`, déclaré dans `project.godot`.
- Sauvegarde : `user://population_state.json`.
- Configuration : `data/population/population_config.cfg`.

Le passage d'un mois regroupe les écritures de sauvegarde afin d'éviter une écriture disque pour chaque naissance ou décès. Le gestionnaire ne crée aucun modèle 3D.

## Étape d'intégration restante

Le projet ne possède pas encore de calendrier de jeu central identifié. Il faudra donc connecter `PopulationManager.advance_month()` au futur système d'horloge/calendrier. Tant que cet appel n'est pas relié à une horloge, les habitants ne vieillissent pas en temps réel dans une partie.

Le système de routines quotidiennes, de métiers réels, d'employeurs, de boutiques, d'héritage et de réactions sociales reste à développer.

## Validation

Le code a été enregistré dans le dépôt. Il n'a pas encore été exécuté dans Godot dans cet environnement : le test de parsing et les essais en jeu doivent être effectués dans l'éditeur Godot avant de considérer cette version comme validée.
