# Repères du front de mer — monument et tribune

## Références architecturales consultées

- Ministère gabonais des Travaux publics, visite du chantier du 4 octobre 2025 : le monument est décrit comme un arc de triomphe principal d'environ 30 m, surmonté d'une structure supérieure ; huit pavillons latéraux représentent les huit autres provinces, le bâtiment central représentant l'Estuaire. La promenade annoncée fait environ 400 m.
  - https://www.infrastructures.gouv.ga/9-actualites/1332-edgard-moukoumbi-en-visite-ce-samedi-04-octobre-2025-sur-les-chantiers-du-camp-de-gaulle-et-de-l-esplanade-georges-damas-aleka/
- Présidence de la République gabonaise, note du 8 août 2026 : confirmation des huit pavillons provinciaux, du bâtiment central de 30 m et de l'inscription des paroles de l'hymne sur les piliers.
  - https://presidence.ga/2026/08/08/esplanade-georges-damas-aleka-le-president-de-la-republique-presente-sa-vision-memorielle-a-la-famille-du-defunt/
- Agence Gabonaise de Presse, inauguration du 17 août 2026 : le monument comprend un musée, une stèle mémorielle et neuf pavillons au total.
  - https://agpgabon.ga/gabon-independance-an-66-oligui-nguema-inaugure-la-place-georges-damas-aleka/
- Le360 Afrique, reportage du 29 août 2026 : donne une hauteur totale annoncée d'environ 47 m et une emprise d'environ 4 000 m².
  - https://afrique.le360.ma/societe/gabon-de-lacier-et-du-beton-pour-immortaliser-georges-damas-aleka-lauteur-de-lhymne-national_LGW5ZNPSZZG6VCRXI3ZLQFYVJY/
- Wikimedia Commons, photographie de la plaque commémorative, prise le 22 août 2026, sous licence CC BY-SA 4.0. Elle sert de référence pour les inscriptions, pas de texture de façade.
  - https://commons.wikimedia.org/wiki/File:Monument_Georges_Damas_Aleka_au_Gabon.jpg
- Getty/iStock, photographie de la tribune officielle du front de mer (30 août 2014) : référence visuelle pour la façade jaune nervurée, la toiture à dents de scie et la structure sombre sous couverture. Image consultée comme référence, non copiée dans le jeu.
  - https://www.gettyimages.com/

## Décisions de reconstruction dans Godot

### Monument Georges-Damas-Aleka

- Implantation conservée dans `game/scripts/libreville_landmarks.gd`, au repère GPS déjà enregistré dans le dépôt.
- L'ancien linteau rectangulaire a été remplacé par un arc elliptique extrudé, avec deux jambages, une ouverture traversante et des normales générées.
- L'arc principal atteint 30 m au sommet ; une charpente supérieure métallique courbe monte jusqu'à environ 47 m au total, en cohérence avec le reportage Le360. Les sources publiques ne donnent pas un plan d'exécution coté : cette géométrie est donc une reconstruction visuelle documentée, pas un relevé d'architecte.
- Le musée est placé en retrait pour préserver la lecture du vide central.
- Les huit pavillons latéraux portent maintenant les noms des huit provinces hors Estuaire.
- Les matériaux minéraux sont procéduraux (grain, variations de rugosité) et ne réutilisent pas de photographie protégée.
- Des collisions sont ajoutées aux jambages, à l'arc et au volume du musée.

### Tribune officielle

- Conservation de la silhouette jaune, de la façade verticale nervurée et de la couverture en dents de scie, éléments visibles dans la référence photographique.
- Les gradins sont détaillés avec des sièges individuels instanciés par MultiMesh, répartis de part et d'autre d'une allée protocolaire rouge.
- Les supports et les rangées sont groupés pour limiter les appels de rendu.

## Limites et validation

- Les dimensions exactes des pavillons et de la tribune ne sont pas publiées dans les sources consultées. Les proportions secondaires sont des estimations visuelles.
- Le fichier de référence photographique de Wikimedia montre la plaque commémorative, pas une élévation complète du monument.
- Aucun rendu ne doit être qualifié de photoréaliste avant ouverture et inspection dans Godot sur la configuration cible.
- La validation requise couvre : compilation des scripts, absence d'erreurs de shader, collision du passage sous l'arc, absence de sièges dans l'allée centrale, lisibilité des inscriptions, implantation GPS et performances sur Intel UHD 620 / GT 730.

## Licence et attribution

Aucune photographie d'actualité ou de presse n'est embarquée comme texture du jeu. Les photos servent à l'étude de formes et de proportions. Si la photo Wikimedia est un jour intégrée au jeu, conserver l'attribution DiHM et la licence CC BY-SA 4.0, et publier toute adaptation sous une licence compatible.
