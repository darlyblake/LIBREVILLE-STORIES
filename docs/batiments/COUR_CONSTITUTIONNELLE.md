# Fiche de modélisation — Palais de la Constitution (Cour constitutionnelle)

**Projet :** LIBREVILLE STORIES  
**Cible :** Godot 4.3 / GLB  
**Priorité :** Lot administratif 1  
**État :** références architecturales documentées ; modèle 3D non encore produit ni validé en jeu.

## 1. Identification et implantation

- Nom à afficher : **Palais de la Constitution — Cour constitutionnelle du Gabon**.
- Secteur : front de mer, boulevard de l’Indépendance / boulevard de la Nation, Libreville.
- Objet cartographique suivi dans le plan principal : OSM way **410343353**.
- Coordonnées de référence inscrites dans l'inventaire : **0.39687, 9.43989**.
- Ces coordonnées désignent le repère cartographique du site, pas nécessairement le point d'entrée ni le pivot du modèle.
- Le bâtiment physique doit être rattaché à son empreinte existante dans `data/osm/extended/buildings.geojson`. Ne pas placer un second volume indépendant sur le même emplacement.

## 2. Faits architecturaux confirmés par les sources

Les sources publiques décrivent le siège inauguré le 30 décembre 2014 après environ six années de travaux :
- bâtiment institutionnel de **six niveaux** ;
- terrain annoncé de **3 800 m²** ;
- surface totale annoncée d'environ **17 000 m²** (une autre source indique 16 800 m²) ;
- implantation en front de mer, au-dessus du boulevard de l'Indépendance ;
- programme intérieur comprenant notamment auditorium de 750 places, salons officiels, salles de réunion, bureaux, bibliothèque, salle de presse, infirmerie, restaurant, archives et parking ;
- architecture décrite comme unique et imposante.

**Précaution de mesure :** les surfaces publiées ne sont pas des dimensions de façade. Ne pas en déduire arbitrairement longueur, largeur ou hauteur. Utiliser l'empreinte OSM pour l'emprise horizontale, puis ajuster les proportions à partir de vues photographiques.

## 3. Références visuelles à consulter

1. Gabonreview, inauguration et description du bâtiment (31 décembre 2014) : https://www.gabonreview.com/cour-constitutionnelle-ses-meubles/
2. Gabonews, nouveau siège, six niveaux, terrain et programme (31 décembre 2014) : https://www.gabonews.com/fr/actus/politique/article/inauguration-du-nouveau-siege-de-la-cour
3. Architecte / équipe de design intérieur, projet « Constitutional Court », Libreville, 2014 : https://www.giancarlotagliabue.com/p/en/projects/constitutional-court/260/
4. L’Union, photographie extérieure légendée « Le siège de la Cour constitutionnelle » (24 février 2022, PDF) : https://lunion-archives.org/web.11/dmdocuments/N%2013860-24-02-2022-003.pdf
5. Afrik.com, visite du chantier et informations sur l'emprise (13 février 2014) : https://www.afrik.com/gabon-le-nouveau-siege-de-la-cour-constitutionnelle-bientot-sur-pied

Ces liens servent de références d'observation. Les photographies restent la propriété de leurs ayants droit : ne pas les extraire et les intégrer comme textures sans autorisation. Reconstituer les matériaux avec des textures CC0 et modéliser les formes observées.

## 4. Cahier des charges visuel — à confirmer sur plusieurs photos

- [ ] Vue frontale nette de l'entrée principale.
- [ ] Vue oblique gauche et droite pour lire le plan et les volumes.
- [ ] Vue latérale côté mer.
- [ ] Vue arrière / accès de service.
- [ ] Vue aérienne permettant de comprendre toiture, cour et implantation.
- [ ] Détails des éléments distinctifs (couronnement, colonnes, auvents, balcons, garde-corps, baies, escaliers).
- [ ] Relever les couleurs réelles et les matériaux dominants.
- [ ] Confirmer le nombre et la disposition des niveaux visibles depuis l'extérieur.

Ne pas extrapoler la forme exacte d'une coupole, d'une toiture ou d'une façade depuis une seule photographie partielle. Les vues disponibles montrent un grand édifice institutionnel clair/beige avec un traitement architectural distinctif ; les détails de la silhouette devront être relevés sur les photographies originales avant modélisation finale.

## 5. Découpage Blender recommandé

Créer un seul asset principal, organisé en objets nommés :
- `CC_GroundBase` — soubassement et plateforme ;
- `CC_MainStructure` — volumes principaux ;
- `CC_Facade_Walls` — murs extérieurs ;
- `CC_Columns` — poteaux/colonnes réellement visibles ;
- `CC_Windows` — cadres et vitrages ;
- `CC_Entrance` — entrée, marquise et escaliers ;
- `CC_Roof` — toiture, couronnement et équipements ;
- `CC_Railings` — garde-corps ;
- `CC_SiteDetails` — accès, murets, clôtures et aménagements visibles dans l'emprise ;
- `CC_Collision` — volumes de collision simplifiés, séparés du rendu.

L'organisation exacte sera adaptée aux photos. Les noms ci-dessus sont une convention de production, pas une affirmation sur les composants réels.

## 6. Matériaux PBR

Réutiliser les matériaux téléchargés par `python3 tools/download_cc0_textures.py --resolution 2k` :
- béton / enduit clair : `white_plaster_02`, `concrete_wall_009` ;
- sols et marches : `concrete_floor_01` ;
- éléments métalliques : `metal_plate_02` ;
- vitrage : matériau Godot dédié, faible rugosité et transparence contrôlée.

Créer des variantes de teinte après comparaison avec les photos. Ne pas utiliser automatiquement une texture de brique ou de tôle ondulée si ces matériaux ne sont pas visibles sur le bâtiment.

## 7. Échelle, optimisation et intégration

- Unités Blender : métriques ; appliquer les transformations avant export.
- Orientation et pivot : documenter le nord et le point de référence utilisé ; faire correspondre l'orientation à l'empreinte OSM et au repère du monde.
- Export : glTF 2.0 / GLB.
- Textures : 1K/2K selon la taille à l'écran ; limiter le nombre de matériaux.
- Géométrie : instancier les éléments répétitifs, fusionner les objets statiques par matériau si cela ne nuit pas à la maintenance.
- LOD : version complète à proximité, version simplifiée à moyenne distance.
- Collisions : quelques formes simples, pas de collision triangle détaillée sur chaque moulure.
- Godot : attacher le GLB à l'objet bâtiment existant ; désactiver/masquer uniquement le rendu générique correspondant, sans supprimer les données OSM ni générer un doublon.
- Contrôle : vérifier l'alignement, l'échelle, le niveau du sol, les collisions, les ombres, les performances et l'aspect depuis la route.

## 8. Suivi de production

- [x] Site et identifiant OSM retrouvés dans le plan du jeu.
- [x] Sources publiques décrivant l'édifice et son programme rassemblées.
- [x] Faits architecturaux quantitatifs documentés.
- [ ] Photos de référence multi-angles collectées et comparées.
- [ ] Empreinte exacte et orientation vérifiées dans le GeoJSON local.
- [ ] Blocage architectural Blender créé.
- [ ] Modèle détaillé terminé.
- [ ] Matériaux PBR affectés.
- [ ] GLB exporté.
- [ ] GLB intégré à Godot.
- [ ] Contrôle visuel en jeu validé.

## 9. Historique

- 2026-11-26 : création de la fiche de production à partir du plan OSM existant et de sources publiques sur l'inauguration, l'architecture et le programme du Palais de la Constitution. Aucun modèle 3D n'est déclaré terminé.
