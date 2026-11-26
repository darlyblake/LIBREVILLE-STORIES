# Marché de Mont-Bouët — références de reconstruction

## Statut dans le jeu

Le marché est placé sur le repère OSM/Wikidata du nœud marché :
- Latitude : 0.40125
- Longitude : 9.45192
- OSM node : 14082088074
- Référence cartographique : https://mapcarta.com/fr/N14082088074

Le modèle actuel de `game/scripts/libreville_districts.gd` est un **blockout de gameplay**. La grille 3 × 7 d'étals n'est pas une empreinte réelle, un plan d'architecte ni une restitution mesurée. Elle ne doit pas être présentée comme la géométrie exacte du marché.

## Références documentaires et visuelles

1. **Photographie récente avec position GPS et orientation**
   - Fichier : https://commons.wikimedia.org/wiki/File:March%C3%A9_de_Mont_Bouet.jpg
   - Auteur : Estrella230, photo prise le 5 janvier 2026.
   - Position de prise de vue : 0.400633, 9.450956.
   - Cap indiqué : 38.14°.
   - Licence : CC BY-SA 4.0. Attribution obligatoire si l'image est réutilisée ou adaptée ; partager les adaptations sous licence compatible.
   - Usage dans le projet : référence de terrain et de densité, pas texture intégrée automatiquement.

2. **Vue de rue du marché**
   - https://socgeo.com/wp-content/uploads/2019/12/La-G%C3%A9ographie-1542-lAfrique.pdf
   - Montre une rue de marché dense, des parasols multicolores, des commerces bas, des véhicules et des réseaux aériens.
   - Usage : référence d'ambiance et de composition urbaine. Les droits de réutilisation doivent être vérifiés avant toute incorporation d'image.

3. **Description des structures historiques du marché**
   - https://www.memoireonline.com/11/19/11269/m_Logiques-d-amenagement-d-un-marche-urbain-ou-construction-du-risque-environnemental-L-exemple-du3.html
   - L'étude décrit un bâtiment central à deux niveaux, donné pour plus de 7 000 m², et plusieurs hangars ajoutés pour environ 400 places.
   - Ces données décrivent l'état documenté par l'étude (travail universitaire de 2009), pas nécessairement l'état exact de 2026.

4. **Typologie des étals**
   - https://www.memoireonline.com/11/19/11269/m_Logiques-d-amenagement-d-un-marche-urbain-ou-construction-du-risque-environnemental-L-exemple-du.html
   - Décrit des tables de vente en bois, des étals maçonnés ou non, isolés ou groupés, couverts ou non, parfois par parasols, nattes ou tôles.
   - Usage : définir plusieurs familles d'étals plutôt que répéter un seul modèle.

5. **État et organisation des boutiques**
   - https://union.sonapresse.com/index.php/fr/node/26729
   - Article sur la fermeture hebdomadaire et le nettoyage ; mentionne façades de boutiques colorées, rideaux métalliques, numéros d'échoppes, étals rangés et ventilateurs.
   - Usage : façades, rideaux, numérotation et accessoires de boutiques.

6. **Projet de centre commercial annoncé en 2026**
   - https://www.focusgroupemedia.com/libreville-le-chantier-du-futur-centre-commercial-de-mont-bouet-sous-la-loupe-des-autorites-municipales/
   - Article du 10 juin 2026 : projet décrit avec deux bâtiments R+3, magasins, boxes en sous-sol, parking et sanitaires.
   - Ce projet doit être représenté séparément de l'existant, uniquement après vérification de son emprise, de ses plans et de son état réel sur la carte du jeu.

## Décisions artistiques fondées

- Conserver des familles visuelles distinctes : béton, rideaux métalliques, bois, tôle ondulée, bâches, parasols, étals au sol.
- Varier les structures : bâtiment commercial à plusieurs niveaux, hangars ouverts, boutiques en façade et étals temporaires.
- Prévoir une densité importante de piétons, vendeurs, marchandises et circulation, sans bloquer toutes les allées.
- Employer les textures PBR CC0 de Poly Haven comme matériaux génériques ; ne pas les présenter comme des scans photographiques des matériaux locaux.
- Garder la patine métallique localisée ; ne pas rouiller uniformément toutes les structures.

## Informations encore nécessaires avant reconstruction fidèle

- Empreintes exactes des bâtiments et hangars depuis OSM/orthophoto exploitable.
- Limites réelles du marché et alignement des allées.
- Dimensions mesurées ou plans vérifiables du bâtiment central et des hangars.
- Plans et position précise du nouveau centre commercial, avec distinction claire entre projet et existant.
- Photos autorisées, à résolution suffisante, des façades, toitures, rideaux, parasols et étals.

**Règle de production :** ne pas transformer les dimensions historiques ou les descriptions journalistiques en coordonnées, mesures ou formes 3D non vérifiées.
