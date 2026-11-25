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


## Vérification géographique complémentaire — candidats et exclusions

### Emprise de référence

L'extraction OSM principale du projet utilise la boîte :
- latitude : 0.355 à 0.445 ;
- longitude : 9.400 à 9.495.

Cette boîte est une première limite technique de la carte, pas une preuve suffisante à elle seule : les ouvrages doivent aussi être présents dans les routes/données réellement chargées par le jeu. Les secteurs Voronoï sont des limites de gameplay à faible confiance, non des frontières administratives.

### Ouvrages confirmés dans l'emprise générale de la carte

| Ouvrage | Référence OSM / position publiée | Contrôle spatial disponible | Décision |
|---|---|---|---|
| Échangeur des Charbonnages | way 1443840888 ; point publié 0.43650, 9.44087 | Dans la boîte de l'extraction ; le point tombe dans le polygone de gameplay « Charbonnages » | Retenu pour relevé détaillé |
| Pont Awendjé | way 1435825401 ; point publié 0.38640, 9.47466 | Dans la boîte ; le point tombe dans le polygone « Awendjé » | Retenu pour relevé détaillé |
| Échangeur de Nzeng-Ayong | way 169184393 ; axe publié autour de 0.42124, 9.46594 | Dans la boîte ; ce point tombe dans le polygone généré « Cité de la Caisse », ce qui signale une limite Voronoï à contrôler, mais ne le place pas hors carte | Retenu, géométrie à superposer précisément |
| Pont de la Caisse | way 1395147722 ; point publié 0.41447, 9.46781 | Dans la boîte ; le point tombe dans le polygone « Cité Mébiame » | Retenu pour relevé détaillé |

Sources cartographiques des références OSM : Mapcarta / OpenStreetMap pour l'Échangeur des Charbonnages, le Pont Awendjé et le Pont de la Caisse. Les coordonnées publiées sont des repères de carte et ne remplacent pas les géométries complètes des ways.

### Candidats présents dans les secteurs couverts, mais dont le tablier doit encore être localisé

- Échangeur PK5 : les sources cartographiques le placent à proximité du quartier PK5 et du Pont de la Caisse. Le point du quartier PK5 (0.40656, 9.46772) n'est pas le point du tablier. Le tablier reste à identifier par son way OSM.
- Échangeur IAI : le dossier Banque mondiale situe l'échangeur au nord-ouest du site IAI et fournit une orthophoto de référence ; une source de décembre 2025 documente les glissières de sécurité du pont. Il reste à extraire la géométrie du tablier.
- Échangeur de Lalala à droite : le marché N°90/MTPC/SG/2025 porte sur la Voie Express entre les échangeurs de Charbonnages et de Lalala à droite. Le way exact de l'ouvrage doit être identifié avant construction.
- Échangeur de la Démocratie : le dossier d'entretien de la Voie Express le situe entre Charbonnages et Nzeng-Ayong ; une publication de juillet 2024 documente les travaux sur la section PK5–Démocratie. La géométrie exacte reste à extraire.
- Échangeur du Lycée d'État : le marché d'entretien le cite sur la Voie Express. Il reste à vérifier par le tracé OSM et son intersection avec les secteurs chargés.

### Exclusion corrigée : Pont Nomba

Le point OSM du quartier « Pont-Nomba » est publié à environ 0.33908, 9.47685, et la station « OILIBYA Pont Nomba » à environ 0.33942, 9.47854. Ces deux repères sont au sud de la limite de latitude 0.355 de l'extraction principale. Le dossier d'entretien de la Voie Express mentionne bien un lot qui va jusqu'au Pont Nomba, mais ce lot couvre un corridor plus long que notre carte.

**Décision : Pont Nomba exclu de la liste de modélisation actuelle.** Il ne sera réintégré que si une extension officielle de l'emprise du jeu vers le sud est décidée et que les données de carte sont mises à jour. Ne pas confondre le nom du quartier avec un pont situé dans notre emprise.

### Références documentaires complémentaires

- Marché d'entretien de la Voie Express, qui distingue les interventions sur/sous les échangeurs et mentionne plusieurs secteurs du corridor : https://www.lejmp.ga/public/file_dossier/676143ae94db7.pdf
- Pont de la Caisse, way OSM 1395147722 et coordonnées publiées : https://mapcarta.com/fr/W1395147722
- Pont Awendjé, way OSM 1435825401 et coordonnées publiées : https://mapcarta.com/fr/W1435825401
- Échangeur des Charbonnages, way OSM 1443840888 et coordonnées publiées : https://mapcarta.com/fr/W1443840888
- Échangeur de Nzeng-Ayong, way OSM 169184393, tags bridge=viaduct, layer=1, lanes=2 : https://ga.geoview.info/echangeur_de_nzeng_ayong%2C169184393w
- Dossier Banque mondiale : localisation IAI/Charbonnages et orthophoto : https://documents1.worldbank.org/curated/en/744961468009995599/pdf/E29250v40FRENC000PUBLIC00Box379870B.pdf
- État des glissières de l'échangeur IAI, 17 décembre 2025 : https://gabonmediatime.com/libreville-echangeur-diai-le-danger-permanent/
- Marché de réhabilitation Charbonnages–Lalala, approuvé le 15 janvier 2026 : https://lejmp.com/marches-approuves/11/

### État de certitude

Les quatre ouvrages du tableau « confirmés dans l'emprise générale » sont confirmés comme candidats dans l'enveloppe de la carte, pas encore certifiés par intersection complète du tablier avec les polygones de gameplay. Les échangeurs PK5, IAI, Lalala, Démocratie et Lycée d'État restent à relever précisément. Aucun modèle 3D ne doit être construit à partir d'un simple point de quartier.



## Complément de recherche — secteurs IAI et Lalala (25 novembre 2026)

### IAI — repère local dans l'enveloppe

- Le secteur **I.A.I-Golf** figure explicitement dans la liste des secteurs jouables du 5e arrondissement dans `data/osm/README_LIMITES_GAMEPLAY.md`.
- Une adresse locale publiée « Échangeur d'IAI, entrée Ozangué » est géolocalisée à **0.3728677, 9.4761053**. Ce repère est à l'intérieur de l'enveloppe principale (0.355–0.445 / 9.400–9.495). Il s'agit toutefois d'une pharmacie / adresse de proximité, **pas du point géométrique du tablier** : ne pas l'utiliser comme origine du modèle.
- L'AGP décrit, le 21 août 2026, une opération municipale autour de l'échangeur de l'IAI et sur l'axe Carrefour Lalala–Lalala à droite. Cette source confirme l'existence et le contexte urbain récent des deux secteurs, mais ne donne ni les dimensions ni la géométrie du pont.
- Le dossier Banque mondiale fournit une orthophoto et indique l'échangeur IAI au nord-ouest du site IAI. À utiliser comme référence de contexte spatial, après recalage sur les données OSM du jeu.

**Décision IAI :** candidat maintenu pour relevé et modélisation, car le secteur I.A.I-Golf appartient à la carte et le repère local de proximité est dans l'enveloppe. Le tablier et ses rampes restent à extraire et à intersecter avec le polygone jouable avant validation finale.

### Lalala à droite — secteur jouable, ouvrage à préciser

- **Lalala-Droite** figure dans la correspondance des secteurs jouables du 5e arrondissement.
- Le marché public N°90/MTPC/SG/2025 porte sur la réhabilitation de la Voie Express entre l'échangeur de Charbonnages et l'échangeur de Lalala à droite.
- L'AGP du 21 août 2026 documente l'axe Carrefour Lalala–Lalala à droite et les abords de l'échangeur IAI.
- Ces éléments établissent que Lalala à droite est bien un secteur concerné par le corridor étudié, mais ne prouvent pas que chaque bretelle ou ouvrage du corridor est dans la zone chargée par le jeu.

**Décision Lalala :** maintenir comme candidat dans la zone de recherche. Ne pas construire de modèle ni fixer un point de tablier avant extraction de la géométrie OSM complète.

### PK5 — confirmation du contexte, pas du point exact

Mapcarta répertorie explicitement « Echangeur PK5 » comme pont à proximité des repères PK5, RIO, Bassin du PK5 et des écoles de Sibang. Ces pages confirment l'existence de l'ouvrage et sa proximité avec les secteurs jouables, mais ne donnent pas ici de coordonnées propres au tablier. Le point du quartier PK5 (0.40656, 9.46772) reste un point de localité et ne doit pas être substitué à la géométrie du pont.

### Incohérence documentaire à corriger dans le pipeline SIG

Le fichier `data/osm/README_LIMITES_GAMEPLAY.md` décrit 72 cellules de gameplay, et le fichier `data/osm/neighbourhoods.geojson` du dépôt contient les polygones générés. En revanche, `data/osm/extraction-report.json` annonce `neighbourhoods.geojson` avec **0 feature** et 77 octets. Ce rapport d'extraction ne reflète donc pas l'état actuel du fichier de polygones (probablement un rapport ancien ou issu d'une étape antérieure).

**Action technique requise :** régénérer le rapport d'extraction à partir des fichiers réellement versionnés, puis exécuter le contrôle SIG sur les géométries complètes des ouvrages. Tant que ce rapport n'est pas synchronisé, il ne faut pas le présenter comme une preuve du nombre actuel de secteurs.

### Sources publiques ajoutées

- AGP, 21 août 2026 — intervention autour de l'échangeur IAI et axe Carrefour Lalala–Lalala à droite : https://agpgabon.ga/gabon-municipalite-lancement-de-loperation-liberez-les-trottoirs-dans-le-5e-arrondissement-de-libreville/
- Repère local près de l'échangeur IAI, adresse et coordonnées publiées : https://ga.near-place.com/pharmacie-nouo-cecile-unnamed-rd-libreville
- Marchés approuvés, N°90/MTPC/SG/2025 — Voie Express Charbonnages–Lalala à droite : https://lejmp.com/marches-approuves/11/
- Dossier Banque mondiale — orthophoto et localisation IAI : https://documents1.worldbank.org/curated/en/744961468009995599/pdf/E29250v40FRENC000PUBLIC00Box379870B.pdf
- Mapcarta / OpenStreetMap — repères PK5 et échangeur à proximité : https://mapcarta.com/fr/N4071487877


### Références visuelles IAI — tablier, dessous, drainage et usages

Les sources publiques apportent désormais des observations complémentaires utiles au futur modèle :

- **17 décembre 2025 — glissières et piétons :** reportage de Gabon Media Time et sa vidéo Dailymotion montrent des glissières de sécurité affaissées ou ouvertes, des passages improvisés de piétons et les circulations sur/au-dessous du pont. Ce sont des observations datées de 2025 ; elles ne doivent être reproduites que si la période choisie pour le jeu correspond à cet état.
- **20 avril 2021 — inondation et assainissement :** L'Union décrit la stagnation d'eau sur la chaussée à l'amorce de l'échangeur, l'étroitesse de la voie, l'encombrement des bassins-versants et l'obstruction des caniveaux. La photo d'archive montre un grand canal d'évacuation. Pour le décor, cela justifie de relever les fossés, avaloirs, caniveaux, buses et niveaux de chaussée au lieu de poser seulement une dalle de béton.
- **12 septembre 2018 — services sous l'échangeur :** une archive de L'Union mentionne des toilettes publiques au carrefour IAI. Ce détail peut guider l'observation des petits équipements de proximité, mais ne doit pas être ajouté au modèle sans vérification visuelle de la période retenue.
- **Novembre 2026 — récurrence des eaux pluviales :** un article récent rapporte que les pluies continuent de perturber la circulation à IAI et mentionne une intervention d'assainissement ainsi que l'actualisation des études du bassin-versant Lowé–IAI. Cela confirme que la gestion de l'eau fait partie du caractère réel du site, sans fournir de plan technique coté.

**Consignes de modélisation IAI (à appliquer après acquisition de la géométrie) :**
1. Séparer le tablier supérieur, les voies inférieures, les piles, culées, rampes et bretelles.
2. Relever la section des glissières et leur implantation ; ne pas inventer leur profil ni leur nombre.
3. Modéliser les dispositifs d'évacuation des eaux réellement visibles : caniveaux, avaloirs, buses, fossés et canal, avec raccordement au relief.
4. Construire les abords avec les trottoirs, les traversées piétonnes et les usages commerciaux observés, en gardant une date de référence.
5. Ne pas utiliser les photos de presse comme textures. Elles servent de références d'observation ; créer les matériaux du jeu à partir de textures CC0 ou de matériaux procéduraux.

Sources :
- Gabon Media Time, 17 décembre 2025 : https://gabonmediatime.com/libreville-echangeur-diai-le-danger-permanent/
- Reportage vidéo Dailymotion, 2025 : https://www.dailymotion.com/video/x9vwg44
- L'Union, 20 avril 2021 : https://lunion-archives.org/web.11/dmdocuments/N13603-20-04-2021-011.pdf
- L'Union, 12 septembre 2018 : https://lunion-archives.org/web.11/dmdocuments/N12818-12-09-2018-008.pdf
- Gabon Quotidien, novembre 2026 : https://gabon-quotidien.com/inondations-a-iai-libreville-face-aux-limites-de-ses-reponses-durgence/
