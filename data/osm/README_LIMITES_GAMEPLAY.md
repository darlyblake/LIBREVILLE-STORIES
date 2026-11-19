# Limites de gameplay — Libreville

## Fichiers générés

- `neighbourhoods.geojson` : 72 cellules de quartiers/secteurs jouables.
- `arrondissements.geojson` : 6 secteurs d'arrondissement, construits par agrégation des cellules précédentes.
- `localities.geojson` : données OSM d'origine conservées comme points de référence.

## Méthode

Les cellules sont générées par partition de Voronoï à partir des points `place` présents dans `localities.geojson`. Elles couvrent l'enveloppe convexe des localités recensées, légèrement élargie pour éviter des cellules trop serrées autour des points extérieurs.

Chaque cellule reçoit un arrondissement de gameplay à partir d'une correspondance géographique et documentaire des noms. Les six polygones d'arrondissement sont ensuite constitués par agrégation des cellules qui leur sont affectées. Ainsi, aucun secteur recensé ne reste sans arrondissement et les limites des arrondissements correspondent exactement à la somme des secteurs de quartier.

## Correspondance des secteurs de gameplay

- **1er arrondissement** : Louis, Vallée Sainte-Marie, Plaine Orety, Quaben, Akémindjogoni, Batterie 4, Baie des Rois, Derrière la Prison, Bas de Gué-Gué, Haut de Gué-Gué, Trois quartiers, Camp des Boys, Charbonnages, Montagne Sainte, Centre-Ville.
- **2e arrondissement** : Atong Abe, Atong-Abe, Atsib-tchoss, Cocotiers, Sotega, Ancien Sobraga, N'kembo, Avea, Cité Mébiame, Cité de la Démocratie, Campagne.
- **3e arrondissement** : Akébé Plaine, Akébé-Ville, Likouala-Moussaka, Petit Paris, Belle-Vue, Derrière l'Hôpital, Mont Bouet, Sorbonne, Venez-Voir, Peyrie, STFO, Akébé-Kinguélé, Kosmoparc.
- **4e arrondissement** : Glass, Plaine Niger, Michel Marine, London, Nombakele, Toulon, Ambilambani, Batavéa, Awendjé, Baraka-Mission, Oloumi, Zone Industrielle d'Oloumi, Akébé Frontière-Baraka.
- **5e arrondissement** : Lalala-Dakar, Lalala-Droite, Lalala-Gauche, Mindoube 1, Institut des Sports, Smag, I.A.I-Golf, Ozangué, Beau-Séjour, Cité Damas, Plein-ciel, Mindoubé 2, RIO, PK5, Bassin du PK5.
- **6e arrondissement** : Sibang, Terre-Nouvelle, Cité de la Caisse, Nzeng Ayong, Cité des Ambassadeurs.

## Règles importantes

- Ces limites sont des **limites de gameplay**, pas des limites administratives officielles.
- Le point OSM « Libreville » est un repère de ville et n'est pas traité comme un quartier.
- Les deux variantes « Atong Abe » et « Atong-Abe » sont conservées car elles ont deux points OSM ; elles sont signalées comme alias dans les propriétés.
- Des lieux comme Baie des Rois, Institut des Sports, Zone Industrielle d'Oloumi, Centre-Ville et RIO sont conservés comme secteurs jouables, même s'ils ne sont pas tous des quartiers administratifs.
- Les cellules ne suivent pas encore les routes, les rivières, le littoral, les bâtiments ou les espaces verts. L'étape suivante sera de déformer/recouper ces cellules avec ces éléments pour obtenir des limites plus naturelles et améliorer les téléporteurs.
- Ne pas afficher ces polygones comme une vérité administrative dans l'interface du jeu.

## Contrôle

Les fichiers sont en GeoJSON / EPSG:4326. Ils peuvent être ouverts directement dans QGIS. Les champs `arrondissement_id`, `arrondissement`, `boundary_status`, `official_boundary`, `confidence` et `source` permettent de filtrer et d'identifier les contours générés.
