# Sources géographiques et licences — Libreville Stories

Ce document distingue les sources identifiées, les données déjà intégrées au jeu et les acquisitions qui restent à faire.

## Sources déjà utilisées

### OpenStreetMap
Les routes, empreintes de bâtiments, points d'intérêt, localités et éléments environnementaux actuellement présents dans `data/osm/` proviennent du pipeline OSM du projet.
- Licence : Open Database License (ODbL).
- Conserver l'attribution OpenStreetMap et les mentions de base de données dérivée dans le jeu et sa documentation.
- Les attributs absents d'OSM ne doivent pas être inventés : largeur, surface, hauteur, matériaux et noms doivent rester estimés/indéterminés si les tags sont absents.

## Sources identifiées pour enrichir le terrain

### Copernicus DEM GLO-30
- Page officielle : https://dataspace.copernicus.eu/explore-data/data-collections/copernicus-contributing-missions/collections-description/COP-DEM
- Couverture mondiale, résolution annoncée de 30 m.
- Modèle numérique de surface (DSM), pas un modèle de terrain nu : végétation et bâtiments peuvent influencer les altitudes.
- Licence d'utilisation GLO-30 gratuite et ouverte selon les conditions Copernicus.
- Attribution à conserver lors de la redistribution : « produced using Copernicus WorldDEM-30 © DLR e.V. 2010-2014 and © Airbus Defence and Space GmbH 2014-2018 provided under COPERNICUS by the European Union and ESA; all rights reserved ».
- Statut projet : source repérée, aucun raster Libreville n'est encore intégré.

### ESA WorldCover 2021
- Accès officiel : https://esa-worldcover.org/en/data-access
- Résolution annoncée : 10 m ; classes d'occupation du sol dont végétation, zones bâties, eau et mangroves.
- Licence : Creative Commons Attribution 4.0 International (CC BY 4.0).
- Attribution cartographique : « © ESA WorldCover project 2021 / Contains modified Copernicus Sentinel data (2021) processed by ESA WorldCover consortium ».
- Statut projet : source repérée, aucun raster Libreville n'est encore intégré.

### Institut National de Cartographie du Gabon
- Produits présentés : orthophotoplans des villes, plans urbains et prises de vues aériennes.
- Pages : https://incgabon.ga/nos-produits et https://www.incgabon.ga/108-expertises/241-nos-prestations/307-orthophotographie-de-libreville-sud/
- Contact publié : infos@incgabon.gouv.ga ; (+241) 61 00 39 04.
- Statut projet : piste prioritaire pour des références locales ; demander disponibilité, prix, date, précision, emprise et droits de réutilisation avant toute intégration.

## Règles d'intégration
1. Ne pas transformer une image satellite en texture du monde sans vérifier sa date, sa résolution, sa projection et ses droits.
2. Reprojeter les rasters dans un système métrique adapté à Libreville avant de construire le terrain Godot.
3. Vérifier l'alignement du raster avec les coordonnées OSM et la boîte géographique du jeu.
4. Garder une version source, une version préparée et une fiche d'attribution pour chaque donnée ajoutée.
5. Ne jamais présenter les limites de quartiers non vérifiées comme des limites officielles.

## État
Les références ci-dessus ont été identifiées, mais aucune donnée raster externe n'a encore été téléchargée ni intégrée au dépôt. La texture actuelle du sol reste une variation procédurale de présentation, pas une reproduction satellite.
