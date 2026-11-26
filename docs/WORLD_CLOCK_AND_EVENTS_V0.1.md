# Horloge, calendrier et événements – version 0.3

## Objectif
Une horloge unique pilote le temps du monde. Les PNJ, commerces, écoles, panneaux publicitaires, radios et télévisions ne gèrent pas chacun leur propre date. Ils interrogent `WorldClock` et écoutent ses signaux.

## Horloge
- Date de départ du prototype : 1 janvier 2026 à 06:00.
- 1 minute de jeu = 1 seconde réelle par défaut (24 minutes réelles par journée complète).
- Vitesse réglable, pause/reprise, changement d'heure et avance rapide par API.
- Sauvegarde indépendante dans `user://world_clock_state.json`.
- Chaque passage réel au premier jour d'un nouveau mois appelle `PopulationManager.advance_month()` une seule fois.
- Un réglage manuel de date synchronise l'année et le mois du gestionnaire de population sans simuler artificiellement des mois de naissance/décès.

## Signaux
- `minute_changed` : horodatage complet ; HUD et systèmes qui nécessitent une précision à la minute.
- `hour_changed` : changement d'heure ; éclairage, horaires et routines.
- `day_started` / `day_ended` : routines quotidiennes.
- `month_changed` / `year_changed` : statistiques, population et calendrier.
- `event_started` / `event_ended` / `active_events_changed` : décorations, produits, médias, comportements et circulation.

Un changement manuel d'heure émet désormais `hour_changed` si l'heure change. Un changement manuel de date met à jour les événements actifs et les signaux de mois/année.

## Événements
- Fêtes fixes gabonaises référencées : 1er janvier, 17 avril, 1er mai, 15 août, 16–17 août, 30 août, 1er novembre et 25 décembre.
- Octobre Rose et Novembre Bleu sont des campagnes de sensibilisation, pas des jours fériés.
- La période commerciale de Noël (1er–25 décembre) est distincte du jour férié du 25 décembre.
- Les événements annuels peuvent traverser le 31 décembre : renseigner une année de référence identique pour les deux dates, par exemple 2000-12-20 au 2000-01-05.
- Les événements non annuels utilisent leurs dates calendaires réelles.

## Horaires de simulation
- Écoles : jour de classe, hors week-end, jour férié et vacances, entre 07:00 et 17:00.
- Commerces génériques : 07:00–20:00 en semaine et 08:00–20:00 le week-end ; fermés la nuit.
- Le marché Mont-Bouët conserve son horaire local prototype de 06:00–19:00.
- Les horaires restent des règles de simulation provisoires : chaque commerce/école pourra définir ses propres heures et jours de fermeture.

## Calendrier scolaire et limites
Les périodes scolaires 2025–2026 sont référencées dans les données présentes. Le calendrier 2026–2027 reste à confirmer par une annonce officielle. Les périodes scolaires révisées se chevauchent parfois avec les périodes de congés : le tag `school_holidays` est prioritaire et ferme les écoles.
Les fêtes mobiles (Pâques, Pentecôte, Aïd) et les dates scolaires annuelles doivent être actualisées à partir de sources officielles ; aucune date arbitraire ne doit être présentée comme officielle.

## Contrat pour les futurs systèmes
Les effets présents dans le JSON sont descriptifs. Chaque système spécialisé devra les appliquer :
- ville/panneaux : décorations, affiches et campagnes ;
- commerces : horaires, stocks saisonniers et promotions ;
- PNJ : présence des élèves, achats, célébrations et réunions familiales ;
- radios/TV : grille spéciale, jingles et annonces ;
- écoles : présence des élèves uniquement les jours de classe ;
- circulation : embouteillages et déviations autour des rassemblements.

## Validation
Le script `tools/validate_calendar.py` vérifie le JSON, les identifiants uniques, les dates et les plages annuelles, y compris celles qui traversent le Nouvel An. La CI vérifie également l'import et l'analyse des scripts Godot.
