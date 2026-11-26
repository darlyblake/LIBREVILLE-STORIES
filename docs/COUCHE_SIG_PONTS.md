# Couche SIG des ponts — extraction dédiée

Mise à jour : 26 novembre 2026

## Pourquoi une couche distincte ?

Jusqu'ici, les voies OSM étaient exportées dans `roads.geojson`. Cette couche contient les routes et leurs attributs, mais les ouvrages d'art étaient difficiles à inventorier indépendamment. Un objet `man_made=bridge` sans attribut `highway` pouvait notamment être absent de la couche routière, même si l'extracteur avait déjà récupéré ses tags.

Le générateur `tools/map-generator/extract_libreville.py` produit désormais aussi `bridges.geojson`, avec :
- les ways portant explicitement `bridge=*` ;
- les ways portant `man_made=bridge` ;
- l'identifiant OSM, les tags originaux et la géométrie coupée à l'emprise d'extraction.

Le fichier est généré dans le dossier configuré par l'extracteur : `data/osm/bridges.geojson` ou `data/osm/extended/bridges.geojson`.

## Limites géométriques

Cette couche est un inventaire SIG de tracés OSM, pas un modèle 3D :
- `layer=1` ou `layer=2` exprime une relation topologique, pas une hauteur en mètres ;
- `bridge=yes` ne donne pas la hauteur du tablier, le nombre de piles ou le profil des rampes ;
- `man_made=bridge` peut représenter un axe ou une emprise cartographique, selon l'objet source ;
- les coordonnées doivent être croisées avec les routes, le relief et les limites des secteurs jouables.

Aucune élévation, largeur, pile ou rampe n'est générée par ce nouvel export.

## Contrôle qualité

`tools/map-generator/validate_extended_osm.py` reconnaît maintenant `bridges.geojson` et contrôle :
- les types de géométrie autorisés ;
- les géométries invalides ou vides ;
- les objets hors emprise ;
- les géométries manquantes.

La couche est optionnelle pour les anciens jeux de données ; elle sera contrôlée automatiquement dès qu'une extraction l'aura créée.

## Prochaine étape SIG

Après la prochaine extraction OSM, produire un tableau de rapprochement par ouvrage :
1. way du pont ;
2. routes supérieures et inférieures associées ;
3. secteur(s) jouable(s) traversé(s) ;
4. tags disponibles et champs absents ;
5. statut de vérification terrain / photo / plan ;
6. décision : modélisable métriquement ou encore en attente.

## Attribution

© OpenStreetMap contributors — ODbL 1.0. Conserver l'attribution et respecter les obligations de partage à l'identique applicables aux bases dérivées.
