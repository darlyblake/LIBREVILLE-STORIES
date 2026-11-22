# Liste de contrôle — finalisation de la carte de Libreville

Cette liste suit uniquement les éléments vérifiés dans le dépôt et les validations CI. Une case cochée signifie que le travail existe dans le projet ; elle ne signifie pas automatiquement que le rendu a été inspecté sur le PC cible.

## 1. Base cartographique et identification
- [x] Emprise de travail définie autour de Libreville (boîte technique provisoire, pas une frontière administrative).
- [x] Extraction OpenStreetMap organisée en 16 secteurs avec cache et solution de repli Geofabrik ; 16/16 secteurs extraits et validés (4 503 routes, 49 359 bâtiments, 2 595 POI, 256 éléments environnementaux, 73 localités nommées).
- [x] Routes et empreintes de bâtiments OSM intégrées au prototype.
- [x] POI nommés et couches environnementales intégrés.
- [x] Couche séparée des localités OSM nommées (place=*) et affichage des étiquettes.
- [x] HUD de position du joueur : coordonnées et localité OSM la plus proche.
- [x] Extraction complète des 16 secteurs vérifiée et publiée sur `main` (workflow n°44149287481, 17/11/2026).
- [x] Comptes vérifiés : 4 503 routes, 49 359 bâtiments, 2 595 POI, 256 éléments environnementaux et 73 localités nommées ; 0 polygone de quartier fourni par OSM dans cette extraction.
- [x] Abaisser les étiquettes 3D près du sol : localités à 0,65 m, noms de routes et POI à 0,55 m ; inspection visuelle en jeu encore requise.
- [ ] Vérifier visuellement les noms et leur placement dans la carte en jeu.
- [ ] Compléter les limites des quartiers avec une source administrative officielle ou vérifiable ; ne pas déduire de frontières depuis les points place=*.

## 2. Bâtiments et architecture
- [x] Volumes 3D extrudés à partir des empreintes OSM.
- [x] Hauteurs OSM utilisées lorsqu'elles sont disponibles ; lecture des valeurs en mètres, centimètres et pieds, estimation visuelle clairement utilisée en leur absence.
- [x] Première texture procédurale de tuiles sur les toitures.
- [x] Détails de façades regroupés en meshes : fenêtres et portes d'entrée stylisées, avec variation déterministe légère.
- [x] Validation Godot 4.3 du générateur de fenêtres/portes sur `main` (rendu Compatibility réussi).
- [x] Validation Godot 4.3 après ajout des balcons (PR n°13, rendu Compatibility réussi).
- [ ] Inspecter leur rendu en jeu sur la machine cible.
- [x] Corriger le bug de double-hauteur des balcons (ils flottaient au-dessus des toits) + ancrage plus serré des fenêtres/portes + plinthe de base pour éviter l'aspect flottant au sol.
- [x] Première variété de matériaux procéduraux : tuiles, tôle nervurée et dalle béton, sélectionnés par typologie OSM (approximation visuelle).
- [x] Exploiter `building:material` pour nuancer la teinte des façades (brique, bois, béton, métal, pierre, verre, enduit) quand aucune couleur explicite OSM n'est fournie ; cela ne remplace pas encore des textures photographiques.
- [x] Première toiture géométrique à deux pans sur les empreintes quadrilatérales compatibles ; `roof:shape=gabled` est prioritaire, `flat` désactive la pente, et les formes non prises en charge (hipped, pyramidal, skillion, dôme…) restent volontairement en toiture plate provisoire.
- [ ] Étendre et affiner les profils de toitures inclinées (4 pans, formes complexes) selon des références architecturales locales.
- [x] Première passe de balcons stylisés sur certains immeubles à plusieurs niveaux, regroupés dans le mesh des façades.
- [ ] Ajouter auvents, escaliers et autres détails seulement là où le type et la taille du bâtiment le permettent.
- [ ] Mieux gérer les cours intérieures et trous dans les empreintes polygonales.
- [ ] Affiner les typologies architecturales locales à partir de photos/références vérifiables ; ne pas uniformiser toutes les constructions.

## 3. Relief, mer et environnement
- [ ] Télécharger et contrôler le DEM SRTM1 d'environ 30 m sur toute l'emprise Libreville (script ajouté : `tools/terrain/build_libreville_dem.py`; les fichiers de données ne sont pas encore générés).
- [ ] Intégrer le raster d'altitude dans Godot et construire le terrain maillé avec collision sur toute l'emprise.
- [ ] Recaler routes, trottoirs, bâtiments, végétation et objets sur l'altitude du terrain ; vérifier les raccords et les dénivelés.
- [ ] Distinguer relief du sol et hauteur des bâtiments ; SRTM/Copernicus sont des modèles de surface et ne remplacent pas un relevé topographique du sol nu.
- [x] Première représentation visuelle du tracé côtier OSM par une bande littorale couleur sable ; validation Godot 4.3 réussie sur `main` (ce n'est pas encore une surface mer/terre).
- [ ] Construire une surface mer/terre fiable à partir d'une géométrie côtière cohérente ; les lignes de côte seules ne suffisent pas.
- [ ] Ajouter plages, mangroves, rivières et zones humides lorsque les données sont vérifiées.
- [x] Première végétation 3D low-poly instanciée dans les espaces verts OSM (plafond 1 200, PR n°17 validée Godot 4.3) ; inspection visuelle et densité à confirmer.

## 4. Routes, mobilier et navigation
- [x] Hiérarchie de largeur et de couleur des routes selon leur catégorie OSM.
- [x] Lecture des tags OSM `width`, `lanes` et `surface` pour adapter largeur et revêtement lorsque ces informations existent.
- [x] Première fermeture des trous aux carrefours avec des raccords de chaussée légers sur les nœuds OSM partagés ; géométrie encore schématique, pas un vrai dessin de carrefour.
- [x] Étiquettes limitées des axes et des lieux importants.
- [ ] Vérifier les intersections complexes, ponts, voies à sens unique et connexions des routes ; les raccords circulaires ajoutés ne remplacent pas une modélisation de carrefour.
- [x] Première passe de trottoirs 3D regroupés sur les grands axes et lorsque les tags OSM indiquent leur présence (PR n°14 fusionnée, validation Godot 4.3 réussie).
- [x] Réseau routier v4 : chaussées et trottoirs posés sur le maillage exact du relief (plus de terrain qui recouvre la route), asphalte mélangé par shader (fissures à deux échelles, rapiéçages, zones délavées, traces de pneus, poussière sur les rives, usure selon la classe de route), pistes en terre (worn_asphalt) et béton/pavés (asphalt_floor) ; correction de plus de 132 000 erreurs `set_uv`. Validation Godot 4.3 : 0 erreur de script.
- [x] Trottoirs v4 : bordure biseautée, dalles 0,5 m, couverture réglable `sidewalk_coverage` (défaut : toutes les rues urbaines), coupés aux carrefours/T/entrées, jamais posés sur une voie voisine, rond-points côté extérieur seulement.
- [x] Voies doubles : les deux chaussées des axes rapides sont séparées par un terre-plein central surélevé (bordure + dessus béton gris) tant que l'écart ne dépasse pas 18 m ; chaque chaussée construit sa moitié, sans doublon.
- [x] Herbe/route : les polygones verts (végétation, espaces verts) sont découpés autour de chaque chaussée avec une marge de 1 m, et leurs triangles sont redécoupés (14 m) pour épouser le relief (avant : grands triangles plats flottant au-dessus des routes) ; brins d'herbe et arbres : 0 instance sur la route.
- [x] Phase tracé : option `render_green_areas` (défaut false) masque parcs/végétation/arbres/herbe OSM pour valider d'abord le tracé des routes ; à remettre à true pour la phase décor.
- [x] Lampadaires v1 : modèle `lampadaire_baie_des_rois.glb` posé sur les trottoirs (axes majeurs tous les 36–52 m, rues nommées 70 m d'un seul côté), orientés vers la chaussée, fusionnés en un seul mesh, visibles jusqu'à 260 m (13 013 au total).
- [x] Collision des chaussées et trottoirs (`road_collision`) : le joueur marche sur la route et monte sur le trottoir par une rampe douce.
- [x] Largeurs des bretelles (_link), pistes, chantiers et rues piétonnes ; marquages et passages piétons repoussés après la chaussée transversale ; meshes regroupés par zones de 800 m avec distance de visibilité pour trottoirs/marquages.
- [x] Premier marquage axial discontinu sur les axes structurants et voies explicitement à plusieurs voies (PR n°16, approximation visuelle, validation Godot 4.3).
- [x] Première génération de passages piétons schématiques aux extrémités de routes OSM structurantes connectées à trois segments ou plus (approximation, validation Godot 4.3 réussie sur `main`).
- [ ] Ajouter carrefours détaillés, ponts, signalisation et mobilier urbain à partir de données ou d'approximations visuelles signalées.
- [x] Première mini-carte nord en haut : routes OSM rasterisées et repère de position du joueur (PR n°18 fusionnée, validation Godot 4.3 réussie).
- [x] Première superposition des POI importants sur la mini-carte (santé, écoles, services publics, commerces, tourisme ; validation Godot 4.3 réussie sur `main`).
- [ ] Ajouter la navigation avec itinéraires et découverte interactive des POI.
- [x] Première prise en charge logicielle des manettes : stick gauche, croix directionnelle, bouton A pour sauter et stick droit pour la caméra ; test avec une manette physique encore requis.
- [x] Détection à chaud des connexions/déconnexions de manette et journalisation du nom/ID du périphérique ; test avec une manette physique encore requis. Validation automatisée Godot 4.3 réussie (workflow `44165860671`).

## 5. Performance et validation
- [x] Regroupement des routes et bâtiments en meshes pour réduire les draw calls.
- [x] Validation automatique Godot 4.3 sous rendu Compatibility passée après les améliorations de largeur, surface et raccords routiers (workflow `44160434574`, commit de base `3cc0325`). Le dernier ajustement d'orientation des faces a été ajouté ensuite et reste à confirmer par un nouveau rendu.
- [x] Validation Godot 4.3 après fenêtres et portes (rendu Compatibility réussi).
- [x] Validation Godot 4.3 après les balcons (PR n°13, rendu Compatibility réussi).
- [x] Validation Godot 4.3 de l'atlas procédural de toitures (PR n°15 fusionnée).
- [ ] Mettre en place le chargement/déchargement spatial par secteurs.
- [ ] Mesurer FPS, mémoire et temps de chargement sur la machine cible (GT 730 2 Go) ; aucun chiffre ne doit être annoncé avant ce test.
- [ ] Vérifier les collisions et la circulation du joueur sur les routes et autour des bâtiments.
- [ ] Faire une inspection visuelle en jeu à plusieurs endroits reconnaissables de Libreville.

## 6. Finition et livraison
- [x] Attribution OpenStreetMap prévue dans la scène et les crédits.
- [ ] Vérifier les crédits et licences de chaque nouvelle source (relief, imagerie, bâtiments éventuels).
- [ ] Corriger les anomalies cartographiques repérées pendant la visite en jeu.
- [ ] Geler une version de la carte, avec rapport d'extraction, captures et résultats de tests.
- [ ] Faire valider que le joueur peut se repérer réellement : position, nom de localité, axes et lieux remarquables.

## Critère de fin de carte
La carte pourra être considérée comme prête pour la phase de jeu lorsque l'extraction est vérifiée, que les localités et les lieux remarquables sont identifiables, que mer/relief et bâtiments sont cohérents, que le joueur se repère en jeu et que les performances sont mesurées sur la machine cible. Les éléments non couverts par des données fiables devront rester explicitement présentés comme des approximations visuelles.

## 7. Recherche documentaire et sources de référence (17/11/2026)
- [x] Documentation officielle Godot consultée pour les manettes : axes analogiques via Input.get_vector, zone morte et gestion des événements de manette.
- [x] Mairie de Libreville consultée : la commune comporte six arrondissements et publie des descriptions de délimitations ; ces descriptions doivent être converties en géométries vérifiables avant affichage.
- [x] Recherche complémentaire : la Banque mondiale décrit 89 unités de quartier numérotées issues d'un travail de superposition de cartes et de secteurs de recensement ; elles ne sont pas des limites officielles de quartiers nommés.
- [x] Références photographiques repérées : Wikimedia Commons (scènes de rues de Libreville) et Service audiovisuel de l'Union européenne (36 photos de Libreville).
- [x] Sources d'imagerie et de relief repérées : Sentinel-2 (10 m) et Copernicus DEM GLO-30 (30 m) ; résolution utile pour occupation du sol et relief général, insuffisante pour reconstruire les façades individuelles.
- [ ] Vérifier les licences image par image avant toute intégration dans le jeu ; les photos de référence ne sont pas automatiquement libres de réutilisation.
- [ ] Acquérir et intégrer une couche d'élévation, puis produire une surface mer/terre à partir d'une géométrie côtière fiable.
- [ ] Obtenir les géométries administratives des six arrondissements depuis la mairie ou une source officielle et documenter leur système de coordonnées.
- [ ] Définir des profils architecturaux distincts à partir des références visuelles (habitat individuel, habitat spontané, immeubles, commerces, bâtiments publics) plutôt que d'appliquer une texture unique à toute la ville.


### Références visuelles complémentaires consultées
- Wikimedia Commons, catégories Streets in Libreville et Street scenes in Libreville : photographies de rues, marché, boulevard du bord de mer et scènes urbaines ; vérifier chaque licence avant intégration.
- Service audiovisuel de l'Union européenne, reportage Libreville (P-060454, 27/02/2023) : 36 photographies de vues générales, rues, bâtiments officiels et religieux.
- Rapport ONU Gabon 2021 : vue aérienne montrant le mélange de bâtiments résidentiels/administratifs, végétation tropicale, grands axes et littoral.
- Étude sur les typologies d'habitat de l'agglomération : coexistence de villas, immeubles, logements sociaux et habitat spontané ; les styles doivent varier par secteur et non être uniformisés.
- Ces références guident la direction artistique, mais ne remplacent pas un relevé architectural géolocalisé ni une licence d'utilisation des photographies.


### Présentation du terrain et atmosphère
- [x] Texture procédurale légère de variation herbe/terre sur le plan de sol, générée au démarrage et sans maillage additionnel.
- [x] Première atmosphère de distance par brouillard doux, éclairage ambiant renforcé et lumière solaire légèrement chaude.
- [ ] Ajuster visuellement densité du brouillard, répétition de texture et direction des ombres sur la machine cible.


### Végétation et sources géographiques
- [x] Première variation déterministe des arbres instanciés : hauteur, largeur, orientation, teinte du tronc et couleur du feuillage ; reste une représentation low-poly simplifiée.
- [x] Ajouter trois silhouettes low-poly instanciées (couronne ronde, étalée et verticale) avec variation déterministe ; ce sont des profils visuels génériques, pas encore des espèces botaniques identifiées.
- [ ] Comparer le DEM SRTM1 généré avec Copernicus GLO-30 et contrôler les altitudes, les trous et la continuité aux bords.
- [ ] Obtenir l'accès et les conditions de réutilisation des orthophotographies/plans auprès de l'Institut National de Cartographie du Gabon.
- [ ] Préparer un extrait ESA WorldCover 2021 local pour différencier végétation, zones bâties, eau et mangroves ; conserver l'attribution CC BY 4.0.


## 8. Zone pilote — Baie des Rois (17/11/2026)
### Références et relevé
- [x] Repérer les vues aériennes et photos de la promenade, des kiosques, du pavillon de concert et du front de mer.
- [x] Repérer les trois secteurs décrits dans les sources publiques : Nord, Centre (ancien Port-Môle) et Sud ; ne pas réduire toute la Baie à la seule promenade Nord.
- [x] Confirmer la présence d'une promenade maritime, de kiosques commerciaux, de zones de loisirs, d'une passerelle piétonne entre Nord et Centre, de terrains remblayés et de chantiers immobiliers.
- [ ] Géoréférencer précisément les photos aériennes et établir un plan de masse à l'échelle du jeu.
- [ ] Relever l'emplacement exact, les dimensions et l'orientation de chaque kiosque, du pavillon de concert, des jeux, des terrains sportifs et de la passerelle.
- [ ] Déterminer l'état réel de chaque parcelle à la date de référence choisie (livré, en chantier, prévu).

### Modélisation et eau
- [x] Identifier le défaut majeur de la première eau : les surfaces étaient sous le plan de sol mondial (y négatif) et donc masquées.
- [x] Remplacer les blocs d'eau opaques/sous le sol par des surfaces de mer dédiées, légèrement au-dessus du plan de sol, avec shader animé léger (variations de houle et reflets stylisés).
- [x] Ajouter les nappes d'eau dédiées au-dessus du plan mondial, séparées de la promenade (première couverture rectangulaire à contrôler visuellement).
- [ ] Corriger la limite terre/mer avec une géométrie côtière continue et une digue/enrochement précisément alignés ; les nappes actuelles ne suivent pas encore un relevé géoréférencé.
- [x] Ajouter une barrière de collision continue par segments chevauchants, dimensionnée au-dessus de la hauteur de saut du personnage ; les essais en jeu restent à effectuer.
- [ ] Remplacer les kiosques génériques par les modèles correspondant aux références (bois, ouvertures, auvents, enseignes, mobilier).
- [ ] Remodéliser le pavillon de concert à coque courbe et sa place, au lieu du volume rectangulaire provisoire.
- [ ] Modéliser la passerelle piétonne en bois/métal avec tablier, poutres, garde-corps et appuis ; vérifier ses deux raccordements.
- [ ] Ajouter mobilier, palmiers, plantations, jeux et éclairage à partir des références visuelles.
- [ ] Ajouter les bâtiments et chantiers de la zone avec leurs états et hauteurs vérifiés.

### Validation de la zone
- [ ] Ouvrir la version main dans Godot 4.3 et vérifier les erreurs de parsing/shader, notamment après l'ajout des collisions côtières.
- [ ] Inspecter l'eau et la promenade depuis plusieurs points de vue, à pied et depuis les hauteurs.
- [ ] Contrôler les collisions, les raccords de la passerelle et l'accès aux zones commerciales.
- [ ] Mesurer FPS et mémoire sur le PC cible ; aucun chiffre de performance n'est validé pour l'instant.

### Sources de référence consultées
- Construction21, fiche « La Baie des Rois » : photos aériennes et vues de la promenade, des kiosques et du pavillon.
- FGIS, page « Land Development » : vue aérienne générale du remblai et de la péninsule aménagée.
- AGP, 20 août 2022 : promenade Nord de 1,2 km et huit kiosques commerciaux.
- GabonActu, 4 août 2023 : distinction zone Nord, zone Centre et zone Sud ; passerelle piétonne prévue entre Nord et Centre.
- Le360 Afrique, 30 juin 2024 : reportage vidéo sur le chantier et le développement du front de mer.
- YouTube, « Promenade sur la Baie des Rois - Libreville (Gabon) », 21 décembre 2024 : vue aérienne du site.
- YouTube, « Libreville : La Baie des Rois en plein chantier », 27 septembre 2025 : visite filmée du chantier.
- Les photos et vidéos servent de références de modélisation ; elles ne sont pas automatiquement autorisées comme textures du jeu. Les matériaux du jeu doivent être recréés ou provenir d'assets dont la licence est vérifiée.


### Avancement technique — première passe de sécurisation de la côte (17/11/2026)
- [x] Les surfaces d'eau sont maintenues au-dessus du plan de sol mondial pour éviter leur masquage.
- [x] Les enrochements côtiers reçoivent désormais des collisions physiques alignées sur leur géométrie visible ; ils forment une première barrière entre la promenade et l'eau.
- [ ] La côte reste une approximation par segments et les nappes d'eau restent rectangulaires : le tracé réel devra être géoréférencé avant de déclarer la rive fidèle au site.
- [ ] Aucun lancement Godot 4.3 ni test de déplacement du joueur n'a été exécuté dans cet environnement ; validation utilisateur nécessaire.


### Consolidation de la phase 1 — 17/11/2026
- [x] La barrière côtière est passée à 24 segments chevauchants sur 230 m afin de réduire les interstices entre collisions.
- [x] La collision invisible est plus haute que la hauteur de saut théorique du joueur (vitesse de saut 5,2 m/s ; gravité projet à confirmer en exécution).
- [ ] La géométrie actuelle reste une approximation locale ; les données OSM de littoral disponibles autour du secteur sont fragmentées en plusieurs ways et ne forment pas à elles seules un polygone de mer fiable. Ne pas les assembler arbitrairement.
- [ ] Validation finale dans Godot 4.3 indispensable : vérifier le rendu, les raccords, le franchissement aux extrémités et l'absence d'accès au sol sous-marin.
- [ ] Mesurer le coût GPU/CPU sur la configuration cible avant d'ajouter des effets d'eau plus coûteux.

### Références consultées pour la zone
- OpenStreetMap / données locales data/osm/environment.geojson : segments de coastline présents autour de 9.432–9.438°E et 0.397–0.405°N, mais géométries fragmentées ; elles nécessitent un contrôle cartographique avant assemblage.
- DGMP Gabon, marché de conception et réalisation de la promenade du front de mer de la zone 1 : https://lejmp.com/marches_approuves/marche-14050/
- Land'Act, fiche projet Baie des Rois (40 hectares, marina, corniche botanique, espaces de vie) : https://land-act.fr/projets/la-baie-des-rois/
- VOA Afrique, ouverture partielle de la promenade et superficie livrée en 2022 : https://www.voaafrique.com/a/gabon-loisirs-la-promenade-de-la-baie-des-rois-enfin-ouverte-aux-librevillois/6710716.html
- GabonActu, distinction zones Nord, Centre (Port-Môle) et Sud et passerelle Nord-Centre : https://gabonactu.com/blog/2023/08/04/baie-des-rois-la-promenade-centre-bientot-ouverte-au-public/

### Correctif direction artistique — mise en sécurité du blockout (17/11/2026)
- [x] Désactiver l'exécution des anciens générateurs procéduraux de la Baie des Rois : nappes d'eau rectangulaires, kiosques cubiques, palmiers en boîtes, pelouses et mobilier simplifiés.
- [x] Empêcher ces éléments approximatifs de recouvrir les routes et bâtiments de la carte.
- [ ] Refaire la zone à partir d'un plan géoréférencé, avec contour terre/mer relevé et kiosques positionnés sur l'arc de promenade.
- [ ] Remplacer les volumes temporaires par des modèles Blender détaillés, matériaux PBR et textures photographiques sous licence.
- [ ] Réintroduire l'eau uniquement après validation de la géométrie de rive ; shader d'eau réaliste et reflets adaptés au renderer Compatibility.
- [ ] Valider le rendu et les performances dans Godot 4.3 sur la GT 730 2 Go.

**Important :** le blockout précédent est volontairement neutralisé. Cela retire les éléments faux, mais ne signifie pas que la Baie des Rois est déjà reconstruite. La prochaine version visuelle doit venir de modèles et de données géographiques vérifiés, pas de nouveaux rectangles ou cubes générés au hasard.


## Intégration DEM SRTM — 19 novembre 2026

- Les fichiers de grille sont actuellement à la racine du dépôt : `libreville_dem.json`, `libreville_dem_f32.bin` et `libreville_srtm1_source.tif`.
- `game/scripts/world_map.gd` charge les métadonnées et la grille float32, vérifie la taille binaire, interpole les altitudes par bilinéaire et génère le terrain en blocs de 32 × 32 cellules avec collision trimesh.
- Le sol plat de `main.tscn` est masqué et sa collision désactivée lorsque la scène de carte démarre.
- Routes, trottoirs, éléments environnementaux, arbres, herbe et bases des bâtiments utilisent désormais l'altitude SRTM. Les objets autonomes de la Baie des Rois sont décalés à leur altitude d'ancrage.
- Résolution source préparée : environ 30 m. Le relief ne représente pas les bordures, trottoirs ou micro-pentes ; les bâtiments utilisent une altitude moyenne à l'empreinte.
- **À faire sur le poste Godot** : lancer le projet, contrôler les raccords de terrain, l'orientation des normales, les collisions, les zones côtières et les performances sur la GT 730. Aucun test du moteur Godot n'a été exécuté dans l'environnement de développement de l'assistant.
