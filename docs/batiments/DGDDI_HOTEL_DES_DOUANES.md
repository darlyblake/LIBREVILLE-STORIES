# Fiche de modélisation — Hôtel des Douanes (DGDDI)

**Projet :** LIBREVILLE STORIES  
**Cible :** Godot 4.3 / GLB  
**Priorité :** Lot administratif 1  
**État :** adresse officielle et références visuelles publiques identifiées ; modèle 3D non encore produit ni validé dans Godot.

## 1. Identification et implantation

- Nom à afficher : **Hôtel des Douanes — Direction Générale des Douanes et Droits Indirects (DGDDI)**.
- Adresse institutionnelle actuelle : **823, avenue Nelson Mandela, Zone industrielle d'Oloumi, Libreville, Gabon**.
- Référence cartographique du plan principal : OSM node **12727052424**.
- Coordonnées enregistrées dans l'inventaire : **0.37618, 9.46677**.
- L'adresse est confirmée par le site officiel des Douanes. Les coordonnées restent celles de l'objet OSM ; elles ne désignent pas nécessairement l'entrée.
- Le bâtiment physique doit être associé à son empreinte existante dans `data/osm/extended/buildings.geojson`. Ne pas créer une géométrie concurrente.

## 2. Références publiques et observations visuelles

### Source institutionnelle principale
- Site officiel — organisation et adresse de l'Hôtel des Douanes : https://douanes.ga/
- Adresse publiée : Hôtel des Douanes, 823 avenue Nelson Mandela, Z.I. Oloumi, BP 40, Libreville.
- Le site précise que la Direction générale et plusieurs services centraux sont regroupés à l'Hôtel des Douanes.

### Photographies du bâtiment
- Rapport institutionnel DGDDI « Performances » : https://www.douanes.ga/med/pdf/performances-min-230929074648.pdf
- Rapport d'activité DGDDI 2021 : https://www.douanes.ga/med/pdf/dgddi-rapport-d-activite-2021-220921100917.pdf
- Document « Commerce extérieur et résultats de la fiscalité douanière » : https://douanes.ga/med/pdf/dgddi-commerce-exterieur-2021-220921100850.pdf

Les couvertures de ces documents présentent une photographie de l'Hôtel des Douanes. Les vues publiées permettent d'identifier une architecture administrative contemporaine, plusieurs niveaux, une façade largement vitrée, une clôture métallique et des palmiers devant l'entrée. Il faut ouvrir les documents originaux et comparer les vues avant de relever les détails de façade.

**Droits :** les photographies institutionnelles ne deviennent pas libres de réutilisation parce qu'elles sont publiées sur un site officiel. Les utiliser comme références visuelles uniquement, sauf autorisation explicite. Recréer les matériaux du jeu avec des ressources CC0 et des teintes observées.

## 3. Cahier des charges visuel

- [ ] Extraire/consulter les vues originales de la façade dans les rapports institutionnels.
- [ ] Collecter une vue récente de face et une vue oblique.
- [ ] Collecter une vue latérale et, si possible, une vue aérienne.
- [ ] Relever le nombre exact de niveaux visibles.
- [ ] Relever la trame des baies vitrées, les parties opaques et les éventuels volumes en retrait.
- [ ] Relever l'entrée principale, le portail, la clôture et les accès véhicules.
- [ ] Confirmer les matériaux, les teintes et les éléments de signalétique.
- [ ] Confirmer la position du bâtiment dans l'empreinte OSM locale.

Ne pas inventer de nombre d'étages, de dimensions ou de détails architecturaux non lisibles sur les références.

## 4. Découpage Blender recommandé

Organiser le GLB en éléments faciles à optimiser :
- `DGDDI_Structure` — volumes principaux et dalles ;
- `DGDDI_FacadeOpaque` — murs et panneaux opaques ;
- `DGDDI_Glazing` — fenêtres et vitrages ;
- `DGDDI_Frames` — cadres et montants ;
- `DGDDI_Entrance` — entrée et auvent, si visibles ;
- `DGDDI_Roof` — acrotères et équipements visibles ;
- `DGDDI_Fence` — clôture et portail, si inclus dans les références ;
- `DGDDI_Landscape` — palmiers et plantations uniquement si leur présence est confirmée ;
- `DGDDI_Collision` — volumes de collision simples.

Les noms définissent l'organisation de travail, pas la présence garantie de chaque élément sur le site réel.

## 5. Matériaux

- Façade opaque : enduit/béton peint, teinte à relever.
- Vitrage : matériau Godot dédié, reflets contrôlés, transparence limitée.
- Menuiseries : aluminium ou métal peint selon les photographies.
- Clôture : métal peint avec géométrie légère.
- Sol extérieur : béton et asphalte selon les zones visibles.
- Végétation : assets légers et optimisés, uniquement si la composition réelle est confirmée.

Textures PBR CC0 disponibles via le script du dépôt :
```bash
python3 tools/download_cc0_textures.py --resolution 2k
```
Matériaux de départ possibles : `concrete_wall_009`, `white_plaster_02`, `concrete_floor_01`, `metal_plate_02`, `asphalt_03`. Le choix final doit suivre les photos.

## 6. Intégration et performance

- Blender en unités métriques, transformations appliquées.
- Pivot et orientation documentés par rapport au nord et au repère monde.
- Export glTF 2.0 / GLB.
- Réutiliser les mêmes matériaux pour les surfaces répétitives.
- Réduire les subdivisions des cadres et garde-corps éloignés.
- Créer une collision simple et un LOD distant.
- Attacher le GLB à l'empreinte existante ; ne pas ajouter un deuxième bâtiment.
- Tester l'alignement, la hauteur au sol, les collisions et le rendu sur la configuration graphique cible.

## 7. Suivi de production

- [x] Adresse officielle confirmée.
- [x] Identifiant OSM présent dans le plan du jeu.
- [x] Références photographiques institutionnelles repérées.
- [ ] Vues multi-angles comparées et relevé architectural terminé.
- [ ] Empreinte et orientation vérifiées dans le GeoJSON local.
- [ ] Blocage Blender créé.
- [ ] Modèle détaillé terminé.
- [ ] Matériaux PBR affectés.
- [ ] GLB exporté.
- [ ] GLB intégré à Godot.
- [ ] Contrôle visuel en jeu validé.

## 8. Historique

- 2026-11-26 : création de la fiche DGDDI à partir de l'adresse institutionnelle et des rapports publics illustrés. La façade vitrée, les niveaux, la clôture et les palmiers sont des éléments visibles dans les références de couverture ; le modèle reste à construire.
