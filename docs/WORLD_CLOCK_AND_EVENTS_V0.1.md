# Horloge, calendrier et événements – version 0.4

## Objectif
Une horloge unique pilote le temps du monde. Les PNJ, commerces, écoles, panneaux publicitaires, radios et télévisions ne gèrent pas chacun leur propre date. Ils interrogent `WorldClock` et écoutent ses signaux.

## Horloge
- Date de départ du prototype : 1 janvier 2026 à 06:00.
- 1 minute de jeu = 1 seconde réelle par défaut (24 minutes réelles par journée complète).
- Vitesse réglable, pause/reprise, changement d'heure et avance rapide par API.
- Sauvegarde indépendante dans `user://world_clock_state.json`.
- Chaque passage réel au premier jour d'un nouveau mois appelle `PopulationManager.advance_month()` une seule fois.
- Un réglage manuel de date synchronise l'année et le mois du gestionnaire de population sans simuler artificiellement des mois de naissance/décès.
- Le changement manuel d'heure émet `hour_changed` si l'heure change ; les événements actifs sont recalculés à chaque changement de jour ou de date.

## Signaux
- `minute_changed` : horodatage complet ; HUD et systèmes à la minute.
- `hour_changed` : changement d'heure ; éclairage, horaires et routines.
- `day_started` / `day_ended` : routines quotidiennes.
- `month_changed` / `year_changed` : statistiques, population et calendrier.
- `event_started` / `event_ended` / `active_events_changed` : décorations, produits, médias, comportements et circulation.

## Calendrier scolaire gabonais intégré
### Année 2025–2026
- Deuxième trimestre révisé : 24 novembre 2025 – 28 mars 2026.
- Reprise effective des cours après les perturbations : 19 janvier 2026 ; la période précédente est marquée comme interruption dans la simulation.
- Troisième trimestre : 30 mars – 31 juillet 2026.
- Fin des cours des classes sans examen : 20 juin 2026 ; fin de l'année des classes d'examen : 31 juillet 2026.

### Année 2026–2027
- Rentrée administrative : 31 août 2026.
- Rentrée des élèves des écoles publiques conventionnées : 2 septembre 2026.
- Rentrée générale des établissements publics et privés : 7 septembre 2026.
- Premier trimestre : 7 septembre – 28 novembre 2026 ; congés jusqu'au 6 décembre.
- Deuxième trimestre : 7 décembre 2026 – 6 mars 2027 ; congés jusqu'au 14 mars.
- Troisième trimestre : 15 mars – 10 juillet 2027.
- Fin des cours des classes sans examen : 5 juin 2027.
- Période annoncée des examens nationaux : 24 mai – 10 juillet 2027.

Les jours de congés utilisent le tag `school_holidays`, prioritaire sur `school_in_session`, pour éviter qu'un chevauchement de dates laisse les écoles ouvertes.

## Jours fériés et fêtes
- Fêtes fixes récurrentes : 1er janvier, 17 avril (Journée des droits de la femme), 1er mai, 15 août, 16–17 août (indépendance), 30 août (Journée nationale de la Libération), 1er novembre et 25 décembre.
- Octobre Rose et Novembre Bleu sont des campagnes de sensibilisation, pas des jours fériés.
- Noël (1er–25 décembre) est une période culturelle/commerciale distincte du jour férié du 25 décembre.
- Les dates mobiles de 2026 déjà référencées comprennent Pâques, lundi de Pâques, Ascension, Pentecôte et lundi de Pentecôte.
- Les dates de l'Aïd sont marquées comme estimatives et doivent être confirmées par les annonces officielles.
- Les événements annuels peuvent traverser le 31 décembre : utiliser une année de référence identique, par exemple 2000-12-20 au 2000-01-05. Les événements non annuels utilisent leurs dates réelles.

## Horaires de simulation
- Écoles : jour de classe, hors week-end, jour férié et vacances, entre 07:00 et 17:00.
- Commerces génériques : 07:00–20:00 en semaine et 08:00–20:00 le week-end ; fermés la nuit.
- Marché Mont-Bouët : horaire local prototype de 06:00–19:00.
- Ces plages sont des règles générales provisoires ; chaque commerce, administration ou école pourra définir ses horaires propres, jours de fermeture et horaires spéciaux.

## Contrat pour les futurs systèmes
Les effets présents dans le JSON sont descriptifs. Chaque système spécialisé devra les appliquer :
- ville/panneaux : décorations, affiches et campagnes ;
- commerces : horaires, stocks saisonniers et promotions ;
- PNJ : présence des élèves, achats, célébrations et réunions familiales ;
- radios/TV : grille spéciale, jingles et annonces ;
- écoles : présence des élèves uniquement les jours de classe ;
- circulation : embouteillages et déviations autour des rassemblements.

## Sources et actualisation
- Ministère de l'Éducation nationale – calendrier scolaire 2025–2026 et rentrée 2026–2027 : https://education-nationale.gouv.ga/calendrier-scolaire/
- Arrêté n°000008/MENIC du 30 janvier 2026, calendrier scolaire révisé 2025–2026 : https://gabonmediatime.com/wp-content/uploads/2026/02/Arrete-000008-MENIC-portant-Modification-des-2eme-et-3eme-Trimestre-du-calendrier-Scolaire-2025-2026.pdf
- Calendrier 2026–2027, trimestres et congés annoncés à la suite de l'arrêté du 10 août 2026 : les dates de trimestre sont reprises des publications qui rapportent le calendrier ministériel ; à remplacer par le texte intégral officiel dès qu'il est disponible.
- Fêtes religieuses dépendant de l'observation lunaire : vérifier chaque année les annonces gouvernementales.

## Validation
`tools/validate_calendar.py` vérifie le JSON, les identifiants uniques, les dates et les plages annuelles, y compris celles qui traversent le Nouvel An. La CI vérifie également l'import et l'analyse des scripts Godot.

## Profils d'horaires centralisés – version 0.5
Les profils sont déclarés dans `data/calendar/opening_hours.json` et chargés par `WorldClock`. Chaque lieu peut demander `is_schedule_open(profile_id)` ou `get_schedule_status(profile_id)`, qui retourne aussi la raison de fermeture.
Profils prototype :
- `school` : lundi–vendredi, 07:00–17:00, uniquement pendant les périodes scolaires et hors jours fériés.
- `administration` et `bank` : lundi–vendredi, 07:30–15:30.
- `retail` : 07:00–20:00 en semaine, 08:00–20:00 le week-end.
- `market_mont_bouet` : tous les jours, 06:00–19:00.
- `hospital` et `police` : services de garde 24 h/24.
- `pharmacy` : profil de pharmacie de garde simulée, 08:00–22:00.
Ces heures sont des valeurs de simulation, non des horaires officiels garantis. Elles seront personnalisables établissement par établissement. Les plages sont en heure locale du monde ; les jours utilisent 0=dimanche, 1=lundi, ..., 6=samedi.


## Rythmes de vie, congés et fréquentation – version 0.6
Le singleton `LifeSimulationManager` écoute `WorldClock.hour_changed` et `day_started`. Il calcule une activité abstraite pour chaque résident vivant, sans créer un nœud 3D par personne.
- Les salariés disposent de deux jours de repos hebdomadaires ; la majorité suit le week-end, une minorité a des repos décalés pour les métiers de service.
- Les jours de congé annuels sont distribués de façon déterministe par résident et par année. La valeur prototype est de 20 jours calendaires consécutifs ; ce paramètre est à ajuster selon le métier et les règles de travail retenues.
- Les élèves suivent le calendrier scolaire et les jours de fermeture définis par `WorldClock`.
- Les soirées peuvent déclencher une sortie au bar, surtout les week-ends et vacances. La consommation augmente un indicateur d'alcoolémie simulé ; le repos la fait diminuer progressivement.
- La fatigue et l'alcool diminuent le multiplicateur de performance au travail et augmentent un multiplicateur de risque de conduite.
- `get_crowd_multiplier(type)` fournit une fréquentation de référence pour les marchés, restaurants, loisirs, front de mer, parcs et bars. Les multiplicateurs sont des paramètres de simulation, pas des comptages réels.
- Les profils et les valeurs sont dans `data/simulation/life_profiles.json`.

Cette version prépare les conséquences sociales et la future simulation d'accidents. Elle ne crée pas encore de collisions, blessures, conduite sous influence ou itinéraires physiques : ces systèmes devront consommer les facteurs de risque et les activités, puis être testés séparément.
