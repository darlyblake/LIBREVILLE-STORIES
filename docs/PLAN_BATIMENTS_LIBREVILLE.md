# Plan de construction des bâtiments — LIBREVILLE-STORIES

> Document de suivi vivant. Les cases sont cochées uniquement après une intégration vérifiée dans le dépôt. Une adresse connue ne suffit pas à valider un emplacement GPS ou un modèle 3D.

## 1. Zone géographique du jeu

- Latitude : **0.355 à 0.445**
- Longitude : **9.400 à 9.495**
- Référence : Libreville, Gabon.
- Les bâtiments physiques ordinaires proviennent de `data/osm/extended/buildings.geojson`.
- Les repères nommés sont gérés par `game/scripts/facility_generator.gd`.
- Ne pas créer de volumes génériques qui doublonnent les empreintes de `buildings.geojson`.
- Ne jamais inventer de coordonnées, dimensions, façades ou textures présentées comme celles d'un bâtiment réel.

## 2. Légende

- [x] Réalisé et vérifié dans le dépôt.
- [ ] À faire.
- **GPS** : point cartographique identifié dans la zone.
- **Repère jeu** : nom/panneau intégré.
- **Modèle 3D** : géométrie détaillée créée.
- **Textures** : matériaux/façades réalistes intégrés.
- **Godot** : scène réellement ouverte et vérifiée dans Godot.

## 3. Administrations prioritaires

| Bâtiment / site | GPS | Repère jeu | Modèle 3D détaillé | Textures réalistes | Contrôle Godot |
|---|---|---|---|---|---|
| Ministère des Eaux et Forêts | [x] | [x] | [ ] | [ ] | [ ] |
| Palais Omar Bongo Ondimba / Sénat | [x] | [x] | [ ] | [ ] | [ ] |
| Immeuble du 2 Décembre / Ministère des Mines | [ ] | [x] | [ ] | [ ] | [ ] |
| Ministère de la Fonction publique | [x] | [x] | [ ] | [ ] | [ ] |
| Ministère de la Justice — Rue Pecqueur | [x] | [x] | [ ] | [ ] | [ ] |
| Ministère de la Santé — Immeuble Alu-Suisse | [x] | [x] | [ ] | [ ] | [ ] |
| Maison Jean Ping — Affaires étrangères | [x] | [x] | [ ] | [ ] | [ ] |
| Tribunal de première instance — annexe | [x] | [x] | [ ] | [ ] | [ ] |
| Direction générale du Budget — avenue Félix Éboué | [x] | [x] | [ ] | [ ] | [ ] |
| Ministère de la Communication et des Médias | [x] | [x] | [ ] | [ ] | [ ] |
| Ministère de l’Intérieur — avenue de Cointet | [x] | [x] | [ ] | [ ] | [ ] |
| Ministère de l’Éducation nationale — Formation civique | [x] | [x] | [ ] | [ ] | [ ] |
| Agence nationale des infrastructures numériques et des fréquences (ANINF) — Immeuble de la Solde | [x] | [x] | [ ] | [ ] | [ ] |
| Direction Générale de la Comptabilité Publique et du Trésor (DGCPT) — 321 avenue Rose Francine Rogombe | [x] | [x] | [ ] | [ ] | [ ] |
| Conférence Interafricaine des Marchés d’Assurances (CIMA) — centre-ville | [x] | [x] | [ ] | [ ] | [ ] |
| Palais présidentiel du Bord de mer — boulevard de l’Indépendance | [x] | [x] | [ ] | [ ] | [ ] |
| Ministère du Travail et de la Formation professionnelle | [x] | [x] | [ ] | [ ] | [ ] |
| Ministère de la Planification et de la Prospective | [x] | [x] | [ ] | [ ] | [ ] |
| CEEAC — Haut de Gué-Gué | [x] | [x] | [ ] | [ ] | [ ] |
| ANUTTC — Agence Nationale de l’Urbanisme, des Travaux Topographiques et du Cadastre — Oloumi | [x] | [x] | [ ] | [ ] | [ ] |
| BRAC-OIF — Bureau régional de l’OIF pour l’Afrique centrale | [x] | [x] | [ ] | [ ] | [ ] |
| DGTTC — Direction Générale des Travaux Topographiques et du Cadastre — Trois quartiers | [x] | [x] | [ ] | [ ] | [ ] |
| DGEL — Direction Générale des Études et Laboratoires — Ancien Sobraga | [x] | [x] | [ ] | [ ] | [ ] |
| CNEE — Conseil National de l’Eau et de l’Électricité — Haut de Gué-Gué | [x] | [x] | [ ] | [ ] | [ ] |
| CND — Conseil National de la Démocratie — secteur Ancien Sobraga | [x] | [x] | [ ] | [ ] | [ ] |
| Palais Léon Mba — Assemblée nationale — Boulevard Triomphal Omar Bongo | [x] | [x] | [ ] | [ ] | [ ] |
| Direction Générale des Douanes et Droits Indirects — Oloumi | [x] | [x] | [ ] | [ ] | [ ] |
| Cour constitutionnelle du Gabon — Boulevard de l’Indépendance | [x] | [x] | [ ] | [ ] | [ ] |
| Agence Gabonaise de Sécurité Alimentaire (AGASA) — Batterie 4 | [x] | [x] | [ ] | [ ] | [ ] |
| Institut National de Cartographie (INC) — Direction générale, Camp de police | [x] | [x] | [ ] | [ ] | [ ] |
| Chambre de Commerce du Gabon — 12 avenue Augustin Boumah | [x] | [x] | [ ] | [ ] | [ ] |
| CPPF — Caisse des Pensions et des Prestations Familiales — 164 Impasse André Mba Obame | [x] | [x] | [ ] | [ ] | [ ] |
| CNTIPPEE — Commission Nationale des Travaux d’Intérêt Public pour la Promotion de l’Entreprenariat et de l’Emploi — 117 Impasse André Mba Obame | [x] | [x] | [ ] | [ ] | [ ] |
| eGabon — Service public numérique — Rue Antchouet Rabaguino / secteur Justice | [x] | [x] | [ ] | [ ] | [ ] |
| SEEG — Société d’Énergie et d’Eau du Gabon — 346 avenue Félix Éboué, siège social | [x] | [x] | [ ] | [ ] | [ ] |
| DGDI — Direction Générale de la Documentation et de l’Immigration — Oloumi | [x] | [x] | [ ] | [ ] | [ ] |
| Centre Technique de l’Habitat — avenue Barthélemy Boganda, Nzeng-Ayong | [x] | [x] | [ ] | [ ] | [ ] |
| Mairie de Nombakélé — 3e arrondissement | [x] | [x] | [ ] | [ ] | [ ] |
| Mairie de Nzeng-Ayong | [x] | [x] | [ ] | [ ] | [ ] |
| Mairie des Hauts de Gué-Gué | [x] | [x] | [ ] | [ ] | [ ] |
| Mairie du 2e arrondissement — avenue Jean-Paul II | [x] | [x] | [ ] | [ ] | [ ] |
| Mairie de Plaine Niger — 4e arrondissement | [x] | [x] | [ ] | [ ] | [ ] |
| Mairie de Sogatol — 5e arrondissement | [x] | [x] | [ ] | [ ] | [ ] |

**Précisions :** le repère du Tribunal correspond au site cartographié et ne localise pas séparément chacun des blocs annexes. Pour l'Immeuble du 2 Décembre, le GPS reste à confirmer ; seul le classement du repère est intégré.

## 4. Administrations en recherche — ne pas placer avant validation GPS

| Bâtiment / site | Informations connues | GPS exact dans la zone | Intégration |
|---|---|---|---|
| Ministère des Travaux publics et de la Construction | 392 avenue Rose Francine Rogombe (annexe) ; 414 avenue du Colonel Parant (principal) | [ ] | [ ] |
| Ministère de l’Agriculture | Immeuble de l’Ancienne Primature, avenue Cornut Gentille | [ ] | [ ] |
| Ministère de la Défense | Rue du Gouverneur Balley et autres implantations mentionnées | [ ] | [ ] |
| Ministère de l’Enseignement supérieur | Avenue de Cointet | [ ] | [ ] |
| ANBG — Agence Nationale des Bourses du Gabon | 195 rue Michel Nze MBA, Oloumi, anciens locaux du ministère de la Planification | [ ] | [ ] |
| PNPE — Pôle National de Promotion de l’Emploi | Siège / antenne Estuaire, 378 rue Jean-Baptiste Ndende, Petit-Paris | [ ] | [ ] |
| ANPI-Gabon — Agence Nationale de Promotion des Investissements | Immeuble Serena Mall, 104 rue Gustave Anguile | [ ] | [ ] |
| DPO — Direction des Publications Officielles / Journal Officiel | 400 avenue du Colonel Parant | [ ] | [ ] |
| Ministère du Travail | GPS confirmé : 0.42757 / 9.44887 ; OSM node 4686643890 | [x] | [x] |
| Mairie du 5e arrondissement — SOGATOL | OSM way 1348151040 ; GPS 0.37679 / 9.47356 ; Boulevard des Bantu | [x] | [x] |
| ANGTI — Agence Nationale des Grands Travaux d’Infrastructures | Immeuble BDM, boulevard de l’Indépendance | [ ] | [ ] |
| CDC — Centre des Dépôts et Consignations | Immeuble Orchidéa, 2e étage, rue Jean Ndende | [ ] | [ ] |
| CIPEP Sud — Centre des Impôts des Petites Entreprises et des Particuliers | Zone industrielle d’Oloumi, face à Gabon Méca | [ ] | [ ] |
| Direction Provinciale des Impôts de l’Estuaire | Zone industrielle d’Oloumi, face à Gabon Méca | [ ] | [ ] |
| DGE — Direction des Grandes Entreprises | Glass, feux tricolores, face à l’ancienne Pharmacie de Glass | [ ] | [ ] |
| CAISTAB — Direction Générale des Caisses de Stabilisation et de Péréquation | Immeuble Gabon 2000, Glass | [ ] | [ ] |
| ARSEE — Agence de Régulation du Secteur de l’Eau et de l’Énergie | Carrefour Boulingui, ruelle FOBERD, Oloumi | [ ] | [ ] |
| CEPIG — Centre de la Propriété Industrielle du Gabon | Immeuble Nostalgie, rue du Cabinet Berthonneau | [ ] | [ ] |
| CICIBA — Centre International des Civilisations Bantu | Cité-Damas, voie express, Carrefour Awendjé | [ ] | [ ] |
| CNAP — Centre National Anti-Pollution | Secteur STFO, Libreville ; adresse à préciser | [ ] | [ ] |
| ONPDF — Observatoire National de Protection des Droits de la Famille | Secteur Lycée d’État, avant l’échangeur | [ ] | [ ] |
| AGANOR — Agence Gabonaise de Normalisation | Immeuble Gabon Industriel, centre-ville | [ ] | [ ] |
| OGAPI — Office Gabonais de la Propriété Industrielle | Boulevard Omar Bongo / secteur CDPI, emplacement exact à vérifier | [ ] | [ ] |
| CNSS — Caisse Nationale de Sécurité Sociale | Avenue Georges Damas Aleka, Batavéa ; point OSM Libreville à confirmer | [ ] | [ ] |
| CNAMGS — Direction générale | Siège actuel à la Sablière ; hors de la zone de jeu | [ ] | [ ] |
| CNAMGS — Directions techniques | Annexe de Montagne Sainte ; coordonnées à vérifier | [ ] | [ ] |

Les sièges hors de la zone validée ne doivent pas être ajoutés comme bâtiments jouables dans cette zone.

- 2026-11-26 : vérification des adresses institutionnelles (sans ajout GPS) : le PNPE confirme son siège de Libreville rue Jean-Baptiste Ndende, BP 9610 ; l’ANBG confirme 195 rue Michel Nze MBA, Oloumi ; la CDC publie désormais l’Immeuble Casimir Marie Ange OYE MBA, 1633 boulevard Triomphal Omar Bongo Ondimba, alors qu’une ancienne publication indiquait l’Immeuble Orchida, rue Jean Nendé ; l’AGANOR affiche actuellement Charbonnages, Immeuble ABC, tandis que des sources antérieures la situaient à l’Immeuble Gabon Industriel ; l’ARSEE publie « Ancien SOBRAGA, en face de Multipress ». Ces changements/adresses contradictoires exigent un point cartographique précis et une vérification de l’implantation avant intégration. Sources : sites officiels PNPE (pnpe.ga/contact.html), ANBG (anbg-ga.com), CDC (cdc-gabon.ga/contact), AGANOR (aganor.ga), ARSEE (arsee-gabon.com).

- 2026-11-26 : ajout de la Chambre de Commerce du Gabon — OSM way 456350865, GPS 0.38419 / 9.44697, 12 avenue Augustin Boumah ; repère institutionnel uniquement, empreinte physique depuis buildings.geojson. Source cartographique : Mapcarta / OpenStreetMap.

- 2026-11-26 : ajout groupé de la CPPF — OSM node 12099801407, GPS 0.43855 / 9.41896, 164 Impasse André Mba Obame — et de la CNTIPPEE — OSM node 12099801403, GPS 0.44026 / 9.41887, 117 Impasse André Mba Obame ; repères institutionnels uniquement, volumes physiques issus de buildings.geojson. Sources cartographiques Mapcarta / OpenStreetMap.

- 2026-11-26 : ajout groupé d’eGabon — OSM way 636626338, GPS 0.38566 / 9.44786 — et du siège social de la SEEG — OSM way 456742208, GPS 0.39300 / 9.44671, 346 avenue Félix Éboué ; repères seulement, empreintes physiques issues de buildings.geojson. Sources Mapcarta / OpenStreetMap.

- 2026-11-26 : ajout groupé de la DGDI — OSM node 2910360231, GPS 0.38207 / 9.46700, secteur Oloumi — et du Centre Technique de l’Habitat — OSM node 11133203583, GPS 0.42044 / 9.48454, avenue Barthélemy Boganda, Nzeng-Ayong ; repères institutionnels uniquement, bâtiments physiques depuis buildings.geojson. Sources Mapcarta / OpenStreetMap.

- 2026-11-26 : ajout groupé de trois mairies d’arrondissement : Mairie de Nombakélé / 3e arrondissement — OSM way 1343319442, GPS 0.39109 / 9.45077 ; Mairie de Nzeng-Ayong — OSM way 1348678391, GPS 0.42399 / 9.47159 ; Mairie des Hauts de Gué-Gué — OSM node 4040655377, GPS 0.42802 / 9.43262. Repères uniquement, empreintes physiques depuis buildings.geojson. Sources Mapcarta / OpenStreetMap.

- 2026-11-26 : ajout de la Mairie du 2e arrondissement — OSM node 11458214434, GPS 0.40390 / 9.44285, avenue Jean-Paul II ; repère uniquement, bâtiment physique depuis buildings.geojson. Source Mapcarta / OpenStreetMap.

- 2026-11-26 : recherche documentaire complémentaire : ANBG (195 rue Michel Nze MBA, Oloumi), PNPE (378 rue Jean-Baptiste Ndende, Petit-Paris), ANPI-Gabon (Serena Mall, 104 rue Gustave Anguile) et DPO / Journal Officiel (400 avenue du Colonel Parant). Adresses confirmées par les sites institutionnels, mais points GPS cartographiques précis non validés : conservés dans la liste de recherche, non intégrés au jeu.

- 2026-11-26 : ajout de la Mairie de Plaine Niger — 4e arrondissement, OSM way 1346923818, GPS 0.37406 / 9.45930 ; point confirmé par Mapcarta/OSM, repère uniquement et empreinte physique issue de buildings.geojson.
- 2026-11-26 : ajout de la Mairie de Sogatol — 5e arrondissement, OSM way 1348151040, GPS 0.37679 / 9.47356, Boulevard des Bantu ; Mapcarta confirme l’appellation et la fonction de mairie. Repère institutionnel intégré, fallback sans empreinte propre ; le bâtiment physique doit provenir de buildings.geojson.
- 2026-11-26 : extension de l’inventaire en attente à partir des annuaires administratifs : ANGTI, CDC, CIPEP Sud, Direction provinciale des Impôts de l’Estuaire, DGE, CAISTAB, ARSEE, CEPIG, CICIBA, CNAP, ONPDF, AGANOR, OGAPI, CNSS et services multi-sites CNAMGS. Coordonnées GPS précises ou situation dans la zone encore à confirmer ; aucun de ces sites n’est intégré sans point vérifié. ANTT et ANAGEISC à Angondjé sont exclues du périmètre strict actuel.
- 2026-11-26 : contrôle des implantations CNAMGS : le siège social a été transféré à la Sablière en mai 2025, hors zone du jeu ; les directions techniques restent annoncées à Montagne Sainte et d’autres services à Glass / bas de Gué-Gué. Les anciens bureaux du front de mer ne doivent pas être présentés comme siège actuel.

## 5. Pipeline 3D pour chaque bâtiment

- [ ] Confirmer le point GPS et l'empreinte au sol.
- [ ] Identifier le bon bâtiment dans les données cartographiques.
- [ ] Collecter des photos fiables : façades, côtés, entrée et toiture.
- [ ] Relever les caractéristiques visibles : étages, ouvertures, couleurs et matériaux.
- [ ] Créer un modèle 3D optimisé pour Godot, aligné sur l'empreinte GPS.
- [ ] Intégrer des textures PBR adaptées : béton, peinture, verre, métal et toiture.
- [ ] Ajouter les détails distinctifs sans inventer de signes officiels.
- [ ] Vérifier échelle, orientation, collisions et apparence en jeu.
- [ ] Tester dans Godot et cocher seulement après contrôle réel.

## 6. Qualité et performances

- Priorité aux bâtiments administratifs emblématiques et visibles depuis les axes de circulation.
- Réutiliser les matériaux partagés lorsque c'est pertinent.
- Prévoir des niveaux de détail (LOD) et des collisions simples pour les modèles éloignés.
- Ne pas remplacer les empreintes réelles par des blocs génériques.
- Les photos servent à reproduire l'apparence ; elles ne prouvent pas les dimensions ou coordonnées.
- Ne jamais cocher « Modèle 3D », « Textures réalistes » ou « Contrôle Godot » avant réalisation effective.

## 7. Historique

- 2026-11-26 : création du document de suivi initial.
- 2026-11-26 : inventaire des administrations déjà repérées dans `facility_generator.gd`.
- 2026-11-26 : ajout du repère du Ministère de l’Éducation nationale — OSM way 410354024, GPS 0.39396 / 9.44551.
- 2026-11-26 : ajout du repère ANINF, Immeuble de la Solde — OSM way 455714440, GPS 0.39245 / 9.44510.
- 2026-11-26 : ajout du repère Direction Générale de la Comptabilité Publique et du Trésor — OSM way 455714429, GPS 0.39216 / 9.44461.
- 2026-11-26 : ajout du repère CIMA — OSM way 455714470, GPS 0.39040 / 9.44528 ; bâtiment physique toujours issu de buildings.geojson.
- 2026-11-26 : ajout du repère Palais présidentiel du Bord de mer — OSM way 168587922, GPS 0.39237 / 9.44235 ; bâtiment physique toujours issu de buildings.geojson.
- 2026-11-26 : ajout du Ministère du Travail et de la Formation professionnelle — OSM node 4686643890, GPS 0.42757 / 9.44887.
- 2026-11-26 : ajout du Ministère de la Planification et de la Prospective — OSM way 1243106067, GPS 0.42260 / 9.42566.
- 2026-11-26 : ajout de la CEEAC, Haut de Gué-Gué — OSM way 424241587, GPS 0.42858 / 9.43105.
- 2026-11-26 : ajout de l’ANUTTC à Oloumi — OSM way 806267454, GPS 0.38001 / 9.46208 ; empreinte physique conservée depuis buildings.geojson.
- 2026-11-26 : ajout du BRAC-OIF — OSM way 625614944, GPS 0.43037 / 9.42647 ; repère institutionnel, volume physique depuis buildings.geojson.
- 2026-11-26 : ajout de la DGTTC — OSM way 816220349, GPS 0.42335 / 9.42733 ; site distinct de l’ANUTTC d’Oloumi, repère institutionnel, empreinte physique depuis buildings.geojson.
- 2026-11-26 : ajout de la DGEL — OSM node 11421865904, GPS 0.41820 / 9.44920, 261 Rue Germain Mba, Ancien Sobraga ; repère institutionnel, volume physique depuis buildings.geojson.
- 2026-11-26 : ajout du CNEE — OSM node 12150167700, GPS 0.42836 / 9.43147, siège social à Haut de Gué-Gué ; repère institutionnel, bâtiment physique issu de buildings.geojson.
- 2026-11-26 : ajout du CND — OSM node 11529395192, GPS 0.41810 / 9.45075 ; repère institutionnel, volume physique depuis buildings.geojson.
- 2026-11-26 : ajout du Palais Léon Mba — Assemblée nationale, GPS converti depuis 0°24′44″N, 9°26′34″E (0.4122222 / 9.4427778) ; repère institutionnel, volume physique depuis buildings.geojson.
- 2026-11-26 : ajout de la Direction Générale des Douanes et Droits Indirects — OSM node 12727052424, GPS 0.37618 / 9.46677, 823 Avenue Edouard Ekomie Mba, Oloumi ; repère institutionnel, bâtiment physique depuis buildings.geojson.
- 2026-11-26 : ajout du repère de la Cour constitutionnelle du Gabon — OSM way 410343353, GPS 0.39687 / 9.43989, boulevard de l’Indépendance ; repère institutionnel, bâtiment physique depuis buildings.geojson.
- 2026-11-26 : ajout de l’Agence Gabonaise de Sécurité Alimentaire (AGASA), Batterie 4 — OSM node 12832789224, GPS 0.41896 / 9.42785 ; repère institutionnel, bâtiment physique depuis buildings.geojson.
- 2026-11-26 : ajout de la Direction générale de l’Institut National de Cartographie (INC), Camp de police — OSM way 793967943, GPS 0.40102 / 9.44126 ; l’adresse du siège technique à Batterie IV est une implantation distincte et n’est pas ajoutée dans cette entrée.
- 2026-11-26 : poursuite de la vérification des Travaux publics ; l’adresse officielle est confirmée mais le point GPS précis du bâtiment reste à identifier.
- Prochaine étape : vérifier les coordonnées des Travaux publics, puis démarrer le premier modèle 3D détaillé dès que les références visuelles et l'empreinte sont fiables.
