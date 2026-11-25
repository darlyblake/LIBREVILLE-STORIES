# Périmètre des ouvrages d'art — carte jouable LIBREVILLE STORIES

Mise à jour : 25 novembre 2026

## Règle de périmètre

La référence n'est ni « tout le Grand Libreville », ni la seule Baie des Rois. La référence est l'emprise géographique de la carte de gameplay du dépôt :

- 72 secteurs issus de `data/osm/neighbourhoods.geojson` ;
- 6 regroupements d'arrondissement dans `data/osm/arrondissements.geojson` ;
- points OSM de `data/osm/localities.geojson` ;
- emprise OSM principale documentée dans `data/osm/extraction-report.json` : sud 0.355, ouest 9.400, nord 0.445, est 9.495.

Les quartiers/secteurs listés dans `data/osm/README_LIMITES_GAMEPLAY.md` sont le périmètre de référence du projet. L'extraction étendue (0.300–0.500 / 9.370–9.550) sert de réserve documentaire et ne donne pas automatiquement le droit d'ajouter des lieux à la carte.

## Contrôle obligatoire avant recherche ou modélisation

Un ouvrage n'est retenu que si son tablier, ses rampes ou ses accès utiles intersectent réellement un secteur jouable. Le nom d'un quartier voisin, une coordonnée approximative ou une mention dans un marché public ne suffisent pas.

Pour chaque ouvrage :
1. extraire la géométrie OSM complète du tablier et des voies de raccordement ;
2. vérifier l'intersection avec les polygones de secteurs jouables ;
3. noter les identifiants OSM et les coordonnées de l'emprise, pas seulement le centroïde du quartier ;
4. vérifier le statut (existant, chantier, projet) à la date de la période représentée ;
5. comparer avec plusieurs photos/vidéos publiques et, si possible, une vue aérienne ;
6. ne construire qu'après ce contrôle. Si la géométrie ne peut pas être confirmée, conserver le statut « à vérifier ».

## Ouvrages à contrôler en priorité dans les secteurs du jeu

Les éléments ci-dessous sont des candidats de recherche, pas une validation automatique de leur présence complète dans la carte.

| Candidat | Secteur de gameplay correspondant | État de sélection |
|---|---|---|
| Échangeur / pont de PK5 | PK5, Bassin du PK5 | À contrôler par géométrie du tablier ; la coordonnée du quartier PK5 ne doit pas être utilisée comme centre de l'ouvrage |
| Échangeur de Nzeng-Ayong | Nzeng Ayong, Cité des Ambassadeurs | À contrôler par géométrie OSM complète |
| Échangeur des Charbonnages | Charbonnages | À contrôler par géométrie OSM complète |
| Échangeur / pont Awendjé | Awendjé | À contrôler par géométrie OSM complète |
| Échangeur IAI | I.A.I-Golf | À contrôler par géométrie OSM complète |
| Échangeur de Lalala à droite | Lalala-Droite | À contrôler par géométrie OSM complète |
| Échangeur de la Démocratie | Cité de la Démocratie | À contrôler par géométrie OSM complète |
| Pont de la Caisse | Cité de la Caisse | À contrôler : vérifier que le tablier est dans le polygone jouable et non simplement dans le voisinage |
| Pont / ouvrages d'Oloumi | Oloumi, Zone Industrielle d'Oloumi | À contrôler par tracé exact et raccordements |
| Pont Nomba | Nombakele / secteur réellement traversé par le tablier | À contrôler : le nom « Pont Nomba » seul ne permet pas d'établir le secteur |

## Hors sélection actuelle ou non démontré

- Camp de Gaulle : aucun secteur de gameplay portant ce nom ne figure dans la correspondance actuelle des 72 cellules. Ne pas lancer sa reconstruction tant qu'une intersection réelle avec un polygone jouable n'est pas démontrée.
- Échangeur de la Route Protocole : emplacement exact et intersection avec les secteurs jouables non démontrés ; ne pas l'ajouter à la liste de construction.
- Passerelles du corridor PK5–PK12 : ne retenir que celles dont la géométrie individuelle tombe dans les polygones jouables. La mention d'un corridor plus long ne signifie pas que toutes ses passerelles sont dans notre carte.
- Tout autre ouvrage du Grand Libreville hors des 72 secteurs : exclu du travail de modélisation.

## Sources et licences

- Données géographiques : OpenStreetMap, ODbL 1.0, attribution « © OpenStreetMap contributors ».
- Inventaire de recherche détaillé : `docs/INVENTAIRE_OUVRAGES_ART_LIBREVILLE.md`.
- Les photos et vidéos de presse ou de réseaux sociaux sont des références d'observation uniquement ; elles ne doivent pas être copiées comme textures ou images du jeu sans licence/autorisation.
- Les textures intégrées doivent provenir de ressources CC0 ou de licences compatibles, avec leurs crédits conservés.

## État de validation

À la date de cette note, la correspondance des secteurs de gameplay est documentée, mais les intersections ouvrage-par-ouvrage ne sont pas encore certifiées par un calcul SIG sur les géométries complètes. Aucun candidat de ce tableau ne doit être déclaré « validé dans la carte » avant cette opération.
