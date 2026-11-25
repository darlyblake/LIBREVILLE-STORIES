# LIBREVILLE STORIES — Fonctionnement de la police dans l'univers du jeu

> Bible des acteurs et des comportements — version 1.0  
> Statut : référence narrative et règles de simulation  
> Univers : Gabon contemporain fictif, principalement Libreville et ses environs  
> Ce document décrit ce que la police fait dans le monde du jeu. Il ne constitue pas un plan d'implémentation Godot.

---

## 1. Vision générale

Dans LIBREVILLE STORIES, la police est un acteur permanent de la société, mais elle n'est ni omniprésente ni réduite à une mécanique de poursuite. Elle circule, contrôle, observe, intervient, enquête, interpelle et reprend ses activités. Elle fait partie du quotidien de la ville.

La représentation s'inspire du vécu urbain gabonais décrit pour le projet : contrôles routiers, vérifications d'identité, patrouilles mobiles, véhicules de transport de policiers de type Iveco, 4x4 blancs, voitures ordinaires, contrôles plus visibles la nuit et contrôles des activités commerciales le matin. Ces éléments sont transposés dans une fiction. Les horaires, fréquences, procédures, personnages et opérations du jeu ne prétendent pas décrire uniformément les pratiques réelles de toutes les unités au Gabon.

La règle fondamentale est la suivante :

**La police agit à partir de ce qu'elle voit, de ce qu'on lui signale, de ce qu'elle peut vérifier et des moyens dont elle dispose. Elle ne sait pas automatiquement où se trouve le joueur.**

Le système doit raconter une société crédible : certains agents sont professionnels, d'autres stricts, certains peuvent être abusifs ou corrompus. Aucun de ces comportements ne représente à lui seul toute l'institution.

## 2. Place de la police dans l'histoire principale

Le protagoniste commence comme un jeune civil gabonais confronté à des difficultés familiales, scolaires et financières. Il cherche des moyens de s'en sortir, travaille notamment sur des chantiers et découvre progressivement différents milieux sociaux. La police ne doit donc pas être une menace permanente dès les premières minutes.

Au début :
- le personnage croise surtout des patrouilles ordinaires et des contrôles de circulation ;
- il peut être témoin d'une intervention sans y être impliqué ;
- il apprend les règles sociales de la ville comme n'importe quel habitant ;
- les premières infractions éventuelles restent liées à des situations ponctuelles et à leurs conséquences.

À mesure que ses choix et ses fréquentations changent :
- certains personnages peuvent le signaler ;
- des incidents peuvent attirer l'attention ;
- une enquête peut progressivement établir son identité ;
- des unités spécialisées peuvent intervenir dans des affaires plus graves ;
- ses décisions peuvent avoir des conséquences sur sa famille, ses amis, son travail, ses études et ses possibilités de déplacement.

La police accompagne l'évolution du protagoniste ; elle ne remplace pas les autres thèmes du jeu : famille, école, travail, argent, quartier, relations, paternité, criminalité et dimension surnaturelle.

## 3. Les acteurs policiers

Les catégories ci-dessous sont des rôles de jeu. Elles peuvent s'inspirer d'appellations connues, mais les équipes, personnages, procédures et missions particulières sont fictionnels. Les appellations institutionnelles réelles ne seront utilisées dans le produit final qu'après vérification.

### 3.1 Patrouille de police urbaine

Rôle : présence quotidienne et interventions courantes.

Comportements :
- circuler dans les quartiers et sur les grands axes ;
- effectuer des contrôles d'identité ou de documents ;
- intervenir après un appel ou un signalement ;
- réguler une situation conflictuelle ;
- demander à un véhicule de s'arrêter ;
- accompagner une personne vers un service compétent dans le cadre d'une scène.

La patrouille n'est pas automatiquement hostile au joueur. Elle peut le saluer, l'ignorer, lui demander ses papiers, lui donner un avertissement ou intervenir si elle observe une infraction.

### 3.2 Équipes mobiles et patrouilles de transport

Rôle : déplacements collectifs, présence renforcée et opérations ponctuelles.

Représentation visuelle :
- véhicules de transport de policiers de type Iveco ;
- équipes qui montent et descendent du véhicule ;
- agents déployés à proximité d'un point de contrôle ;
- déplacements en groupe entre plusieurs secteurs.

Ces véhicules ne doivent pas apparaître à chaque coin de rue. Leur présence annonce une activité particulière : patrouille renforcée, contrôle ou opération planifiée dans la fiction.

### 3.3 Unité anticriminalité / BAC fictivement représentée

Rôle : intervention ciblée dans des situations de délinquance ou de criminalité plus sérieuses.

Comportements :
- intervenir à la suite d'informations suffisamment crédibles ;
- rechercher une personne identifiée ;
- participer à une interpellation ;
- appuyer une enquête ou une opération scénarisée.

La BAC ne doit pas être appelée pour chaque petite infraction. Son intervention doit être rare, justifiée par le contexte et reconnaissable par le joueur.

### 3.4 Police judiciaire et enquêteurs

Rôle : comprendre les faits après un incident.

Comportements :
- recueillir les déclarations ;
- examiner les éléments disponibles ;
- comparer les témoignages ;
- identifier progressivement des personnes ;
- convoquer ou rechercher un suspect ;
- reprendre une affaire lorsqu'un nouvel élément apparaît.

Les enquêteurs ne connaissent pas automatiquement la vérité. Une enquête peut être lente, incomplète, erronée ou classée faute d'éléments suffisants.

### 3.5 Unités spécialisées

Rôle : opérations exceptionnelles réservées aux situations graves ou à certaines missions principales.

Leur apparition doit être rare. Elles ne constituent pas la réponse habituelle à un simple contrôle, une dispute ou une infraction mineure. Les moyens engagés doivent rester cohérents avec la gravité de l'événement et le ton du jeu.

## 4. Véhicules et présence visuelle

La flotte visible est mixte :

1. **Voitures ordinaires de patrouille** : contrôles, déplacements et interventions courantes.
2. **4x4 blancs** : certaines équipes mobiles ou interventions ciblées dans la fiction.
3. **Iveco de transport** : déplacement de plusieurs agents et contrôles renforcés.
4. **Patrouilles à pied** : proximité des marchés, quartiers, bâtiments publics et lieux fréquentés.

Les véhicules doivent avoir des fonctions et des fréquences différentes. Un Iveco n'est pas une voiture de poursuite ordinaire. Un 4x4 n'est pas automatiquement un véhicule d'intervention spéciale.

Les hélicoptères ne font pas partie de la présence policière habituelle. Ils ne doivent pas apparaître comme un système automatique de recherche ou de poursuite. Une éventuelle scène exceptionnelle devrait être écrite et justifiée spécifiquement.

La ville ne doit pas être saturée de véhicules policiers. La plupart du temps, le joueur doit pouvoir circuler sans rencontrer une intervention.

## 5. Rythme de la journée policière

Le monde utilise trois grandes plages horaires de conception. Elles servent à différencier l'ambiance et les types d'activités ; elles ne constituent pas des horaires officiels.

### 5.1 Matin — 06 h à 12 h

Ambiance :
- reprise des activités économiques ;
- circulation des travailleurs, élèves, taxis et transports ;
- livraisons et déplacements commerciaux.

Activités policières plus probables dans la simulation :
- contrôles de véhicules commerciaux ;
- vérification de documents de transport ;
- contrôles routiers ponctuels ;
- patrouilles sur les axes fréquentés.

Le protagoniste peut être contrôlé s'il conduit un véhicule concerné ou traverse un point de contrôle. Le contrôle ne doit pas être déclenché uniquement parce qu'il est le personnage principal.

### 5.2 Journée — 12 h à 18 h

Ambiance :
- circulation urbaine ordinaire ;
- déplacements professionnels et scolaires ;
- activités de quartier.

Activités possibles :
- patrouilles ordinaires ;
- interventions après signalement ;
- contrôles ponctuels ;
- présence autour de certains lieux publics ;
- traitement d'incidents survenus plus tôt.

La présence policière est visible mais non systématique.

### 5.3 Soir et nuit — 18 h à 06 h

Ambiance :
- baisse progressive de certaines activités commerciales ;
- déplacements privés ;
- circulation plus calme dans certains secteurs ;
- éclairage urbain, contrôles et patrouilles plus perceptibles.

Activités plus probables dans la simulation :
- patrouilles mobiles ;
- contrôles de véhicules particuliers ;
- vérifications d'identité ;
- contrôles ponctuels sur des axes déterminés ;
- interventions sur signalement.

Un Iveco peut être stationné près d'un contrôle, avec des agents qui orientent les véhicules. Le joueur peut être arrêté, interrogé, contrôlé puis autorisé à repartir. La nuit ne signifie pas que chaque trajet se termine par un contrôle.

## 6. Fonctionnement d'un contrôle routier

Un contrôle est une scène de vie, pas nécessairement une confrontation.

Déroulement possible :
1. Le joueur aperçoit les agents, les barrières ou le véhicule de patrouille.
2. Un agent fait signe de ralentir ou de s'arrêter.
3. Le joueur immobilise son véhicule dans la zone prévue.
4. L'agent demande les documents ou explique le motif du contrôle.
5. Le joueur répond et présente les éléments disponibles dans le jeu.
6. L'agent vérifie les informations accessibles.
7. Le contrôle se termine par un départ autorisé, un avertissement, une amende, une vérification complémentaire ou une interpellation si le scénario et les faits le justifient.

Les issues possibles dépendent de la situation :
- documents en règle : le joueur repart ;
- document manquant ou infraction mineure : avertissement ou amende ;
- anomalie importante : immobilisation ou vérification complémentaire ;
- recherche active et identité confirmée : interpellation possible ;
- comportement abusif d'un agent : scène narrative particulière, sans faire de l'abus une règle universelle.

Le joueur doit comprendre pourquoi il est contrôlé et ce qui lui est reproché. Les contrôles ne doivent pas être des sanctions arbitraires invisibles.

## 7. Perception et connaissance du monde

La police dispose d'informations limitées et imparfaites.

Elle peut connaître :
- un incident observé directement par un agent ;
- une description fournie par un témoin ;
- un véhicule associé à un événement ;
- un nom donné dans une déclaration ;
- une adresse révélée par une information du scénario ;
- une preuve qui relie progressivement un suspect à un fait.

Elle ne connaît pas automatiquement :
- l'identité d'un auteur masqué ou non identifié ;
- la position actuelle du joueur après avoir perdu le contact ;
- le domicile d'un personnage sans élément narratif permettant de le découvrir ;
- toutes les infractions commises hors de la présence de témoins ou de preuves.

Il faut distinguer quatre notions :
- **fait observé** : un agent a personnellement vu quelque chose ;
- **signalement** : une personne rapporte un événement ;
- **suspicion** : plusieurs éléments orientent l'enquête, sans certitude ;
- **identification** : les informations disponibles permettent d'attribuer les faits à une personne.

Une suspicion ne doit pas être traitée comme une preuve définitive.

## 8. Témoins, signalements et preuves

Les habitants peuvent jouer un rôle dans les événements policiers.

Un témoin peut :
- appeler ou prévenir un service ;
- donner une description approximative ;
- reconnaître ou ne pas reconnaître une personne ;
- se tromper ;
- refuser de parler par peur ou par loyauté ;
- revenir sur sa déclaration dans une mission.

Les preuves peuvent être :
- un témoignage ;
- un objet lié à un événement ;
- une information obtenue pendant une mission ;
- un véhicule reconnu ;
- une image ou un document fictif du scénario ;
- plusieurs éléments qui, ensemble, renforcent une hypothèse.

Chaque information possède une fiabilité. Une rumeur de quartier ne doit pas avoir la même valeur qu'une observation directe confirmée.

## 9. Le dossier de recherche du protagoniste

Le système de recherche est persistant. Une fois qu'une identité est établie et qu'une enquête est ouverte, le dossier ne disparaît pas simplement parce que le joueur s'éloigne ou attend.

États narratifs :

1. **Inconnu** : aucun suspect identifié.
2. **Identifié** : la police connaît l'identité d'une personne liée à l'affaire, mais aucune recherche active n'est nécessairement lancée.
3. **Recherché** : les services cherchent activement cette personne.
4. **Localisé** : une adresse ou une zone exploitable est connue ; cela ne signifie pas que la police connaît sa position exacte à chaque instant.
5. **Enquête résolue** : l'affaire a reçu une conclusion dans le scénario.

Une affaire peut aussi être suspendue ou classée faute d'éléments suffisants. Ces conclusions doivent être explicites dans l'histoire.

### 9.1 Persistance et baisse de pression

La recherche reste dans le dossier, mais l'intensité des recherches peut diminuer avec le temps :
- moins de patrouilles ciblées ;
- moins d'interventions immédiates ;
- absence temporaire de contrôle spécifique ;
- maintien des preuves et des informations déjà recueillies.

Une nouvelle preuve, un nouveau témoignage ou un incident supplémentaire peut réactiver l'enquête.

Le joueur peut donc croire que la pression est retombée, mais il ne redevient pas automatiquement inconnu.

### 9.2 Domicile et interpellation différée

Une interpellation peut survenir sans course-poursuite.

Exemple narratif :
- un incident se produit ;
- un témoin donne des informations ;
- une enquête identifie le protagoniste ;
- une adresse est établie par un élément du scénario ;
- une équipe décide de procéder à une interpellation ;
- le joueur découvre la présence des agents lorsqu'il arrive dans le secteur ou au moment de sortir de chez lui.

Cette scène ne doit pas être déclenchée sans justification narrative. La police ne peut pas deviner le domicile du protagoniste.

La même logique peut s'appliquer à un lieu de travail, un commerce ou un autre lieu fréquenté si l'enquête a permis de l'établir.

## 10. Courses-poursuites

Les courses-poursuites existent pour donner de la tension au jeu, mais elles restent occasionnelles.

Elles peuvent commencer lorsqu'un agent :
- observe une infraction suffisamment importante ;
- tente d'intercepter un véhicule qui refuse de s'arrêter ;
- reconnaît une personne faisant l'objet d'une recherche active ;
- reçoit une information crédible et dispose d'une unité à proximité.

La poursuite doit évoluer selon la scène. Elle peut s'interrompre si les agents perdent le contact ou si les moyens disponibles ne permettent plus de continuer.

Perdre une poursuite ne supprime pas le dossier d'enquête. Si le suspect est déjà identifié, la recherche peut continuer plus tard sous une autre forme.

Le jeu ne doit pas créer une succession infinie de voitures de police. Les renforts dépendent de la gravité, de la disponibilité des unités et du scénario. Les poursuites ne doivent pas être la seule façon pour le joueur de rencontrer la police.

## 11. Arrestations, amendes et détention

Le modèle retenu est mixte : une infraction peut entraîner un avertissement, une amende, une immobilisation, une procédure ou une détention selon sa gravité et le contexte narratif.

### 11.1 Avertissement

Pour des situations mineures ou une première erreur, un agent peut rappeler une règle et laisser repartir le personnage.

### 11.2 Amende

L'amende concerne certaines infractions prévues par le jeu. Avant paiement, le joueur voit :
- le motif ;
- le montant ;
- les conséquences ;
- les possibilités de contester ou de refuser, si la scène le permet.

Le jeu ne prélève jamais de l'argent sans l'indiquer.

### 11.3 Immobilisation

Un véhicule peut être temporairement immobilisé dans certaines situations : document manquant, problème administratif fictif ou incident lié à la mission. Le joueur doit comprendre comment récupérer le véhicule ou poursuivre son déplacement.

### 11.4 Interpellation et détention

Une interpellation peut conduire à une séquence de procédure et à une période de détention décidée par le scénario.

Conséquences possibles :
- du temps passe ;
- une journée ou une activité est manquée ;
- des revenus prévus ne sont pas perçus ;
- certaines relations se dégradent ou évoluent ;
- des missions deviennent indisponibles ou changent ;
- la réputation du personnage peut être affectée ;
- une nouvelle situation familiale ou scolaire peut l'attendre à sa sortie.

La détention ne doit pas être une simple téléportation punitive. Elle doit avoir un effet sur la vie du protagoniste et sur la continuité de l'histoire.

## 12. Comportements individuels des policiers

Le jeu présente plusieurs personnalités, sans réduire tous les agents à un seul comportement.

- **Professionnel** : explique le motif, suit la procédure de la fiction et reste calme.
- **Strict** : applique les règles avec peu de tolérance, sans être nécessairement corrompu.
- **Humain ou conciliant** : peut avertir, écouter ou tenir compte du contexte.
- **Abusif** : utilise sa position de manière injuste dans une scène particulière.
- **Corrompu** : cherche à obtenir un avantage illégitime.
- **Expérimenté** : observe davantage, pose des questions et peut repérer des incohérences.
- **Débutant** : peut hésiter ou demander l'aide d'un collègue.

Les abus et la corruption sont des éléments de fiction qui peuvent être dénoncés, contestés ou avoir des conséquences. Ils ne doivent pas être présentés comme le comportement de tous les policiers gabonais.

## 13. Corruption, négociation et choix du joueur

Certaines missions peuvent mettre le protagoniste face à un agent corrompu ou à une demande injustifiée.

Choix narratifs possibles :
- refuser de payer ;
- payer dans le cadre de la fiction ;
- demander une explication ;
- chercher un témoin ;
- signaler l'incident ;
- accepter une conséquence plutôt que céder.

Ces choix peuvent modifier :
- l'argent du joueur ;
- la relation avec certains personnages ;
- la confiance envers une institution ;
- le déroulement d'une mission ;
- les informations qu'un personnage accepte ensuite de partager.

Le système ne doit pas transformer chaque contrôle en négociation financière.

## 14. Relations entre la police et les habitants

La police ne rencontre pas uniquement le protagoniste. Elle fait partie de la vie collective.

Scènes possibles :
- un agent aide à sécuriser un accident ;
- une patrouille intervient lors d'une dispute ;
- des habitants observent un contrôle ;
- un commerçant donne un renseignement ;
- un témoin refuse de parler ;
- une famille cherche un proche ;
- une patrouille demande à un groupe de se disperser ;
- une enquête modifie l'ambiance d'un quartier.

Les habitants ont des réactions différentes selon leur personnalité, leur vécu et leur relation avec les personnes concernées.

## 15. Relations avec les autres systèmes du jeu

La police doit être cohérente avec les autres acteurs et activités.

### École
Un incident peut avoir des conséquences sur la présence en classe, la réputation ou les relations avec des adultes. L'école ne doit pas automatiquement transmettre toute information à la police.

### Travail et chantiers
Le protagoniste peut être témoin d'un incident sur un chantier, être contrôlé pendant un déplacement professionnel ou manquer un travail à cause d'une procédure.

### Famille et domicile
Une interpellation peut inquiéter la famille, modifier les responsabilités du protagoniste et créer des conflits. Les proches ne doivent pas tous réagir de la même façon.

### Économie
Amendes, frais et journées perdues peuvent affecter le budget. Les sanctions doivent rester compatibles avec l'économie générale du jeu et ne pas rendre la progression impossible.

### Véhicules
Les véhicules peuvent être associés à des incidents lorsque des témoins ou des éléments du scénario permettent de les reconnaître. Un véhicule emprunté ou vendu peut créer des situations narratives, mais la police ne connaît pas automatiquement tous les propriétaires et conducteurs.

### Réputation et relations
Une arrestation connue publiquement peut modifier la manière dont certains personnages traitent le protagoniste. Une affaire discrète ne doit pas être connue de toute la ville sans raison.

### Système surnaturel
Les phénomènes surnaturels doivent rester distincts des connaissances ordinaires de la police. Les agents peuvent constater des événements étranges sans automatiquement comprendre leur origine. Le surnaturel ne doit pas être une excuse pour donner aux policiers des connaissances omniscientes.

## 16. Missions et événements liés à la police

Le système peut alimenter plusieurs types de scènes :

- contrôle routier ordinaire ;
- contrôle nocturne avec Iveco ;
- vérification de documents d'un véhicule commercial ;
- témoin d'une arrestation dans le quartier ;
- convocation après un incident ;
- enquête liée à une disparition ou à un vol ;
- recherche d'un personnage secondaire ;
- interpellation différée au domicile ;
- opération de quartier liée à une mission principale ;
- agent corrompu impliqué dans une histoire secondaire ;
- erreur d'identification qui oblige le protagoniste à clarifier la situation ;
- affaire classée faute de preuves.

Ces événements doivent être écrits avec des variations. Le joueur ne doit pas vivre exactement la même scène à chaque contrôle.

## 17. Règles de cohérence absolues

1. La police ne connaît pas automatiquement la position du joueur.
2. Une infraction non observée et sans preuve ne révèle pas automatiquement l'identité du protagoniste.
3. Une suspicion n'est pas une preuve.
4. Une recherche identifiée persiste jusqu'à une résolution narrative, même si la pression diminue.
5. Un changement de vêtements ne supprime pas un dossier déjà établi.
6. Un changement de véhicule ne détruit pas les témoignages ou les preuves déjà recueillis.
7. Une interpellation peut arriver sans course-poursuite.
8. Les courses-poursuites sont rares et justifiées.
9. Les voitures ordinaires, 4x4 blancs et Iveco ont des fonctions différentes.
10. Les hélicoptères ne sont pas un moyen ordinaire de poursuite.
11. Les contrôles varient selon l'heure et le secteur ; ils ne sont pas omniprésents.
12. Les policiers ont des personnalités et des comportements variés.
13. Les abus et la corruption sont des comportements individuels représentés par la fiction, pas une généralisation.
14. Les arrestations et amendes ont des conséquences compréhensibles pour le joueur.
15. Les événements policiers doivent soutenir l'histoire du protagoniste et non prendre toute la place.

## 18. Exemple d'une séquence complète

Yann, jeune civil, travaille sur un chantier et rentre chez lui en soirée. Sur le trajet, il traverse un contrôle routier. Les agents vérifient les documents et le laissent repartir. Quelques jours plus tard, il est témoin d'un incident impliquant une connaissance. Il ne fait pas l'objet d'une recherche immédiate, car aucun élément ne permet encore de l'identifier.

Un témoin finit par communiquer des informations. Une enquête s'ouvre. Les enquêteurs rapprochent plusieurs éléments et identifient Yann comme une personne liée à l'affaire. La recherche devient active. Une patrouille peut effectuer des contrôles ciblés, mais Yann ne voit pas nécessairement une voiture derrière lui.

La pression baisse ensuite pendant quelques jours : il ne croise plus d'unité qui le recherche. Pourtant, le dossier reste ouvert. Une nouvelle information permet aux enquêteurs d'identifier une adresse liée au personnage. Une équipe se présente alors dans le quartier. Yann peut être interpellé sans avoir vécu de course-poursuite.

Selon les faits et ses choix, il peut recevoir une convocation, être entendu, recevoir une sanction ou être placé en détention dans le cadre du scénario. À sa sortie, il retrouve une vie qui a continué sans lui : travail manqué, proches inquiets, argent perdu et relations modifiées.

Cette séquence illustre la logique recherchée : la police agit à partir d'informations accumulées, et les conséquences s'inscrivent dans la vie du protagoniste.

## 19. Ce que le joueur doit ressentir

Le joueur doit ressentir :
- que la ville vit indépendamment de lui ;
- qu'un contrôle peut être banal et se terminer rapidement ;
- qu'une enquête peut progresser sans poursuite visible ;
- que les actes ont des conséquences qui durent ;
- que les policiers sont des personnages avec des comportements différents ;
- que la fuite n'est pas toujours la réponse ;
- que la police peut intervenir à un moment inattendu, mais jamais sans raison narrative ;
- que la vie familiale, scolaire, professionnelle et sociale continue malgré les événements judiciaires.

## 20. Statut de référence

Ce document fixe la logique narrative et comportementale de la police dans LIBREVILLE STORIES. Il sert de référence pour l'écriture des missions, des dialogues, des événements du monde et, plus tard, pour la conception technique.

Il ne demande pas de programmer ou d'intégrer maintenant les systèmes policiers dans Godot. Aucune scène, IA, ressource, animation ou mécanique n'est considérée comme implémentée du seul fait que ces règles sont écrites.

Toute évolution future doit respecter cette bible ou être ajoutée comme une décision narrative explicitement validée.
