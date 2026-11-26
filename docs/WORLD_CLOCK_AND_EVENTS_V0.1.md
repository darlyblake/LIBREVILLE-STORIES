# Horloge, calendrier et événements – version 0.1

## Objectif
Une horloge unique pilote le temps du monde. Les PNJ, commerces, écoles, panneaux publicitaires, radios et télévisions ne doivent pas chacun inventer leur propre date.

## Horloge
- Date de départ prototype : 1 janvier 2026 à 06:00.
- 1 minute de jeu = 1 seconde réelle par défaut (24 minutes réelles par journée complète).
- Vitesse réglable, pause/reprise, changement d'heure et avance rapide disponibles par API.
- Sauvegarde indépendante dans user://world_clock_state.json.
- Chaque changement de mois appelle PopulationManager.advance_month() une seule fois.

## Signaux à écouter
- minute_changed / hour_changed : éclairage, animations, circulation et horaires.
- day_started / day_ended : routines quotidiennes et réinitialisation des activités.
- month_changed / year_changed : statistiques, factures, population et calendrier.
- event_started / event_ended / active_events_changed : décorations, affichage, produits, émissions radio/TV et comportements PNJ.

## Événements déjà référencés
- Fêtes fixes gabonaises : 1er janvier, 17 avril (Journée nationale de la femme), 1er mai, 15 août, 16–17 août (indépendance), 30 août (Libération), 1er novembre et 25 décembre.
- Octobre Rose : campagne de sensibilisation aux cancers féminins, notamment sein et col de l'utérus.
- Novembre Bleu : sensibilisation aux cancers masculins, notamment prostate.
- Noël : période commerciale et culturelle du 1er au 25 décembre, distincte du jour férié du 25.
- Calendrier scolaire révisé 2025-2026 : périodes officielles renseignées. Le calendrier 2026-2027 n'est pas figé dans les données tant qu'une source officielle annuelle ne le confirme pas.

## Contrat pour les futurs systèmes
Les effets d'événements sont des données descriptives. Un système spécialisé devra les appliquer :
- ville/panneaux : décorations, affiches et campagnes de santé ;
- commerces : stocks saisonniers, promotions et horaires ;
- PNJ : présence des élèves, achats, célébrations, réunions familiales ;
- radios/TV : grille spéciale, jingles et annonces ;
- écoles : présence des élèves uniquement pendant les jours de classe et hors vacances ;
- circulation : embouteillages et déviations autour des rassemblements.

Les fêtes mobiles (Pâques, Pentecôte, Aïd) et les dates annuelles scolaires nécessitent un calendrier actualisé chaque année. Ne pas les figer avec une date arbitraire.

## Limites de la version
Cette première livraison fournit le moteur temporel et le catalogue d'événements. Elle ne crée pas encore les assets de décoration, les stocks réels, les émissions radio/TV ou les routines PNJ : ces systèmes devront écouter les signaux ci-dessus.


## Extension 0.2 – cycle jour/nuit
- Le nœud WorldLighting ajuste progressivement la lumière directionnelle, l'ambiance et la couleur du ciel/brouillard selon l'heure.
- La circulation et les piétons ralentissent pendant les heures nocturnes ; ils ne disparaissent pas brutalement.
- Les horaires des commerces et établissements sont fournis par WorldClock, mais leur fermeture physique et leurs animations restent à connecter à chaque bâtiment.
