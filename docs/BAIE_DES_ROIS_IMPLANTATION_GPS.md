# Implantation GPS — kiosques de la Baie des Rois

## Références retenues

Les captures Capture7.PNG, Capture8.PNG et Capture9.PNG du dossier assets/models/image geographique/ sont les références visuelles prioritaires demandées par le maître du projet. La capture 7 doit notamment servir à comprendre les deux rangées de kiosques qui se font face.

Les trois coordonnées GPS communiquées sont exprimées en latitude, longitude (WGS84).

| Repère | Latitude | Longitude | Rôle |
|---|---:|---:|---|
| P1 | 0.40392567507842964 | 9.431029723961437 | Premier kiosque de la rangée A |
| P2 | 0.4038486056410187 | 9.430125017741204 | Dernier kiosque communiqué de la même rangée A |
| P3 | 0.403847888849537 | 9.431017268453365 | Point supposé sur la rangée opposée, à confirmer avec les captures |

## Conversion avec le repère de world_map.gd

La conversion reprend exactement les constantes du projet : CENTER_LAT = 0.400, CENTER_LON = 9.4475 et METERS_PER_DEG_LAT = 111320.0.

| Repère | X monde (m) | Z monde (m) |
|---|---:|---:|
| P1 | -1833.43 | -437.01 |
| P2 | -1934.14 | -428.43 |
| P3 | -1834.81 | -428.35 |

**Correction importante :** ces valeurs recalculées remplacent les conversions erronées données dans un précédent message. En particulier, P2 et P3 ont un Z proche de -428 m, et non de -445 m.

## Ce que les points permettent déjà d'établir

- La distance P1–P2 est d'environ **101,1 m**.
- L'axe de la rangée A est presque ouest-est, avec une légère composante nord-sud.
- P3 est à environ **8,77 m** de P1.
- En projetant P3 perpendiculairement à l'axe P1–P2, l'écartement indicatif entre les axes des rangées est d'environ **8,51 m**.

Cette dernière valeur est une estimation géométrique issue du point P3, pas une mesure certifiée de la largeur de la voie. P3 doit être vérifié visuellement avec Capture7–9 avant d'en faire une contrainte de placement définitive.

## Règles d'intégration à respecter

1. Ne plus utiliser les anciens offsets approximatifs autour de ANCHOR = Vector3(-1790, 0, -570) pour positionner les kiosques.
2. Reconstituer deux rangées parallèles qui se font face, au lieu de disperser sept copies autour de l'ancienne ancre.
3. Garder une voie ou un passage libre entre les rangées.
4. Prévoir deux variantes architecturales distinctes si les captures montrent bien deux types de kiosques.
5. Déterminer l'orientation de la façade de service à partir des captures et de l'axe de la voie. Le modèle GLB actuel a sa façade de service sur son axe local Y négatif ; cette orientation doit être vérifiée dans Godot avant de multiplier les instances.
6. Ne pas réactiver les anciens générateurs de promenade, d'eau, de pelouse ou de mobilier : ils sont des placeholders et ne constituent pas une implantation validée.

## Helper Godot ajouté

Le script `game/scripts/baie_des_rois_survey.gd` expose maintenant les deux extrémités GPS de la rangée A, son vecteur directeur, le décalage perpendiculaire indicatif vers la rangée B et deux fonctions de calcul paramétrique `row_a_position(progress)` et `row_b_position(progress)`. Il s'agit d'un repère de construction : il ne crée pas encore de kiosques dans la scène. L'orientation des façades reste volontairement non codée tant que les captures n'ont pas été examinées.

## État

Les points GPS fournissent maintenant un premier axe mesurable et un écartement indicatif entre rangées. L'implantation n'est **pas encore validée en jeu** : il faut encore lire visuellement les trois captures, confirmer P3, identifier les deux familles de kiosques, puis faire un contrôle dans Godot.
