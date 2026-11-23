# Textures nécessaires aux monuments de Libreville

## Déjà présentes et affectées dans le jeu
- `rock_face_01_diff_4k.jpg`, `rock_face_01_nor_gl_4k.jpg`, `rock_face_01_arm_4k.jpg`: pierre des socles, plinthes et éléments minéraux du monument Georges-Damas-Aleka et de la Stèle de la Liberté.
- `rock_face_02_diff_4k.jpg`, `rock_face_02_nor_gl_4k.jpg`, `rock_face_02_arm_4k.jpg`: dalles et parvis minéraux.
- Les textures de sol, d'asphalte et d'océan restent réservées à leurs surfaces respectives ; elles ne sont pas appliquées aux façades.

## À ajouter pour une finition fidèle
Déposer chaque matériau dans `assets/models/materials/architecture/<nom_du_materiau>/` avec ses cartes PBR :
- **Béton architectural clair** : albedo/base color, normal OpenGL, roughness, ambient occlusion.
- **Béton blanc / enduit minéral** : albedo, normal, roughness, AO.
- **Métal peint jaune** (tribune officielle) : albedo, normal, roughness, metallic/AO.
- **Acier sombre peint** (charpente, meneaux et éléments structurels) : albedo, normal, roughness, metallic.
- **Verre architectural** : texture de teinte/transmission ou matériau transparent dédié ; pas une simple image opaque.
- **Pierre claire / marbre** pour la Stèle de la Liberté : albedo, normal, roughness, AO.
- **Métal de chaîne patiné** pour les chaînes de la Stèle : albedo, normal, roughness, metallic.

Format recommandé : cartes 1K ou 2K pour la cible GT 730 ; fournir les cartes Normal OpenGL (GL), pas DirectX (DX), et indiquer clairement les noms des cartes dans le dossier.
