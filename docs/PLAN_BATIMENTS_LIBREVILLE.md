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
| Ministère du Pétrole — boulevard Triomphal (OSM node 11505339840, 0.40778 / 9.44131) | [x] | [x] | [ ] | [ ] | [ ] |
| Ministère de l’Économie et des Finances — Immeuble Arambo (OSM node 11505197345, 0.40803 / 9.43928 ; bâtiment partagé avec d’autres services) | [x] | [x] | [ ] | [ ] | [ ] |
| Ministère de l’Intérieur — avenue de Cointet | [x] | [x] | [ ] | [ ] | [ ] |
| Ministère de l’Éducation nationale — Formation civique | [x] | [x] | [ ] | [ ] | [ ] |
| Agence nationale des infrastructures numériques et des fréquences (ANINF) — Immeuble de la Solde | [x] | [x] | [ ] | [ ] | [ ] |
| Direction Générale de la Comptabilité Publique et du Trésor (DGCPT) — 321 avenue Rose Francine Rogombe | [x] | [x] | [ ] | [ ] | [ ] |
| Conférence Interafricaine des Marchés d’Assurances (CIMA) — centre-ville | [x] | [x] | [ ] | [ ] | [ ] |
| Palais présidentiel du Bord de mer — boulevard de l’Indépendance | [x] | [x] | [ ] | [ ] | [ ] |
| Agence Nationale des Parcs Nationaux (ANPN) — Rue Bana Ba Kengue | [x] | [x] | [ ] | [ ] | [ ] |
| AGATOUR — Agence Gabonaise de Développement et de Promotion du Tourisme — Impasse Père Peterse, Batterie IV | [x] | [x] | [ ] | [ ] | [ ] |
| Ministère des Transports, de la Marine marchande et de la Logistique — Immeuble Arambo | [x] | [x] | [ ] | [ ] | [ ] |
| ANPI-Gabon — Agence Nationale de Promotion des Investissements, Serena Mall | [x] | [x] | [ ] | [ ] | [ ] |
| Direction Nationale des Assurances — Rond-Point de la Démocratie | [x] | [x] | [ ] | [ ] | [ ] |
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
| Maison Georges Rawiri — Radio-Gabon / Gabon Télévision (RTG) — Boulevard Triomphal | [x] | [x] | [ ] | [ ] | [ ] |
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
| Mairie de Plaine Niger — 4e arrondissement | [x] | [x] | [ ] | [ ] | [ ] |
| Mairie de Sogatol — 5e arrondissement | [x] | [x] | [ ] | [ ] | [ ] |

**Précisions :** le repère du Tribunal correspond au site cartographié et ne localise pas séparément chacun des blocs annexes. Pour l'Immeuble du 2 Décembre, le GPS reste à confirmer ; seul le classement du repère est intégré. La Mairie de Nzeng-Ayong est également identifiée par Mapcarta comme la Mairie du 6e arrondissement. Le point OSM précédemment utilisé pour la Mairie du 2e arrondissement (avenue Jean-Paul II) est obsolète : la mairie a été délocalisée en 2024 dans un immeuble derrière le ministère des Eaux et Forêts ; le nouveau bâtiment n'a pas encore de GPS validé. L'Hôtel de Ville central est annoncé boulevard Omar Bongo Ondimba, mais son annuaire ne donne qu'un plus code CC6V+6Q2, insuffisant pour intégrer un GPS exact.

## 3 bis. Pôle CHU — bâtiments et équipements voisins identifiés

| Site | Référence OSM | GPS | Statut dans le projet |
|---|---|---|---|
| Centre Hospitalier Universitaire de Libreville (CHUL) | way 410356077 | 0.39200, 9.44797 | [x] point cartographique vérifié ; [ ] repère de jeu ; [ ] modèle 3D dédié |
| Agence SEEG-Centrale — 268 avenue Félix Éboué | way 456784178 | 0.39215, 9.44662 | [x] bâtiment OSM vérifié ; [ ] repère de jeu dédié |
| Institut National de Formation d’Action Sanitaire et Sociale (INFASS) — 339 rue Fall Ndiaye Azizet | node 12429309200 | 0.39321, 9.44818 | [x] point OSM vérifié ; [ ] repère de jeu |
| Mémorial du Président Léon Mba — 151 avenue Félix Éboué | way 455714475 | 0.39106, 9.44574 | [x] bâtiment OSM vérifié ; [ ] repère de jeu |
| État-major régional CEEAC — secteur CHUL | way 424247169 | 0.39397, 9.44731 | [x] point cartographique vérifié ; [x] repère marker-only ajouté au générateur ; [ ] modèle 3D dédié |
| Commissariat du Littoral — avenue Docteur Albert Schweitzer | way 250792764 | 0.38963, 9.44691 | [x] bâtiment OSM vérifié ; [x] repère marker-only ajouté au générateur ; [ ] modèle 3D dédié |

**Lecture du secteur :** l'Agence SEEG-Centrale (268 avenue Félix Éboué) et le siège social de la SEEG (346 avenue Félix Éboué, déjà suivi séparément) sont deux sites différents. Le CHUL est un complexe hospitalier, tandis que l'INFASS est un établissement de formation situé à environ 140 m au nord du CHUL. L'État-major régional CEEAC et le ministère de l'Intérieur sont également signalés à proximité, mais leurs empreintes et points propres doivent être vérifiés avant d'ajouter de nouveaux marqueurs. Ne pas confondre le ministère de l'Intérieur situé près du CHUL avec le point précédemment intégré avenue de Cointet sans contrôle de l'identité du bâtiment.

## 4. Administrations en recherche — ne pas placer avant validation GPS

| Bâtiment / site | Informations connues | GPS exact dans la zone | Intégration |
|---|---|---|---|
| Mairie du 1er arrondissement de Libreville — secteur Hauts de Gué-Gué | Annuaire cartographique : plus code CCHM+562 ; correspondance avec le secteur à vérifier et bâtiment exact à identifier | [ ] | [ ] |
| Mairie du 2e arrondissement — siège provisoire derrière le ministère des Eaux et Forêts | Nouvelle adresse annoncée en mai 2024 ; bâtiment exact à identifier | [ ] | [ ] |
| Hôtel de Ville central de Libreville — boulevard Omar Bongo Ondimba | Adresse d’annuaire ; point GPS propre au site central à confirmer (ne pas utiliser l’Hôtel de Ville d’Akanda) | [ ] | [ ] |
| Ministère des Travaux publics et de la Construction | 392 avenue Rose Francine Rogombe (annexe) ; 414 avenue du Colonel Parant (principal) | [ ] | [ ] |
| Ministère de l’Agriculture, de l’Élevage et du Développement rural | Contact officiel : Centre-ville, face à Rénovation, BP 551 ; ancienne adresse Ancienne Primature à ne plus considérer comme confirmée | [ ] | [ ] |
| Ministère de la Défense | Siège rue du Gouverneur Balley ; annuaires le placent aussi à côté / face à la Présidence ; secrétariat général dans la Cité administrative présidentielle ; points GPS propres à chaque bâtiment à identifier | [ ] | [ ] |
| Ministère de l’Enseignement supérieur | Avenue de Cointet | [ ] | [ ] |
| ANBG — Agence Nationale des Bourses du Gabon | 195 rue Michel Nze MBA, Oloumi, anciens locaux du ministère de la Planification | [ ] | [ ] |
| PNPE — Pôle National de Promotion de l’Emploi | Siège / antenne Estuaire, 378 rue Jean-Baptiste Ndende, Petit-Paris | [ ] | [ ] |
| DPO — Direction des Publications Officielles / Journal Officiel | 400 avenue du Colonel Parant | [ ] | [ ] |
| ANGTI — Agence Nationale des Grands Travaux d’Infrastructures | Immeuble BDM, boulevard de l’Indépendance | [ ] | [ ] |
| CDC — Caisse des Dépôts et Consignations | Siège actuel inauguré en février 2026 : Immeuble Casimir Marie Ange OYE MBA, 1633 boulevard Triomphal Omar Bongo Ondimba | [ ] | [ ] |
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
| CNAMGS — Directions techniques | Annexe de Montagne Sainte ; coordonnées à vérifier | [ ] | [ ] |
| SCG-Ré — Société Commerciale Gabonaise de Réassurance | 2080 boulevard de l’Indépendance, Immeuble du Bord de Mer ; GPS exact du bâtiment à valider | [ ] | [ ] |
| Primature — Immeuble du 2 Décembre | Avenue Jean-Paul II ; adresse officielle confirmée ; GPS/empreinte du bâtiment à identifier précisément | [ ] | [ ] |
| Tour ANINF — siège de l’Agence Nationale des Infrastructures Numériques et des Fréquences | Boulevard Triomphal Omar Bongo, quartier Louis ; adresse officielle confirmée ; point OSM exact de la tour à valider | [ ] | [ ] |

Les sièges hors de la zone validée ne doivent pas être ajoutés comme bâtiments jouables dans cette zone.

### Exclusions et doublons confirmés

- Hôtel de Ville cartographié OSM node 13279033156 : 0.49508 / 9.39345, à Akanda, hors limite nord (0.445) et hors commune de Libreville ; ne pas l’utiliser pour l’Hôtel de Ville central de Libreville. L’Hôtel de Ville central boulevard Omar Bongo reste à localiser séparément.
- Siège de la CNAMGS à la Sablière : hors zone ; exclu. Les directions techniques à Montagne Sainte restent à vérifier, sans point exact.
- OPRAG : point Mapcarta 0.28952 / 9.50403, hors limites sud et est ; exclu.
- EPCA et École Nationale d’Administration, PK11 : longitudes 9.51786 et 9.51855, hors limite est 9.495 ; exclues.
- Ministère du Travail et mairie de Sogatol : déjà présents dans la section 3 et dans le générateur ; retirés des lignes de recherche pour éviter les doublons.
- Les directions DGIT, DGCE, DGERA, DGEI et directions supports du Ministère des Travaux publics sont annoncées au même immeuble principal, 414 avenue du Colonel Parant. Elles ne doivent pas devenir autant de bâtiments distincts.
- Le point OSM node 6703527385 est libellé ANPI à 0.38766 / 9.44761 et se situe dans le secteur de Nombakélé ; le siège officiel est annoncé à Serena Mall, 104 rue Gustave Anguile. Le point est maintenant intégré comme repère ANPI sur la base de son libellé OSM et de la concordance du secteur, mais la correspondance exacte du bâtiment doit encore être contrôlée visuellement.

- 2026-11-26 : ajout du pôle CHUL : État-major régional CEEAC (way 424247169, 0.39397 / 9.44731) et Commissariat du Littoral (way 250792764, 0.38963 / 9.44691). Les deux repères sont intégrés dans `facility_generator.gd` avec empreinte nulle afin de laisser la géométrie physique à `buildings.geojson`. Le siège CEEAC du Haut de Gué-Gué reste un site distinct. Sources cartographiques : Mapcarta / OpenStreetMap.
- 2026-11-26 : vérification des adresses institutionnelles (sans ajout GPS) : le PNPE confirme son siège de Libreville rue Jean-Baptiste Ndende, BP 9610 ; l’ANBG confirme 195 rue Michel Nze MBA, Oloumi ; la CDC publie désormais l’Immeuble Casimir Marie Ange OYE MBA, 1633 boulevard Triomphal Omar Bongo Ondimba, alors qu’une ancienne publication indiquait l’Immeuble Orchida, rue Jean Nendé ; l’AGANOR affiche actuellement Charbonnages, Immeuble ABC, tandis que des sources antérieures la situaient à l’Immeuble Gabon Industriel ; l’ARSEE publie « Ancien SOBRAGA, en face de Multipress ». Ces changements/adresses contradictoires exigent un point cartographique précis et une vérification de l’implantation avant intégration. Sources : sites officiels PNPE (pnpe.ga/contact.html), ANBG (anbg-ga.com), CDC (cdc-gabon.ga/contact), AGANOR (aganor.ga), ARSEE (arsee-gabon.com).

- 2026-11-26 : ajout de la Chambre de Commerce du Gabon — OSM way 456350865, GPS 0.38419 / 9.44697, 12 avenue Augustin Boumah ; repère institutionnel uniquement, empreinte physique depuis buildings.geojson. Source cartographique : Mapcarta / OpenStreetMap.

- 2026-11-26 : ajout groupé de la CPPF — OSM node 12099801407, GPS 0.43855 / 9.41896, 164 Impasse André Mba Obame — et de la CNTIPPEE — OSM node 12099801403, GPS 0.44026 / 9.41887, 117 Impasse André Mba Obame ; repères institutionnels uniquement, volumes physiques issus de buildings.geojson. Sources cartographiques Mapcarta / OpenStreetMap.

- 2026-11-26 : ajout groupé d’eGabon — OSM way 636626338, GPS 0.38566 / 9.44786 — et du siège social de la SEEG — OSM way 456742208, GPS 0.39300 / 9.44671, 346 avenue Félix Éboué ; repères seulement, empreintes physiques issues de buildings.geojson. Sources Mapcarta / OpenStreetMap.

- 2026-11-26 : ajout groupé de la DGDI — OSM node 2910360231, GPS 0.38207 / 9.46700, secteur Oloumi — et du Centre Technique de l’Habitat — OSM node 11133203583, GPS 0.42044 / 9.48454, avenue Barthélemy Boganda, Nzeng-Ayong ; repères institutionnels uniquement, bâtiments physiques depuis buildings.geojson. Sources Mapcarta / OpenStreetMap.

- 2026-11-26 : ajout groupé de trois mairies d’arrondissement : Mairie de Nombakélé / 3e arrondissement — OSM way 1343319442, GPS 0.39109 / 9.45077 ; Mairie de Nzeng-Ayong — OSM way 1348678391, GPS 0.42399 / 9.47159 ; Mairie des Hauts de Gué-Gué — OSM node 4040655377, GPS 0.42802 / 9.43262. Repères uniquement, empreintes physiques depuis buildings.geojson. Sources Mapcarta / OpenStreetMap.

- 2026-11-26 : ajout de la Mairie du 2e arrondissement — OSM node 11458214434, GPS 0.40390 / 9.44285, avenue Jean-Paul II ; repère uniquement, bâtiment physique depuis buildings.geojson. Source Mapcarta / OpenStreetMap.

- 2026-11-26 : recherche documentaire complémentaire : ANBG (195 rue Michel Nze MBA, Oloumi), PNPE (378 rue Jean-Baptiste Ndende, Petit-Paris), ANPI-Gabon (Serena Mall, 104 rue Gustave Anguile) et DPO / Journal Officiel (400 avenue du Colonel Parant). Adresses confirmées par les sites institutionnels ; ANBG et DPO restent sans point GPS propre validé. L’ANPI a depuis été intégrée sur la base du node OSM 6703527385, dont la correspondance exacte avec Serena Mall reste à contrôler.

- 2026-11-26 : ajout de la Mairie de Plaine Niger — 4e arrondissement, OSM way 1346923818, GPS 0.37406 / 9.45930 ; point confirmé par Mapcarta/OSM, repère uniquement et empreinte physique issue de buildings.geojson.
- 2026-11-26 : ajout de la Mairie de Sogatol — 5e arrondissement, OSM way 1348151040, GPS 0.37679 / 9.47356, Boulevard des Bantu ; Mapcarta confirme l’appellation et la fonction de mairie. Repère institutionnel intégré, fallback sans empreinte propre ; le bâtiment physique doit provenir de buildings.geojson.
- 2026-11-26 : extension de l’inventaire en attente à partir des annuaires administratifs : ANGTI, CDC, CIPEP Sud, Direction provinciale des Impôts de l’Estuaire, DGE, CAISTAB, ARSEE, CEPIG, CICIBA, CNAP, ONPDF, AGANOR, OGAPI, CNSS et services multi-sites CNAMGS. Coordonnées GPS précises ou situation dans la zone encore à confirmer ; aucun de ces sites n’est intégré sans point vérifié. ANTT et ANAGEISC à Angondjé sont exclues du périmètre strict actuel.
- 2026-11-26 : précision CDC : l’adresse officielle actuelle est l’Immeuble Casimir Marie Ange OYE MBA, 1633 boulevard Triomphal Omar Bongo Ondimba ; le nouveau siège a été inauguré le 17 février 2026. Les anciennes adresses Immeuble Orchidéa / Phoenix, rue Jean Ndende ou 70 rue Simon Kalife sont historiques et ne doivent pas servir de repère pour le siège actuel. La localisation GPS du nouvel immeuble reste à confirmer. Sources : CDC officielle (cdc-gabon.ga/contact), communication gouvernementale du 18 février 2026 et GabonReview.
- 2026-11-26 : contrôle ANPI : le node OSM 6703527385 (0.38766 / 9.44761) existe près de Nombakélé, mais le site officiel situe le siège actuel à l’Immeuble Serena Mall, 104 rue Gustave Anguile. Le node OSM n’est donc pas utilisé comme point du siège sans preuve qu’il représente bien l’implantation actuelle. Serena Mall reste à géolocaliser précisément.
- 2026-11-26 : contrôle des implantations CNAMGS : le siège social a été transféré à la Sablière en mai 2025, hors zone du jeu ; les directions techniques restent annoncées à Montagne Sainte et d’autres services à Glass / bas de Gué-Gué. Les anciens bureaux du front de mer ne doivent pas être présentés comme siège actuel.


- 2026-11-26 : nouvelle passe de recoupement des administrations : l’ANBG confirme toujours son adresse au 195 rue Michel Nze MBA, Oloumi ; le point de recherche d’annuaire ne fournit pas de coordonnées GPS propres au bâtiment, donc aucun repère supplémentaire n’est ajouté. La DPO / Journal Officiel est confirmée au 400 avenue du Colonel Parant par sa fiche institutionnelle et par l’annuaire cartographique, mais le plus code cartographique 9CPW+FQF ne suffit pas à établir le point OSM exact du bâtiment. L’Hôtel de Ville central est bien référencé boulevard Triomphal / CC6V+6Q2, mais ce plus code n’est pas converti en point GPS de bâtiment sans vérification OSM ; la mairie du 1er arrondissement apparaît également dans les annuaires avec le plus code CCHM+562, sans identifiant OSM ni coordonnées validées. La CDC possède une fiche cartographique qui la place à l’Université Omar Bongo, en contradiction avec l’adresse officielle du nouveau siège au 1633 boulevard Triomphal : cette fiche est considérée comme probablement ancienne ou mal géolocalisée et n’est pas utilisée. Enfin, le site officiel du Trésor publie désormais « Centre-ville, rue Alfred Marche » pour la DGCPT, tandis que le repère intégré précédemment est associé à une autre adresse ; ce décalage est à auditer avant toute correction du point existant. Les directions DGCE, DGIT, DGERA, DGEI, DCRH et DMC du ministère des Travaux publics confirment toutes le même immeuble principal au 414 avenue du Colonel Parant : elles restent un seul bâtiment physique dans le jeu. Sources : ANBG (anbg-ga.com), Journal Officiel (journal-officiel.ga), mairie de Libreville (sygmagabon.com), annuaire cartographique Gabonews, Trésor public (tresorpublic.ga), ministère des Travaux publics (infrastructures.gouv.ga).

- 2026-11-26 : vérification ciblée du secteur Présidence–boulevard Triomphal–CHU. Les adresses de la Présidence (boulevard de la Nation), de la Cour constitutionnelle (boulevard de la Nation, BP 4025), du Sénat (Palais Omar Bongo, boulevard Triomphal), de l’Assemblée nationale (Palais Léon Mba, boulevard Triomphal Omar Bongo), du ministère de la Défense (à côté de la Présidence), du ministère des Eaux et Forêts (immeuble face au Sénat) et de la Direction générale du Budget (avenue Félix Éboué, face CHUL) sont recoupées. La Maison Georges Rawiri, qui abrite Radio-Gabon et Gabon Télévision, est localisée sur le boulevard Triomphal à proximité du Sénat et de l’Assemblée nationale ; coordonnées publiées 00°24′37″N, 09°26′28″E, converties en 0.4102778 / 9.4411111. Un repère marker-only est ajouté au générateur ; le bâtiment physique reste issu de buildings.geojson. La SCG-Ré publie l’adresse 2080 boulevard de l’Indépendance, Immeuble du Bord de Mer ; point GPS individuel à confirmer avant intégration. Attention : les adresses seules ne prouvent pas le bâtiment exact et aucun modèle 3D ni texture spécifique n’est encore créé pour cette série. Sources : Le Pratique du Gabon / Entrepro-Gabon (institutions), sites officiels du Sénat et de l’Assemblée nationale, World Radio Map (coordonnées Maison Georges Rawiri), rapport annuel SCG-Ré 2022.

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

- 2026-11-26 : ANPI-Gabon est sortie de la liste des recherches en attente après intégration du node OSM 6703527385. Le compteur des lignes ouvertes est recalculé après retrait des doublons déjà intégrés et des sites hors périmètre.

- 2026-11-26 : intégration du repère ANPI-Gabon à partir du node OSM 6703527385, GPS 0.38766 / 9.44761. Mapcarta identifie explicitement ce point comme ANPI ; le siège officiel actuel est publié à Serena Mall, 104 rue Gustave Anguile. Repère ajouté au générateur avec anti-doublon par OSM ID/nom et fallback sans empreinte propre. La correspondance exacte entre le point cartographique et le bâtiment Serena Mall reste à vérifier par comparaison visuelle / terrain avant modélisation 3D. Sources : Mapcarta/OSM (ANPI node 6703527385), investingabon.ga/contact.

- 2026-11-26 : recherche complémentaire sur les sièges encore en attente. Le ministère de l’Agriculture publie désormais comme adresse de contact « Centre-ville (face Rénovation), BP 551 » ; l’adresse historique Ancienne Primature / Cornut Gentille n’est plus confirmée sur sa page de contact. Le ministère des Travaux publics distingue une annexe au 392 avenue Rose Francine Rogombe et un immeuble principal au 414 avenue du Colonel Parant ; ses directions générales infrastructures, construction, entretien des routes et études sont rattachées au même immeuble principal et ne doivent pas être comptées comme des bâtiments séparés. Le ministère de l’Enseignement supérieur confirme l’avenue de Cointet et fournit un lien OSM, mais le lien ouvre une carte embarquée centrée sur le secteur et non un point précis du bâtiment. La Défense confirme rue du Gouverneur Balley, sans GPS exact. La DPO confirme 400 avenue du Colonel Parant ; les données Mapcarta la situent dans le secteur Rue Pecqueur / eGabon / Pharmacie La Librevilloise, mais sans identifiant OSM propre ni coordonnées précises exploitables. Le PNPE confirme rue Jean-Baptiste Ndende ; Mapcarta le signale comme immeuble de bureaux proche de Nombakélé, sans point individuel publié. L’ANBG confirme 195 rue Michel Nze MBA, Oloumi ; aucun point exact du bâtiment actuel validé. Le CNAP est confirmé au Carrefour STFO ; coordonnées trouvées pour le carrefour (0.4071296 / 9.4571099) et pour le secteur STFO (0.40747 / 9.458), mais ce ne sont pas les coordonnées du bâtiment CNAP et ne sont pas utilisées comme telles. L’AGANOR confirme Charbonnages, Immeuble ABC ; aucune géolocalisation OSM exacte de l’immeuble n’a été vérifiée. Sources : sites officiels des ministères (agriculture.gouv.ga/contact, infrastructures.gouv.ga/contact, enseignement-superieur.gouv.ga/contacts, defense-nationale.gouv.ga/contact.twg), journal-officiel.ga/contact, pnpe.ga/contact.html, anbg-ga.com/contacts, eaux-forets.gouv.ga/organismes-sous-tutelles, aganor.ga, Mapcarta/OSM.

- 2026-11-26 : recherche générale complémentaire sur les administrations et mairies. La mairie officielle de Libreville confirme six arrondissements ; la mairie de Nzeng-Ayong est le point cartographié du 6e arrondissement et les cinq autres points déjà présents couvrent les 1er, 3e, 4e et 5e arrondissements (les mairies de Nombakélé, Hauts de Gué-Gué, Plaine Niger et Sogatol). La mairie du 2e a changé d’adresse : les articles de 2024 signalent un siège provisoire derrière le ministère des Eaux et Forêts ; le point OSM avenue Jean-Paul II a été retiré du générateur, faute de géolocalisation du nouveau siège. L’Hôtel de Ville central est donné boulevard Omar Bongo Ondimba par les annuaires, mais le plus code seul ne permet pas de valider le GPS. La CNSS confirme son siège avenue Georges Damas Aleka, Batavéa ; le point OSM CNSS Akanda est hors périmètre et ne doit pas être utilisé. Autres adresses confirmées sans GPS précis : ANGTI (Immeuble BDM, boulevard de l’Indépendance), CEPIG (Immeuble Nostalgie, rue du Cabinet Berthonneau), CIPEP Sud et Direction provinciale des Impôts de l’Estuaire (zone industrielle d’Oloumi face à Gabon Méca), DGE (feux tricolores de Glass), CAISTAB (Immeuble Gabon 2000, Glass), ARSEE (Ancien Sobraga, face à Multipress), CICIBA (voie express avant échangeur Awendjé). Le site officiel DGI publie une carte des centres fiscaux mais aucun GPS exploitable n’a été extrait ici. Aucun de ces sites n’est ajouté au jeu sans point exact dans les limites. Sources : mairie de Libreville (libreville.ga), Gabon Media Time, Le Pratique du Gabon, CNSS (cnss.ga), DGI (dgi.ga/maps), Go Africa Online, site officiel ARSEE.

- 2026-11-26 : audit des mairies : confirmation que les six arrondissements de Libreville sont couverts dans l’inventaire, mais le repère de la Mairie du 2e arrondissement (OSM node 11458214434, avenue Jean-Paul II) est ancien. Des articles de mai et octobre 2024 confirment le déplacement du siège provisoire dans un immeuble derrière le ministère des Eaux et Forêts ; aucun point GPS précis du nouvel immeuble n’a été validé. Le repère obsolète a donc été retiré du générateur. La Mairie de Nzeng-Ayong correspond aussi à la Mairie du 6e arrondissement. L’Hôtel de Ville central est listé boulevard Omar Bongo Ondimba, mais seule une adresse/plus code CC6V+6Q2 est disponible, sans GPS OSM vérifié. Sources : mairie de Libreville (libreville.ga), annuaire Le Pratique du Gabon, Mapcarta/OSM, Gabon Media Time (28 mai et 9 octobre 2024).

- 2026-11-26 : ajout du Ministère des Transports, de la Marine marchande et de la Logistique, siège officiel au 3e étage de l’Immeuble Arambo (site ministériel). Coordonnées utilisées : centroïde OSM du bâtiment public Arambo, way 249526244, GPS 0.40802 / 9.43928. Repère marker-only, aucune empreinte physique ajoutée ; le bâtiment est déjà représenté par les données bâtiments OSM. Sources : ministère des Transports (transports.gouv.ga/contact), Mapcarta/OSM (Immeuble Arambo).
- 2026-11-26 : contrôles de périmètre : l’OPRAG repéré à 0.28952 / 9.50403 est hors limites sud et est ; l’EPCA (0.40181 / 9.51786) et l’École Nationale d’Administration (0.40191 / 9.51855) sont hors limite est 9.495. La DGCC est annoncée à l’Immeuble des Domaines mais sans point GPS OSM précis validé ; la DGPE est annoncée à Akémigjogoni sans coordonnées vérifiées. Ces structures restent en attente ou exclues, sans coordonnées inventées. Sources : Mapcarta/OSM, site ministériel transports.gouv.ga, annuaires publics DGCC/DGPE.

- 2026-11-26 : ajout de l’Agence Nationale des Parcs Nationaux (ANPN), OSM node 12149539808, GPS 0.42843 / 9.42760, Rue Bana Ba Kengue ; siège indiqué par Mapcarta/OSM et adresse corroborée par l’annuaire Go Africa. Repère institutionnel sans empreinte propre, volume physique depuis buildings.geojson.
- 2026-11-26 : ajout d’AGATOUR, Agence Gabonaise de Développement et de Promotion du Tourisme et de l’Hôtellerie, OSM node 12317977790, GPS 0.41896 / 9.42793, Impasse Père Peterse, Batterie IV. Ce point correspond au bureau gouvernemental de l’agence et non au point d’information touristique distinct situé avenue du Colonel Parant. Repère sans empreinte propre, volume physique depuis buildings.geojson.

- 2026-11-26 : ajout de la Direction Nationale des Assurances — OSM node 6144764686, GPS 0.42738 / 9.44884, Rond-Point de la Démocratie ; point Mapcarta/OSM vérifié et situé dans l’emprise stricte. Repère institutionnel seul, sans empreinte propre ; bâtiment physique depuis buildings.geojson. Source : Mapcarta / OpenStreetMap.

- 2026-11-26 : contrôle complémentaire des implantations : CAISTAB est confirmée à l’Immeuble Gabon 2000, quartier Glass (Go Africa, Filao et site CAISTAB) ; la DGE est indiquée aux feux tricolores de Glass, face à la Pharmacie de Glass (Go Africa) ; le CEPIG est indiqué à l’Immeuble Nostalgie, rue du Cabinet Berthonneau (Go Africa) ; le CICIBA est signalé à Cité-Damas, voie express avant la montée du carrefour Awendjé (Go Africa, annuaire du ministère des Affaires étrangères) ; l’ONPDF est localisé dans le secteur du Lycée d’État, avant l’échangeur (Filao et annuaire diplomatique). Ces adresses sont des repères textuels, pas des coordonnées GPS : aucune entrée n’est ajoutée au générateur tant qu’un point OSM exact dans l’emprise 0.355–0.445 / 9.400–9.495 n’est pas vérifié. Sources : Go Africa (CAISTAB, DGE, CEPIG, CICIBA), Filao (ONPDF), ministère des Affaires étrangères (CICIBA).

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


- 2026-11-26 : extension de la zone du boulevard Triomphal : ajout du Ministère du Pétrole — OSM node 11505339840, GPS 0.40778 / 9.44131 — et du Ministère de l’Économie et des Finances — OSM node 11505197345, GPS 0.40803 / 9.43928, dans l’Immeuble Arambo. Pour les Finances, le point est un repère institutionnel dans un bâtiment déjà cartographié ; aucune seconde géométrie physique n’est créée. Sources cartographiques : Mapcarta / OpenStreetMap ; adresses du secteur recoupées avec les annuaires institutionnels.

- 2026-11-26 : complément ciblé Présidence–Primature–boulevard Triomphal : adresse actuelle de la Primature confirmée à l’Immeuble du 2 Décembre, avenue Jean-Paul II (site officiel primature.gouv.ga/nous-contacter et avis APDPVP 2024). La Tour ANINF est confirmée au boulevard Triomphal Omar Bongo (site officiel aninf.ga/contact et ministère de l’Économie numérique) ; le point OSM exact du bâtiment doit encore être extrait, donc aucun GPS n’est ajouté. Le ministère de la Défense possède plusieurs implantations : siège rue du Gouverneur Balley, secrétariat général dans la Cité administrative de la Présidence, Garde républicaine dans l’enceinte présidentielle, états-majors et unités à d’autres adresses ; ne pas fusionner toutes ces implantations en un seul bâtiment. Sources : Primature, APDPVP, ANINF, ministère de la Défense, Go Africa Online.

- 2026-11-26 : cartographie détaillée du pôle CHUL / avenue Félix Éboué. Validation des références OSM : CHUL way 410356077 (0.39200, 9.44797) ; Agence SEEG-Centrale way 456784178 (0.39215, 9.44662), 268 avenue Félix Éboué ; INFASS node 12429309200 (0.39321, 9.44818), 339 rue Fall Ndiaye Azizet ; Mémorial du Président Léon Mba way 455714475 (0.39106, 9.44574), 151 avenue Félix Éboué. Les coordonnées sont celles des objets cartographiques, pas des points d'entrée. Distinction maintenue avec le siège social SEEG, way 456742208, 346 avenue Félix Éboué (0.39300, 9.44671), déjà suivi. Aucune nouvelle géométrie 3D ni texture créée dans cette passe. Sources Mapcarta / OpenStreetMap.
