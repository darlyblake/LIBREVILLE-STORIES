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


## Recherche documentaire complémentaire — 25 novembre 2026

La recherche publique confirme que plusieurs ouvrages candidats correspondent bien à des secteurs présents dans notre carte. Elle sert à prioriser les relevés, mais ne remplace pas le contrôle SIG des emprises.

### Références utiles dans le périmètre de gameplay

- **PK5 → Awendjé → IAI → Lalala → Pont Nomba** : le dossier d'entretien de la Voie Express décrit explicitement ce corridor et distingue les interventions « sous le pont » / « sur le pont ». Cette source permet de préparer des fiches séparées par ouvrage, sans fusionner les structures. Source : https://www.lejmp.ga/public/file_dossier/676143ae94db7.pdf
- **Nzeng-Ayong** : reportage du 20 avril 2025 décrivant le tablier, une cavité apparue dans la chaussée et les risques liés à l'érosion. Pour une version de jeu datée de 2025, la surface routière et les réparations provisoires doivent être vérifiées sur des images de la même période : https://www.gabonreview.com/echangeur-de-nzeng-ayong-quand-letat-joue-a-la-roulette-russe-avec-la-vie-des-usagers/
- **Nzeng-Ayong — abords** : reportage du 1er août 2025 documentant les démolitions de constructions de fortune autour de l'échangeur. Ne pas reproduire automatiquement les anciennes boutiques comme si elles étaient toujours présentes : https://www.gabonreview.com/deguerpissement-chute-de-lhimalaya-et-de-les-retrouvailles-de-lechangeur-de-nzeng-ayong/
- **Charbonnages — sous le tablier** : reportage photographique de L'Union du 11 mars 2021 montre les piliers, les passages piétons et les installations commerciales informelles sous le pont. Il s'agit d'une référence historique datée, pas d'une preuve de l'état actuel : https://lunion-archives.org/web.11/dmdocuments/N13571-11-03-2021-006.pdf
- **Charbonnages — jardin** : vidéo de Gabon Télévisions du 5 avril 2025 documente le chantier d'aménagement du jardin de l'échangeur : https://www.youtube.com/watch?v=AAjzBr1c2X4
- **Awendjé** : article du 21 mars 2025 décrit les traversées piétonnes dangereuses sous l'échangeur ; à utiliser pour observer les flux et l'usage des abords, pas pour inventer les dimensions du tablier : https://www.gabonreview.com/tribune-awendje-un-echangeur-des-dangers-une-solution/
- **État des grands axes** : article du 22 novembre 2025 cite notamment Nzeng-Ayong, Cité de la Caisse, PK5, Awendjé, Charbonnages et Lycée d'État dans les opérations de remise en état. La présence du Lycée d'État dans l'article ne suffit pas à l'inclure dans notre carte : https://gabonmediatime.com/gabon-cure-de-jouvence-dans-le-grand-libreville/

### Décision de production

1. Prioriser les ouvrages du corridor documenté qui tombent dans les secteurs jouables : PK5, Awendjé, IAI, Lalala et Pont Nomba.
2. Traiter séparément l'échangeur de Nzeng-Ayong, Charbonnages et la Démocratie, car leurs usages, formes et états documentés diffèrent.
3. Pour chaque modèle, conserver une date de référence visuelle. Les opérations de déguerpissement, de réhabilitation ou d'aménagement peuvent modifier fortement les abords.
4. Les pages, vidéos et photos ci-dessus sont des références d'observation. Aucune image protégée n'est intégrée comme texture au jeu.
5. Aucun ouvrage hors des secteurs de la carte n'est ajouté parce qu'il apparaît dans un dossier couvrant un corridor plus long.
