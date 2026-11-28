# Architecture multiplateforme — LIBREVILLE STORIES

**Décision produit (2026-11-28)**

- Cibles : Windows, Linux, PlayStation 4, PlayStation 5, Xbox One, Xbox Series S et Xbox Series X.
- Mode de lancement : solo.
- Multijoueur : prévu pour une version ultérieure ; aucune dépendance réseau obligatoire pour le mode solo.
- Moteur de référence actuel : Godot 4.3. Ne pas changer de version du moteur sans campagne de validation complète.

## 1. Règle d'architecture

Le gameplay ne doit jamais dépendre directement d'un périphérique, d'un système d'exploitation ou d'une API console. Les scripts de gameplay lisent des actions abstraites (move_forward, interact, vehicle_accelerate, etc.). Les couches plateforme fournissent les entrées, les services système et les réglages adaptés.

Dépendances autorisées :
1. Gameplay et simulation -> interfaces de services abstraites.
2. Adaptateurs de plateforme -> implémentations des services.
3. Interface -> actions abstraites et profil de périphérique, jamais des codes de touches codés en dur.

Ne pas introduire de SDK Sony/Microsoft dans le dépôt public. Les SDK, clés, certificats, identifiants partenaires et fichiers fournis sous NDA restent dans l'environnement privé autorisé.

## 2. Cibles et faisabilité du portage

| Cible | Statut de préparation |
|---|---|
| Windows | Export Godot standard à maintenir |
| Linux | Export Godot standard à maintenir |
| PlayStation 5 | Portage tiers/outil sous licence et SDK Sony requis |
| Xbox Series X/S | Portage tiers/outil sous licence et SDK Microsoft requis |
| PlayStation 4 | À confirmer avec un prestataire : disponibilité d'un port Godot 4 compatible PS4, version moteur et limites mémoire |
| Xbox One | À confirmer avec un prestataire : disponibilité d'un port Godot 4 compatible Xbox One, version moteur et limites mémoire |

**Important :** Godot ne fournit pas de modèles d'export console officiels publics. L'approbation du constructeur, les SDK/devkits et un portage compatible sont nécessaires. Les offres de middleware publiquement référencées ne garantissent pas automatiquement PS4 et Xbox One. Avant de promettre ces deux versions, obtenir une confirmation écrite du prestataire concernant les générations legacy, Godot 4.3, le rendu, les plugins et le support.

Référence : https://godotengine.org/consoles/

## 3. Couches à maintenir

### A. Entrées — InputMap et InputConfig

- Conserver une seule action logique pour chaque intention de jeu.
- Ajouter les événements manette dans les actions existantes ; ne pas créer un chemin gameplay séparé PlayStation et Xbox.
- Ajouter les actions manquantes : interaction, pause, carte, menu, caméra, frein à main, klaxon et navigation UI.
- Axes analogiques avec zones mortes configurables ; gâchettes analogiques pour accélérateur et frein.
- Détecter le dernier périphérique utilisé pour basculer les pictogrammes clavier / PlayStation / Xbox.
- Prévoir remappage, restauration par défaut, inversion des axes, sensibilité caméra et vibration désactivable.
- Le menu, les dialogues, les inventaires et les paramètres doivent être entièrement navigables à la manette, sans souris obligatoire.

### B. Interface et affichage

- UI adaptative aux résolutions TV et moniteur, zones de sécurité TV et tailles de texte réglables.
- Navigation focus-first : ordre de focus explicite, retour arrière cohérent, focus visible.
- Icônes de boutons fournies en ressources séparées par famille de contrôleurs ; ne pas écrire X ou A en dur dans les textes.
- Pause, chargement, erreurs et confirmations utilisables sans clavier.
- Prendre en charge les changements de résolution et le plein écran uniquement sur les plateformes qui l'autorisent.

### C. Services système

Créer des interfaces internes stables pour :
- SaveService : sauvegarde locale, emplacement fourni par la plateforme, version de schéma et migrations.
- SettingsService : paramètres graphiques, audio, commandes et accessibilité.
- PlatformService : nom de plateforme, capacités, fermeture/pause/reprise, espace disque si disponible.
- InputGlyphService : famille de manette et pictogrammes.
- AchievementService : interface neutre, inactive en solo si aucun service plateforme n'est configuré.
- NetworkService : interface future, désactivée par défaut en version solo.

Ne pas coder de chemin de sauvegarde absolu ni supposer que l'accès aux fichiers est identique sur PC et console. Sauvegarder de façon atomique (fichier temporaire puis remplacement), prévoir plusieurs emplacements de sauvegarde et vérifier l'intégrité au chargement.

### D. Monde ouvert et ressources

- Streaming par secteurs/quartiers, avec budgets de mémoire et de temps de chargement par cible.
- Chargement/déchargement des PNJ, véhicules, sons et décors selon la distance et la priorité gameplay.
- LOD, occlusion, instancing et collisions simplifiées à distance.
- Textures avec mipmaps et variantes de résolution ; conserver les sources haute qualité, produire des variantes importées adaptées.
- Limiter les allocations et les ressources simultanées ; surveiller les pics mémoire, pas seulement la moyenne FPS.
- Aucun contenu hors du périmètre Libreville validé ne doit être ajouté par le système de streaming.

### E. Rendu et shaders

- Garder le renderer Compatibility comme référence de compatibilité tant que les tests matériels ne justifient pas un changement.
- Éviter les dépendances aux fonctionnalités exclusives d'un renderer ou à des shaders non portables.
- Fournir des variantes de shaders simples pour eau, pluie, surfaces mouillées, végétation et matériaux.
- Définir les options graphiques par capacités détectées et profils validés, pas seulement par le nom commercial de la plateforme.
- Ne pas promettre 60 FPS partout avant mesure sur matériel réel. Cibles initiales à tester : 30 FPS stables sur profils qualité et 60 FPS lorsque le budget CPU/GPU le permet.

## 4. Profils de performance à mesurer

Les profils sont des plafonds de qualité, pas une réduction de la qualité des assets sources.

- PC bas/moyen/haut : options détaillées et réglages personnalisables.
- PS4 / Xbox One : profil legacy à confirmer, budgets mémoire/CPU/GPU les plus contraints.
- PS5 / Xbox Series S : profil current-gen équilibré, calibré séparément pour Series S.
- Xbox Series X : profil current-gen haute qualité.

Mesures obligatoires : FPS moyen et 1 % low, temps CPU/GPU, mémoire RAM/VRAM, temps de chargement, nombre de PNJ/véhicules actifs, taille des shaders et stabilité sur session longue.

## 5. Préparation au multijoueur futur sans le développer maintenant

La version initiale reste entièrement jouable hors ligne. Pour éviter une refonte ultérieure :

- Attribuer des identifiants stables aux entités persistantes (joueur, PNJ, véhicule, objet, mission).
- Séparer simulation, rendu, interface et stockage.
- Centraliser les transitions d'état importantes (mission, inventaire, véhicule, santé, monde).
- Enregistrer les états persistants plutôt que les références de nœuds de scène.
- Éviter les dépendances à l'heure locale système pour la simulation ; utiliser l'horloge du monde.
- Concevoir les actions de gameplay comme des commandes explicites et validables.
- Garder la simulation déterministe autant que raisonnablement possible, sans promettre une synchronisation déterministe complète du moteur physique.
- Ne pas ajouter de serveur, matchmaking, comptes en ligne, réplication ou dépendance cloud avant la phase multijoueur.

Quand le multijoueur sera lancé, décider d'une architecture serveur autoritaire, de la persistance, de l'anti-triche, des coûts d'hébergement et du jeu croisé avant d'implémenter le réseau.

## 6. CI et validation

À chaque changement gameplay ou plateforme :
1. Importer le projet avec la version Godot verrouillée.
2. Vérifier les erreurs de parsing GDScript et l'import des ressources.
3. Exécuter les tests automatisés de données et de scripts.
4. Construire les exports PC Windows et Linux.
5. Vérifier les scènes principales, commandes clavier/manette, sauvegarde/chargement et reprise après pause.
6. Pour les consoles, exécuter les builds et tests uniquement dans l'environnement privé approuvé, avec les SDK et devkits autorisés.

Les builds console ne doivent pas être simulés par un export PC et déclarés certifiés.

## 7. Ordre de réalisation

1. Inventorier les scripts qui lisent directement les touches ou boutons.
2. Compléter l'InputMap et tester une manette Xbox et une manette PlayStation sur PC.
3. Rendre tous les menus et interfaces navigables à la manette.
4. Introduire les services abstraits de sauvegarde, paramètres et plateforme.
5. Versionner les sauvegardes et tester les migrations.
6. Ajouter les budgets de streaming, mémoire et rendu par profil.
7. Contacter les prestataires pour confirmer PS4, PS5, Xbox One et Series, les versions Godot supportées, les coûts et les délais.
8. Obtenir les programmes développeur, SDK et devkits après acceptation.
9. Réaliser les portages, tests matériels, accessibilité, conformité et certification.

## 8. Règles de contribution

- Ne pas supprimer ni déplacer les assets du monde pour créer des builds console.
- Ne pas remplacer les assets haute qualité par des assets basse qualité ; générer des variantes.
- Ne pas ajouter de SDK propriétaire, secret ou fichier NDA au dépôt.
- Chaque nouvelle fonctionnalité doit être testable au clavier et à la manette.
- Toute modification du moteur, du renderer ou des plugins doit être évaluée sur PC bas de gamme et sur les cibles console envisagées.
