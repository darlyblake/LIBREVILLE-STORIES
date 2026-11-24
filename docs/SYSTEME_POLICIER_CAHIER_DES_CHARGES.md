# LIBREVILLE STORIES — Cahier des charges technique
## Système policier Godot 4

> Version : 1.0  
> Statut : spécification approuvée — conception, pas encore implémentée  
> Dépôt : darlyblake/LIBREVILLE-STORIES  
> Cible : Godot 4.x, rendu Compatibility, PC modestes

## 1. Objectif

Construire un système policier crédible pour un monde ouvert inspiré de Libreville et du Gabon. Le système privilégie les contrôles, patrouilles, enquêtes et interpellations ciblées plutôt qu'une poursuite permanente de type arcade.

Le joueur commence comme civil. La pression policière évolue selon les faits, les preuves, les témoins, l'identification et la gravité des événements.

## 2. Décisions fonctionnelles verrouillées

| Domaine | Règle validée |
|---|---|
| Arrestation | Modèle mixte : amende, procédure ou détention selon le cas |
| Flotte | Mixte : voitures ordinaires, 4x4 blancs, Iveco |
| Recherche | Persistante jusqu'à résolution de l'enquête |
| Pression | Peut diminuer sans effacer l'enquête |
| Poursuite | Possible, mais rare et contextuelle |
| Hélicoptères | Pas de présence ni poursuite ordinaire par hélicoptère |
| Contrôles | Plus probables la nuit ; contrôles commerciaux plus probables le matin |
| Localisation | Distinguer dernière position connue, adresse identifiée et position observée |
| Corruption | Comportements individuels possibles, jamais généralisés à toute la police |

Les plages horaires sont des paramètres de conception et ne doivent pas être présentées comme des horaires officiels de la police gabonaise.

## 3. Périmètre fonctionnel

### 3.1 Patrouilles

- Patrouilles à pied et en véhicules.
- Véhicules : voiture de patrouille, 4x4, Iveco de transport.
- Routes et points de contrôle configurés dans la carte.
- Variations selon l'heure, le secteur et les événements actifs.
- Densité faible par défaut afin de préserver les performances.
- Aucun véhicule ne doit apparaître directement dans le champ de vision du joueur pour créer artificiellement une intervention.

### 3.2 Contrôles routiers

- Points de contrôle activables par plages horaires.
- Sélection pondérée des points disponibles.
- Contrôle possible des véhicules commerciaux le matin.
- Contrôles de véhicules particuliers possibles, notamment la nuit.
- Interaction : ralentir, s'arrêter, présenter les documents, recevoir une amende ou être orienté vers une vérification complémentaire.
- Les contrôles ne doivent pas être présents sur toutes les routes ni à chaque déplacement.

### 3.3 Détection et signalement

Chaque événement peut produire une information policière avec : type d'incident, heure du jeu, secteur, description du suspect, véhicule associé si connu, source (agent, témoin, preuve ou mission), niveau de fiabilité et statut de traitement.

Ne pas confondre un événement observé avec une identité confirmée. Une infraction sans témoin ni preuve exploitable ne doit pas automatiquement révéler le nom du protagoniste.

### 3.4 Enquête et recherche

États de recherche :
1. UNKNOWN : aucune identité attribuée ;
2. IDENTIFIED : identité connue, sans recherche active ;
3. WANTED : recherche active ;
4. LOCATED : adresse ou position exploitable connue ;
5. RESOLVED : enquête résolue.

États complémentaires possibles pour l'enquête : OPEN, SUSPENDED, CLOSED_NO_EVIDENCE, CLOSED_RESOLVED.

Règles :
- Les dossiers persistent entre les sessions.
- La pression opérationnelle peut baisser, mais les preuves et l'identité restent.
- Une nouvelle preuve peut réactiver une recherche.
- Les vêtements et le véhicule peuvent affecter la reconnaissance visuelle, mais ne suppriment pas les preuves d'identité.
- Une adresse n'est connue que si le scénario ou les éléments collectés la rendent disponible.
- La police ne connaît jamais la position exacte du joueur sans observation ou information scénarisée récente.

### 3.5 Poursuites

- Déclenchement uniquement si un agent a observé un événement ou reçu une information suffisamment fiable et dispose d'un moyen d'intervention.
- Une poursuite peut perdre en intensité si le contact visuel est rompu.
- La recherche demeure dans le dossier si l'identité a été établie.
- Pas de génération infinie de véhicules.
- Les unités spécialisées sont réservées aux événements graves ou aux missions spécifiques.
- Les poursuites doivent être compatibles avec le réseau routier réellement généré.

### 3.6 Arrestations et sanctions

Résultats possibles : avertissement, amende, immobilisation temporaire du véhicule, interpellation, détention ou libération après procédure scénarisée.

Les règles de sanction doivent être configurées par type d'incident. Le joueur reçoit un message expliquant la raison, le montant éventuel et les conséquences. Aucun prélèvement silencieux.

## 4. Architecture Godot proposée

Cette architecture est une cible de conception. Avant l'implémentation, vérifier les scènes, autoloads et conventions déjà présents dans le dépôt pour éviter les doublons.

- game/police/data/ : police_config.gd, patrol_profile.gd, offense_definition.gd
- game/police/managers/ : police_dispatch.gd, wanted_manager.gd, investigation_manager.gd, checkpoint_manager.gd, arrest_manager.gd, police_save_adapter.gd
- game/police/actors/ : police_agent.gd, police_patrol_vehicle.gd, checkpoint_controller.gd
- game/police/resources/patrol_routes/ : ressources de routes de patrouille
- game/police/resources/checkpoint_points/ : emplacements de contrôles
- game/police/scenes/ : scènes d'agent, voiture, 4x4, Iveco et barrage

### Responsabilités des modules

| Module | Responsabilité |
|---|---|
| PoliceDispatch | Distribuer les alertes et choisir les unités disponibles |
| WantedManager | Maintenir les états de recherche et la pression |
| InvestigationManager | Gérer preuves, témoins, dossiers et résolution |
| CheckpointManager | Planifier les contrôles selon horaires et points |
| ArrestManager | Appliquer interpellation, amende et détention |
| PoliceSaveAdapter | Sérialiser et restaurer l'état policier |
| PoliceAgent | Perception locale, interaction et comportement d'agent |
| PatrolVehicle | Déplacement, arrêt, navigation et transport des agents |

Les managers doivent être indépendants de la scène de carte autant que possible. Les données de patrouille et de contrôle doivent être configurables, pas codées en dur dans les scripts d'IA.

## 5. Modèle de données recommandé

### WantedRecord

- suspect_id : String
- wanted_state : enum
- investigation_state : enum
- known_identity : bool
- last_known_position : Vector3 ou identifiant de secteur
- known_home_location_id : String
- evidence_ids : Array[String]
- witness_report_ids : Array[String]
- associated_vehicle_ids : Array[String]
- operational_pressure : float entre 0 et 1
- created_at_game_time : float
- updated_at_game_time : float

### PoliceIncident

- incident_id : String unique
- incident_type : String
- severity : int
- game_timestamp : float
- location_id : String
- suspect_id : String optionnel
- vehicle_id : String optionnel
- source_type : enum (OFFICER, WITNESS, EVIDENCE, MISSION)
- confidence : float entre 0 et 1
- evidence_status : enum

### CheckpointDefinition

- checkpoint_id : String
- location_id : String
- active_time_ranges : Array
- vehicle_profile_weights : Dictionary
- unit_profile : String
- spawn_budget : int
- enabled : bool

Les structures doivent utiliser des types explicites et des valeurs par défaut sûres. Les identifiants persistants ne doivent pas dépendre de l'ordre des nœuds dans une scène.

## 6. Horaires et profils de contrôle

Valeurs de départ proposées, modifiables dans les données :

| Plage | Profil |
|---|---|
| 06:00–12:00 | Probabilité supérieure de contrôles commerciaux |
| 12:00–18:00 | Patrouilles et contrôles ponctuels |
| 18:00–06:00 | Probabilité supérieure de contrôles nocturnes |

La sélection doit prendre en compte le secteur, l'heure du jeu, la densité de circulation, les contrôles déjà actifs à proximité, la disponibilité d'une unité, les événements de mission et le budget de véhicules actifs.

Éviter les contrôles redondants dans un rayon trop faible.

## 7. IA et états de comportement

États possibles d'un agent : PATROL, OBSERVE, APPROACH, CHECK, INVESTIGATE, PURSUE, SEARCH_AREA, ARREST et RETURN.

Les transitions doivent être explicites et testables. Un agent ne doit pas passer en PURSUE sur la seule base d'une suspicion non confirmée.

## 8. Sauvegarde et persistance

La sauvegarde doit conserver les dossiers d'enquête ouverts, états de recherche, preuves et signalements, infractions connues, amendes dues ou payées, état de détention et heure de libération, contrôles et missions ayant un impact persistant.

Ne pas sauvegarder chaque agent ou chaque véhicule de patrouille actif. Sauvegarder les données de simulation et reconstruire les patrouilles au chargement.

Prévoir une version de schéma de sauvegarde pour permettre les migrations.

## 9. Performance et robustesse

Cible : PC modestes et rendu Godot Compatibility.

- IA active uniquement dans un rayon pertinent autour du joueur.
- Simulation simplifiée des patrouilles éloignées.
- Pooling des véhicules et agents si nécessaire.
- Limite configurable du nombre d'unités actives.
- Pas de requête de navigation coûteuse à chaque frame.
- Utiliser des timers et des mises à jour espacées pour les décisions non urgentes.
- Éviter les recherches globales répétées dans l'arbre de scène.
- Les systèmes doivent tolérer l'absence temporaire de véhicule, de navigation ou de point de contrôle.

## 10. Cohérence et protection des données

Le système de recherche policière est un système de jeu, pas un outil de surveillance réelle. Les coordonnées et adresses du jeu sont fictives ou issues de la carte de jeu, jamais des données personnelles du joueur. Ne pas reproduire de procédures opérationnelles sensibles ni prétendre décrire les méthodes réelles des unités. Représenter plusieurs comportements policiers sans généralisation abusive. Les noms d'unités réelles doivent être vérifiés avant publication ; sinon utiliser des unités fictives.

## 11. Plan d'implémentation

### Phase 0 — Audit du projet
- Vérifier la scène principale et les autoloads.
- Vérifier le système temps/jour-nuit existant.
- Vérifier le joueur, les véhicules et le réseau de routes.
- Vérifier le format de sauvegarde existant.
- Confirmer les conventions de scripts et de ressources.

### Phase 1 — Données et enquête
- Définir les ressources de configuration.
- Implémenter incidents et signalements.
- Implémenter WantedManager.
- Tester la persistance et les transitions d'état.

### Phase 2 — Contrôles et patrouilles
- Ajouter des points de contrôle configurables.
- Ajouter le scheduler horaire.
- Ajouter les premiers agents et véhicules placeholder.
- Tester les contrôles matin/nuit.

### Phase 3 — Interpellation et sanctions
- Implémenter interaction de contrôle.
- Implémenter amende, immobilisation et détention.
- Relier les sanctions au temps et à l'économie du joueur.

### Phase 4 — Poursuite et recherche ciblée
- Ajouter la perception et les poursuites.
- Ajouter la perte de contact et la recherche de zone.
- Ajouter les interpellations hors poursuite et les événements scénarisés à domicile.

### Phase 5 — Intégration et optimisation
- Intégrer les modèles de véhicules.
- Tester sur la carte complète.
- Profiler sur une machine modeste.
- Vérifier sauvegarde, chargement et reprise des enquêtes.

## 12. Critères d'acceptation

- [ ] Une infraction non observée ne révèle pas automatiquement l'identité du joueur.
- [ ] Un témoin ou une preuve peut créer un signalement.
- [ ] Une recherche active reste après sauvegarde et rechargement.
- [ ] La pression policière peut diminuer sans effacer le dossier.
- [ ] Une enquête résolue change l'état du dossier.
- [ ] Les contrôles matinaux favorisent les profils commerciaux.
- [ ] Les contrôles nocturnes peuvent viser les véhicules particuliers.
- [ ] Les contrôles ne bloquent pas systématiquement les routes.
- [ ] Les trois familles de véhicules (voiture, 4x4, Iveco) sont supportées.
- [ ] Une interpellation peut arriver sans course-poursuite.
- [ ] Une amende est expliquée avant paiement.
- [ ] La détention fait avancer le temps et applique les conséquences prévues.
- [ ] Les poursuites sont limitées et peuvent perdre le contact.
- [ ] Aucun hélicoptère n'est généré par défaut.
- [ ] Les systèmes ne provoquent pas d'erreur si une unité ou un point de contrôle manque.

## 13. Tests Godot recommandés

Créer des tests automatisés pour les transitions de WantedRecord, la persistance après sauvegarde/chargement, la baisse de pression sans effacement du dossier, la réactivation après nouvelle preuve, la pondération des contrôles par plage horaire, le calcul des amendes, le passage en détention et l'avance du temps, la limite d'unités actives, l'absence de poursuite sans détection valide et l'absence d'erreur quand une scène de véhicule est indisponible.

La validation finale doit inclure un lancement headless Godot et un test en jeu sur la carte réelle.

## 14. État de livraison

Ce document constitue le cahier des charges validé. Il ne signifie pas que les scripts, scènes, véhicules ou IA policières sont déjà implémentés. Toute implémentation doit commencer par la phase 0 d'audit du projet existant.
