# Générateur cartographique

Le dépôt contient un premier jeu de données OpenStreetMap contrôlé dans `data/osm/`.

- `roads.geojson` : lignes de routes et chemins.
- `buildings.geojson` : empreintes de bâtiments.
- `extraction-report.json` : compteurs, emprise et attribution.

Le script `extract_libreville.py` permet de rafraîchir ces données avec Overpass, mais les serveurs publics peuvent être indisponibles ou ralentis. La version vérifiée initiale doit rester disponible si une nouvelle extraction échoue.

La génération 3D est réalisée par `game/scripts/world_map.gd`. Le script construit des meshes groupés à partir des deux GeoJSON.

Source et attribution : © OpenStreetMap contributors — ODbL 1.0.
