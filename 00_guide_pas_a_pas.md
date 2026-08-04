# Guide pas à pas - comprendre ce qu'on a fait, et pourquoi

> Pour les lecteurs, voyez ce document comme un **support de cours** !
> Ce document est également le **mode d'emploi** du dossier de conception du projet.
> Il introduit Merise et le vocabulaire des bases de données.
> Chaque notion est expliquée au moment où on en a besoin, avec des exemples tirés de notre projet.
>
> Vous pouvez le lire d'une traite (environ 25 minutes) ou y revenir document par document.

---

## Sommaire

1. [Le vocabulaire de base, en 5 minutes](#1-le-vocabulaire-de-base-en-5-minutes)
2. [Merise pourquoi 4 étapes et pas une seule](#2-merise-pourquoi-4-étapes-et-pas-une-seule)
3. [Étape 1.1 Comprendre le besoin](#3-étape-11-comprendre-le-besoin)
4. [Étape 1.2 Se mettre d'accord sur les règles d'écriture](#4-étape-12-se-mettre-daccord-sur-les-règles-décriture)
5. [Étape 1.3 Le dictionnaire de données](#5-étape-13-le-dictionnaire-de-données)
6. [Étape 1.4 Le MCD](#6-étape-14-le-mcd-modèle-conceptuel-de-données)
7. [Étape 1.5 Le MLD](#7-étape-15-le-mld-modèle-logique-de-données)
8. [Étape 1.6 Les scripts SQL](#8-étape-16-les-scripts-sql)
9. [Ce qui a changé par rapport à la version précédente](#9-ce-qui-a-changé-par-rapport-à-la-première-version)
10. [Glossaire](#10-glossaire)
11. [Les questions que le client peut poser](#11-les-questions-que-le-client-peut-poser)

---

## 1. Le vocabulaire de base, en 5 minutes

Une base de données relationnelle, c'est **un classeur Excel en beaucoup plus rigoureux**. L'analogie tient étonnamment bien :

| Dans Excel | Dans une base de données | Dans notre projet |
|---|---|---|
| Un onglet | Une **table** | l'onglet « colis » |
| Une ligne de l'onglet | Une **ligne** (ou *enregistrement*) | un colis précis, le n° CE2026073000003 |
| Une colonne | Une **colonne** (ou *champ*, ou *attribut*) | la colonne « poids » |
| Le contenu d'une case | Une **valeur** | 1,750 kg |

Trois différences majeures avec Excel, et ce sont elles qui font tout l'intérêt :

### a) Chaque ligne a un identifiant unique : la clé primaire

Dans Excel, rien n'empêche d'avoir deux fois la même ligne. Dans une base, chaque table possède une colonne spéciale qui **identifie chaque ligne de façon unique** : c'est la **clé primaire** (*primary key*, `PK`).

Chez nous, `col_id` est la clé primaire de la table `colis` : le colis n°7, c'est le colis n°7, il n'y en a pas deux.

En pratique on utilise presque toujours un simple numéro qui s'incrémente tout seul (1, 2, 3, 4…) : on appelle ça un **identifiant technique**. On aurait pu prendre la référence de suivi du colis comme identifiant, mais un numéro court est plus rapide et ne pose pas de problème si le format des références change un jour.

### b) Les tables se citent les unes les autres : la clé étrangère

C'est *le* concept central. Plutôt que de recopier les informations d'un client dans chaque ligne de colis, on **cite le numéro du client**.

```
Table client
┌────────┬──────────┬─────────┐
│ cli_id │ cli_nom  │ ...     │   ← cli_id est la CLÉ PRIMAIRE de client
├────────┼──────────┼─────────┤
│   3    │ Girard   │ ...     │
└────────┴──────────┴─────────┘
              ▲
              │  « ce colis est destiné au client n°3 »
              │
┌────────┬───────────────────┬────────┐
│ col_id │ col_reference     │ cli_id │   ← ici cli_id est une CLÉ ÉTRANGÈRE
├────────┼───────────────────┼────────┤
│   3    │ CE2026073000003   │   3    │
└────────┴───────────────────┴────────┘
Table colis
```

Une **clé étrangère** (*foreign key*, `FK`), c'est donc une colonne qui contient l'identifiant d'une ligne d'une autre table. Deux bénéfices immédiats :

- **Zéro recopie.** Si M. Girard change de numéro de téléphone, on le modifie à un seul endroit et tous ses colis sont à jour.
- **Zéro incohérence possible.** La base **refuse** d'enregistrer un colis destiné à un client n°999 qui n'existe pas. Elle refuse aussi de supprimer un client qui a encore des colis. Ce filet de sécurité s'appelle l'**intégrité référentielle**, et c'est gratuit : il suffit de déclarer la clé étrangère.

### c) On peut poser des règles que la base fera respecter toute seule

Exemples que nous avons mis en place :
- « le poids d'un colis est forcément positif »
- « un code postal fait exactement 5 chiffres »
- « deux colis ne peuvent pas avoir la même référence de suivi »
- « la date limite de retrait est toujours la date de dépôt + 14 jours »

Ces règles sont dans le **schéma** de la base. Aucun programme, aucune faute de frappe, aucune requête manuelle ne peut les contourner. C'est très différent d'un contrôle fait dans une application, qu'on peut toujours oublier ou court-circuiter.

---

## 2. Merise pourquoi 4 étapes et pas une seule

On pourrait écrire directement le code SQL qui crée les tables. Personne ne fait ça sur un vrai projet, pour la même raison qu'on ne construit pas une maison sans plan.

**Merise** est une méthode française (années 1970-80, toujours enseignée et utilisée) qui découpe la conception en étapes, de la plus abstraite à la plus concrète :

```
  Le besoin du client (texte en français)
              │
              ▼
  ① DICTIONNAIRE DE DONNÉES        « De quelles informations a-t-on besoin ? »
     La liste brute, sans organisation.        → fichier 02
              │
              ▼
  ② MCD - Modèle Conceptuel        « Comment ces informations s'organisent-elles ? »
     On regroupe et on relie. Indépendant       → fichier 03
     de toute technologie.
              │
              ▼
  ③ MLD - Modèle Logique           « À quoi ressemblent les tables ? »
     On applique des règles mécaniques          → fichier 04
     pour passer du MCD aux tables.
              │
              ▼
  ④ SCRIPT SQL                     « On construit pour de vrai. »
     Le code exécutable.                        → fichiers 05, 06, 07
```

L'intérêt de ce découpage : **une erreur coûte de moins en moins cher à corriger plus on la détecte tôt**. Se tromper dans le MCD, c'est déplacer un trait sur un schéma. S'en apercevoir une fois la base en production avec 3 millions de colis dedans, c'est un projet de migration.

Autre intérêt, très concret pour un travail en binôme : le MCD est **lisible par le client**. On peut poser le schéma sur la table et lui demander « est-ce qu'un colis peut être destiné à deux personnes ? ». Il n'a pas besoin de savoir ce qu'est une clé étrangère pour répondre.

---

## 3. Étape 1.1 Comprendre le besoin

📄 **Fichier concerné : `01_analyse_et_conventions.md`, partie 1**

### Ce qu'on a fait

On a relu le cahier des charges en cherchant trois choses :

**1) Les « acteurs »** - qui utilise le système ? On en a trouvé quatre :
le **particulier** (qui prête son domicile), le **transporteur** (qui livre), le **client final** (qui reçoit), et le **système lui-même** (le traitement automatique qui surveille les délais).

**2) Les « choses » dont il faut se souvenir** - ce sont les futures tables : des colis, des adresses, des missions…

**3) Les scénarios** (on dit aussi *cas d'utilisation* ou *use cases*) - chaque action concrète que quelqu'un va vouloir faire. On en a listé 24, numérotés UC01 à UC24.

### Pourquoi les scénarios sont l'outil le plus utile

C'est le test de vérité de votre modèle. À la fin, pour chaque scénario, vous devez pouvoir dire : « voilà la requête qui répond à ce besoin ». Si vous n'y arrivez pas, il manque une donnée ou un lien.

Exemple concret. Le scénario **UC21** dit : *« lister les colis en attente de retrait »*. Pour y répondre il faut savoir, pour chaque colis : son statut actuel, chez qui il est, pour qui il est, et depuis quand. Ces quatre besoins ont directement dicté quatre colonnes du modèle. Sans le scénario, on aurait pu oublier « depuis quand ».

Le fichier `07_tests_use_cases.sql` contient justement la requête SQL correspondant à chaque scénario important : c'est la preuve que le modèle tient debout.

### La chose la plus importante du cahier des charges

Une phrase mérite d'être relue trois fois :

> *« La plateforme doit conserver l'**historique** des changements d'état des colis, en incluant les dates correspondantes, le point relais concerné et le transporteur responsable. »*

« Conserver l'historique » change tout. La solution naïve serait d'avoir une colonne « statut » dans la table colis, qu'on écrase à chaque étape :

```
Lundi    : colis n°10, statut = "en cours de livraison"
Mercredi : colis n°10, statut = "déposé au relais"     ← on a PERDU l'info de lundi
```

Impossible ensuite de répondre à « quand ce colis a-t-il été déposé ? » ou « combien de temps met ce transporteur à récupérer ses retours ? ». Il faut donc une **table dédiée** qui garde une ligne par changement - c'est notre table `historique_statut`, et c'est le cœur du modèle.

---

## 4. Étape 1.2 Se mettre d'accord sur les règles d'écriture

📄 **Fichier concerné : `01_analyse_et_conventions.md`, partie 2**

### Pourquoi c'est loin d'être du formalisme inutile

Vous êtes deux à écrire. Sans accord préalable, vous obtenez ça :

```
Table Clients     colonne  NomClient
table colis       colonne  poids_du_colis
Table TRANSPORTEUR colonne Adresse_Mail
```

Trois styles différents en trois lignes. Sur 7 tables et 81 colonnes, personne ne se souviendra si la colonne s'appelle `email`, `mail`, `adresse_mail` ou `courriel` - et chaque requête deviendra une devinette.

### Les règles qu'on a retenues

| Règle | Exemple |
|---|---|
| Tout en **minuscules**, mots séparés par `_` | `historique_statut` |
| **Jamais d'accent ni d'espace** dans un nom de table ou de colonne | `disponibilites`, pas `disponibilités` |
| Nom de table au **singulier** | `colis`, `client`, `mission` |
| Chaque colonne commence par un **préfixe de 3 lettres** rappelant sa table | `col_poids_kg` est dans `colis` |
| La clé primaire s'appelle `<préfixe>_id` | `col_id`, `cli_id` |
| Une clé étrangère **garde le nom** de la clé primaire qu'elle cite | `colis.cli_id` cite `client.cli_id` |
| Un booléen (vrai/faux) commence par `est_` ou `a_` | `par_est_actif` |
| L'unité de mesure est dans le nom | `col_poids_kg`, `par_surface_stockage_m2` |

**À quoi sert le préfixe de 3 lettres ?** Quand une requête assemble 5 tables, on lit `par_nom` et on sait instantanément que ça vient de `particulier`. Sans préfixe, une colonne `nom` toute seule est ambiguë : le nom de qui ? Cette convention est très répandue en formation française, et elle rend le SQL beaucoup plus lisible pour un débutant.

### Choisir les types de données

Chaque colonne doit annoncer ce qu'elle contient. Les principaux :

| Type | Sert à | Exemple chez nous |
|---|---|---|
| `INT`, `SMALLINT`, `BIGINT` | des nombres entiers | `col_id` |
| `VARCHAR(n)` | du texte de longueur variable, jusqu'à *n* caractères | `par_nom VARCHAR(80)` |
| `CHAR(n)` | du texte de longueur **fixe** | `adr_code_postal CHAR(5)` |
| `DATE` | une date seule | `par_date_naissance` |
| `DATETIME` | une date **avec l'heure** | `his_date_changement` |
| `BOOLEAN` | vrai / faux | `par_est_actif` |
| `DECIMAL(p,s)` | un nombre à virgule **exact** | `col_poids_kg DECIMAL(6,3)` |
| `ENUM(...)` | une liste courte et figée de valeurs autorisées | `par_civilite ENUM('M','MME','AUTRE')` |

**Deux pièges à connaître**, ils tombent souvent à l'oral :

> ⚠️ **Ne jamais utiliser `FLOAT` ou `DOUBLE` pour un montant ou un poids.** Ces types stockent des valeurs *approchées* : `0.1 + 0.2` peut donner `0.30000000000000004`. Sur une valeur déclarée en euros, c'est inacceptable. On utilise `DECIMAL`, qui est exact.
> `DECIMAL(6,3)` se lit : 6 chiffres au total dont 3 après la virgule → de `-999.999` à `999.999`.

> ⚠️ **`VARCHAR` ou `CHAR` ?** `CHAR(5)` réserve toujours 5 caractères, même pour un texte plus court. C'est parfait quand la longueur est *toujours* la même (code postal, SIRET) et légèrement plus rapide. `VARCHAR(80)` ne consomme que ce qu'on écrit : c'est le bon choix pour un nom de famille.

---

## 5. Étape 1.3 Le dictionnaire de données

📄 **Fichier concerné : `02_dictionnaire_donnees.md`**

### Ce que c'est

Un grand tableau qui liste **toutes les informations** à mémoriser, **sans se demander dans quelle table elles iront**. C'est volontaire : on sépare le « quoi » du « comment ».

Chaque ligne contient au minimum :

| Colonne du dictionnaire | Ce que c'est | Exemple |
|---|---|---|
| **Code mnémonique** | le nom technique de la donnée | `col_poids_kg` |
| **Désignation** | ce que c'est, en français | Poids du colis |
| **Type** | la nature de la donnée | Décimal |
| **Taille** | la place occupée | 6,3 |

On a ajouté deux colonnes utiles : les **contraintes** (obligatoire ? unique ? valeurs permises ?) et la **nature**.

### La colonne « nature » : la seule subtilité de l'étape

On classe chaque donnée en trois catégories :

- **E - élémentaire** : une information qu'on doit vraiment stocker. `col_poids_kg` : personne ne peut la deviner, il faut la saisir.
- **C - calculée** : une information qu'on peut **déduire** d'autres données. L'âge d'un particulier se déduit de sa date de naissance. Le volume d'un colis se déduit de ses trois dimensions.
- **CC - concaténée** : un assemblage de plusieurs données. « 17 rue Paul Bert, 69003 Lyon » est l'assemblage de 4 colonnes.

**Règle d'or : on ne stocke pas les données calculées.** Pourquoi ? Parce que si on stockait l'âge, il serait faux dès le lendemain de l'anniversaire. Une donnée stockée à deux endroits finit toujours par diverger.

Cette règle a **une exception assumée** dans notre projet, expliquée au point 7 ci-dessous.

### Notre dictionnaire en chiffres

**71 données élémentaires** réparties sur 7 rubriques, plus **7 données calculées** repérées et volontairement non stockées.

### Le conseil pratique

Le dictionnaire n'est jamais complet du premier coup, et ce n'est pas grave. Vous découvrirez en construisant le MCD qu'il manque une date, ou en écrivant une requête de test qu'il manque un indicateur. **Ajoutez-les au fur et à mesure** - c'est un document vivant, pas un examen.

---

## 6. Étape 1.4 Le MCD (Modèle Conceptuel de Données)

📄 **Fichiers concernés : `03_mcd.md` et `mcd.mermaid`**
⏱️ *C'est l'étape la plus longue du sujet (7,5 h prévues) et la plus importante.*

### L'idée

On prend les données en vrac du dictionnaire et on répond à deux questions :

1. **Quels paquets forment-elles ?** → ce seront les **entités**
2. **Comment ces paquets sont-ils reliés ?** → ce seront les **associations**

### Une entité

Une entité, c'est une « chose » du monde réel dont on veut se souvenir. On la dessine dans un rectangle : le nom en en-tête, les données en dessous, **l'identifiant en première ligne**.

```
┌─────────────────────┐
│      CLIENT         │   ← le nom, au singulier, en majuscules
├─────────────────────┤
│  cli_id             │   ← l'identifiant, toujours en premier
│  cli_nom            │
│  cli_prenom         │
│  cli_email          │
│  cli_telephone      │
└─────────────────────┘
```

**Comment sait-on qu'un paquet mérite d'être une entité ?** Trois signes qui ne trompent pas :
- On peut lui donner un nom au singulier qui a du sens pour le client (« un colis », « une mission »).
- On peut l'identifier de façon unique.
- Il en existera plusieurs exemplaires.

Notre MCD compte **7 entités** : `ADRESSE`, `PARTICULIER`, `TRANSPORTEUR`, `CLIENT`, `MISSION`, `COLIS`, `HISTORIQUE_STATUT`.

> **Contre-exemple utile : le statut d'un colis n'est PAS une entité.** On pourrait être tenté d'en faire une, puisqu'il y a 6 valeurs bien identifiées. Mais un statut n'est pas une « chose » : c'est une **caractéristique** du colis, au même titre que son poids. Il devient donc un simple **attribut**, de type énuméré. Le point ② ci-dessous donne le critère qui permet de trancher à coup sûr.

### Une association

Une association, c'est le **lien** entre deux entités. On la dessine dans un ovale et on la nomme avec un **verbe** :

```
┌──────────────┐                              ┌──────────┐
│ TRANSPORTEUR │────( TRANSPORTER )───────────│  COLIS   │
└──────────────┘                              └──────────┘
```

Ça se lit dans les deux sens : « un transporteur transporte des colis », « un colis est transporté par un transporteur ».

### Les cardinalités - le point à ne pas rater

Une cardinalité répond à la question : **« combien ? »**. On l'écrit sur le trait, **du côté de l'entité**, sous la forme `minimum,maximum`.

Il n'y a que quatre valeurs possibles :

| Notation | Se lit | Exemple concret |
|---|---|---|
| `0,1` | zéro ou un, au plus un | un colis est déposé sous **au plus une** mission (aucune tant qu'il roule) |
| `1,1` | exactement un, ni plus ni moins | un colis est transporté par **un seul** transporteur |
| `0,n` | zéro, un ou plusieurs | un transporteur peut avoir **0 ou 1000** colis |
| `1,n` | au moins un, éventuellement plusieurs | un colis a **au moins une** ligne d'historique |

**La méthode pour ne pas se tromper.** Placez-vous sur **une** occurrence de l'entité, et posez la question à voix haute :

> Je prends **un** transporteur précis, disons ColiExpress.
> - Combien de colis **au minimum** ? → zéro (un partenaire tout juste signé n'a encore rien confié).
> - Combien de colis **au maximum** ? → autant qu'il veut, donc `n`.
> → Du côté `TRANSPORTEUR`, on écrit **`0,n`**.

> Je prends **un** colis précis, le n°CE2026073000003.
> - Combien de transporteurs au minimum ? → un, forcément, sinon il n'existerait pas dans le système.
> - Au maximum ? → un aussi, il n'est pas transporté par deux sociétés.
> → Du côté `COLIS`, on écrit **`1,1`**.

```
┌──────────────┐  0,n                    1,1  ┌──────────┐
│ TRANSPORTEUR │───────( TRANSPORTER )────────│  COLIS   │
└──────────────┘                              └──────────┘
```

> ⚠️ **Le piège classique**, et le sujet vous prévient d'ailleurs : *« Attention à la position des cardinalités »*. Beaucoup de débutants écrivent le `0,n` du côté du colis parce qu'ils pensent « plusieurs colis ». Non : la cardinalité se lit **depuis l'entité sur laquelle elle est posée**. Elle décrit ce que fait **une seule** occurrence de cette entité.
>
> Une bonne façon de vérifier : les cardinalités `1,1` et `0,n` sont presque toujours **en face l'une de l'autre**, jamais du même côté.

### Les trois choix de notre MCD qui méritent une explication

#### ① Pourquoi `MISSION` est une entité et non une simple association

Le lien entre un particulier et un transporteur n'est pas un simple trait : il porte des informations propres (date de début, date de fin, statut de la candidature, quota de colis). Et surtout, **le colis doit pouvoir désigner cette mission**.

Or Merise interdit de relier une association à une autre association. La solution s'appelle la **réification** : on transforme le lien en entité à part entière, avec son propre identifiant `mis_id`.

Le bénéfice est très concret : quand une ligne d'historique cite une mission, elle indique **d'un seul coup** le point relais concerné **et** le transporteur responsable - exactement les deux informations que le cahier des charges exige.

#### ② Pourquoi le statut est un **attribut énuméré** et pas une table à part

C'est la question qui revient systématiquement, alors autant avoir la réponse prête.

Trois options existaient :

| Option | Verdict |
|---|---|
| Une colonne de **texte libre** | ❌ Non. Rien n'empêcherait `« déposé »`, `« depose »`, `« Déposé »` de cohabiter, et aucun filtre ne serait fiable. |
| Une **table de référence** `STATUT_COLIS` citée par clé étrangère | ⚠️ Ça marche, mais c'est disproportionné ici. |
| Un **type énuméré** (`ENUM`) | ✅ Retenu. |

**Le critère de décision.** On crée une table de référence **si et seulement si** au moins l'un de ces trois points est vrai :

1. **la liste évolue** - le client doit pouvoir ajouter ou renommer des valeurs lui-même ;
2. **chaque valeur porte des données propres** (un libellé traduit, une couleur, un délai spécifique…) qu'il faut maintenir ;
3. **l'intégrité ne peut pas être garantie autrement**.

Ici, aucun des trois. Les 6 statuts décrivent le parcours physique d'un colis, tel qu'il est écrit noir sur blanc dans le cahier des charges : ils ne bougeront pas. Et surtout, le point 3 tombe - **un type énuméré garantit l'intégrité tout seul**.

> **C'est le point qu'il faut bien comprendre : « énuméré » ne veut pas dire « texte libre ».**
> Une colonne déclarée `ENUM('EN_COURS_LIVRAISON','DEPOSE_RELAIS', …)` n'accepte **que** ces 6 valeurs. Écrire `'PERDU_EN_ROUTE'`, ou même `'depose_relai'` avec une faute de frappe, provoque une **erreur** - exactement comme une clé étrangère invalide. Les tests négatifs du fichier `07` le démontrent noir sur blanc.

**Ce qu'on y gagne :**

- une table de moins, et une jointure de moins dans **chaque** requête de consultation ;
- des requêtes d'écriture nettement plus courtes : `col_statut = 'DEPOSE_RELAIS'` au lieu d'aller chercher un identifiant par sous-requête ;
- le tri chronologique **gratuit** : on déclare les 6 valeurs dans l'ordre du parcours, et MySQL trie un énuméré selon cet ordre de déclaration (pas alphabétiquement). Un simple `ORDER BY his_statut` restitue le déroulé du colis ;
- **et un gain inattendu** : une règle `CHECK` ne peut porter que sur des colonnes de sa propre table. Le statut vivant désormais *dans* la table `colis`, on peut enfin écrire « un colis terminé a forcément une date de clôture ». Avec une clé étrangère vers une table externe, cette règle aurait exigé une jointure - donc aurait été impossible.

**Ce qu'on y perd :** ajouter un 7ᵉ statut demandera un `ALTER TABLE` au lieu d'un `INSERT`, et le libellé lisible (« Déposé au point relais ») n'est plus stocké - il est reconstruit par une expression `CASE` dans les vues. Deux inconvénients acceptables pour une liste qui, par définition, ne bouge pas.

> **La règle à retenir :**
> **liste figée et sans données propres → énuméré.
> Liste administrable ou porteuse d'informations → table de référence.**
>
> Le type de logement et le statut de mission suivent exactement le même raisonnement, et sont donc eux aussi des énumérés.

#### ③ Pourquoi `HISTORIQUE_STATUT` existe

Déjà expliqué au point 3 : c'est l'exigence de traçabilité du cahier des charges. Une ligne = un changement d'état. Le colis n°10 de notre jeu de test a 5 lignes d'historique, qui racontent toute son histoire :

```
30/05 08:45  EN_COURS_LIVRAISON    (par le transporteur)
01/06 12:00  DEPOSE_RELAIS         chez Sophie Marchand
16/06 02:00  NON_RECLAME           (bascule automatique à J+14)
17/06 08:30  EN_ATTENTE_REPRISE    (le transporteur planifie le retour)
22/06 10:15  REPRIS_TRANSPORTEUR   (fin du processus)
```

---

## 7. Étape 1.5 Le MLD (Modèle Logique de Données)

📄 **Fichiers concernés : `04_mld.md` et `mld.mermaid`**

### L'idée

Le MCD est un schéma conceptuel : il contient des ovales (les associations) qui n'existent pas dans une vraie base. Le MLD les **traduit en tables et en clés étrangères**.

Bonne nouvelle : cette traduction est **mécanique**. Trois règles, aucune créativité nécessaire.

### Règle 1 - quand les deux côtés sont `0,1` ou `1,1`

Les deux entités sont liées une à une. On ajoute la clé primaire de l'une comme clé étrangère dans l'autre, avec une contrainte d'unicité.

*Dans notre modèle simplifié, ce cas n'apparaît plus* : le lien 1-à-1 entre le particulier et son logement a été supprimé, puisque les informations du logement sont maintenant **dans** la table `particulier`.

### Règle 2 - quand un côté est `1,1` (ou `0,1`) et l'autre `0,n` (ou `1,n`)

**C'est le cas le plus fréquent : 10 de nos 10 associations.**

La clé primaire du côté « n » **descend** comme clé étrangère du côté « 1 ».

```
AVANT (MCD)
┌──────────────┐  0,n                    1,1  ┌──────────┐
│ TRANSPORTEUR │───────( TRANSPORTER )────────│  COLIS   │
└──────────────┘                              └──────────┘

APRÈS (MLD)
┌────────────────────┐              ┌──────────────────────┐
│ transporteur       │              │ colis                │
│  tra_id       (PK) │◄─────────────│  col_id         (PK) │
│  tra_raison_sociale│              │  tra_id         (FK) │  ← la clé descend ici
│  ...               │              │  col_poids_kg        │
└────────────────────┘              └──────────────────────┘
```

**Comment retenir le sens ?** La clé va toujours **du côté qui n'en a qu'un**. Un colis n'a qu'un transporteur → on peut écrire ce transporteur dans la ligne du colis. L'inverse serait impossible : un transporteur a 1000 colis, on ne va pas mettre 1000 colonnes dans sa ligne.

**Petite astuce de relecture** qui permet de vérifier tout le MCD d'un coup :
- une patte `1,1` donne une clé étrangère **obligatoire** (`NOT NULL`)
- une patte `0,1` donne une clé étrangère **facultative** (qui peut rester vide)

Si vous obtenez une colonne obligatoire alors que le métier dit « ça peut être vide », c'est que la cardinalité était fausse dans le MCD. C'est exactement ce qui se passe pour `colis.mis_id` : tant que le colis roule dans le camion, il n'a pas encore de point relais, donc la case reste vide, donc la cardinalité était bien `0,1`.

### Règle 3 - quand les deux côtés sont `0,n` ou `1,n`

Là, aucune des deux tables ne peut accueillir la clé de l'autre. On crée une **troisième table** (une « table d'association ») qui contient les deux clés.

Dans notre projet, le seul cas était « un particulier travaille pour plusieurs transporteurs et réciproquement »… et on l'a déjà traité au MCD en créant l'entité `MISSION`. **`mission` EST notre table d'association** : elle contient `par_id` + `tra_id` + ses propres données.

### Le classement par niveaux : à quoi ça sert

Une table qui contient une clé étrangère ne peut pas être créée avant la table qu'elle cite - la base refuserait. On classe donc les tables par **niveau de dépendance**, et ce classement donne directement l'ordre d'écriture du script :

```
Niveau 0 : adresse                         ← aucune clé étrangère
Niveau 1 : particulier · transporteur · client   ← citent adresse
Niveau 2 : mission                         ← cite particulier et transporteur
Niveau 3 : colis                           ← cite mission, transporteur, client
Niveau 4 : historique_statut               ← cite colis et mission
```

Pour **supprimer**, c'est exactement l'inverse : niveau 4 d'abord, niveau 0 en dernier. Même logique pour les insertions de données : on ne peut pas créer un colis avant son client.

### L'exception à la règle « on ne stocke pas les données calculées »

Notre table `colis` contient une colonne `col_statut` : le statut **actuel** du colis. C'est une information redondante - on pourrait la retrouver en cherchant la dernière ligne d'historique du colis.

Alors pourquoi la stocker ? Parce que le cahier des charges annonce un **volume important de colis** et que la question « quels colis sont en attente de retrait ? » sera posée en permanence. Sans cette colonne, il faudrait, pour chaque colis, parcourir tout son historique et trouver la ligne la plus récente. Avec elle, la réponse est immédiate.

On appelle ça une **dénormalisation** : on accepte volontairement une redondance pour gagner en rapidité. Deux conditions pour que ce soit acceptable :

1. **On l'écrit noir sur blanc** - sinon un relecteur croit à une erreur de conception.
2. **Les deux écritures se font toujours ensemble**, dans la même *transaction* : quand on ajoute une ligne d'historique, on met à jour `colis.col_statut` dans le même mouvement. Une transaction, c'est un bloc « tout ou rien » : soit les deux écritures réussissent, soit aucune. Sans ça, une coupure de courant au mauvais moment laisserait la base incohérente.

Le fichier `07_tests_use_cases.sql` contient d'ailleurs un contrôle (test T1) qui vérifie que les deux informations n'ont jamais divergé.

---

## 8. Étape 1.6 Les scripts SQL

📄 **Fichiers concernés : `05_creation_bdd.sql`, `06_insertion_donnees.sql`, `07_tests_use_cases.sql`**

### Le script de création (`05`)

Il fait exactement trois choses :

```sql
DROP DATABASE IF EXISTS relais_domicile;   -- on repart d'une base propre
CREATE DATABASE relais_domicile ...;       -- on crée la base
USE relais_domicile;                       -- on s'y place
-- puis un CREATE TABLE par table, dans l'ordre des niveaux
```

Le `DROP ... IF EXISTS` en tête rend le script **rejouable** : vous pouvez le relancer autant de fois que vous voulez pendant la mise au point.

**Anatomie d'un `CREATE TABLE`** - prenons un extrait commenté :

```sql
CREATE TABLE colis (
    col_id        BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    --            │                │        └─ la base numérote toute seule : 1, 2, 3...
    --            │                └─ interdit de laisser vide
    --            └─ grand entier positif (on attend beaucoup de colis)

    col_reference VARCHAR(30)     NOT NULL,
    tra_id        SMALLINT UNSIGNED NOT NULL,
    mis_id        INT UNSIGNED        NULL,   -- vide tant que le colis n'est pas déposé

    CONSTRAINT pk_colis PRIMARY KEY (col_id),
    --         └─ on nomme la contrainte : les messages d'erreur seront lisibles

    CONSTRAINT uq_colis_reference UNIQUE (col_reference),
    --         └─ interdit deux colis avec la même référence

    CONSTRAINT fk_colis_transporteur FOREIGN KEY (tra_id)
        REFERENCES transporteur (tra_id) ON DELETE RESTRICT,
    --  └─ tra_id doit exister dans transporteur ; on refuse de supprimer
    --     un transporteur qui a encore des colis

    CONSTRAINT ck_colis_poids CHECK (col_poids_kg > 0)
    --         └─ la base refusera un poids négatif ou nul
) ENGINE = InnoDB;
--  └─ le moteur de stockage qui gère les clés étrangères et les transactions
```

**Trois mots à connaître :**
- `UNIQUE` : interdit les doublons sur cette colonne.
- `CHECK` : une règle que la base vérifie à chaque écriture.
- `ON DELETE RESTRICT` : que faire si on supprime la ligne citée ? `RESTRICT` = « on refuse ». L'autre valeur qu'on utilise est `CASCADE` = « on supprime aussi les lignes qui citent ». Nous mettons `CASCADE` sur l'historique d'un colis (si le colis disparaît, son historique n'a plus de raison d'être) et `RESTRICT` partout ailleurs.

### Les vues

À la fin du script, vous trouverez des `CREATE VIEW`. Une **vue** est simplement une requête à laquelle on donne un nom, pour ne pas la réécrire à chaque fois :

```sql
SELECT * FROM v_colis_en_attente_retrait;
```

Cette seule ligne assemble 6 tables et calcule les jours restants avant expiration. La vue ne stocke rien : elle recalcule à chaque appel, donc elle est toujours à jour. C'est ce qui alimentera les écrans de consultation demandés par le cahier des charges.

### Le script de remplissage (`06`)

Sans données, impossible de vérifier quoi que ce soit. On insère donc :

- **les données des scénarios** : de quoi rejouer chaque cas d'utilisation ;
- **et surtout les cas limites**, qui sont les plus utiles à tester.

*(Il n'y a plus aucun référentiel à alimenter : les statuts étant des valeurs énumérées, ils vivent dans la définition des colonnes, pas dans des lignes à insérer.)*

Notre jeu de données contient volontairement :

| Situation | Pourquoi c'est là |
|---|---|
| un particulier inscrit mais **refusé** par le transporteur | le cahier des charges dit que tous les inscrits ne sont pas actifs |
| un particulier dont la candidature est **en attente** | vérifier qu'il n'apparaît pas comme point relais actif |
| un particulier **désactivé** dont la mission est terminée | vérifier qu'on garde son historique |
| un particulier travaillant pour **deux transporteurs à la fois** | c'est explicitement autorisé par le cahier des charges |
| un colis dont le **délai de 14 jours vient d'expirer** | c'est le cas que le traitement automatique doit attraper |
| **au moins un colis dans chacun des 6 statuts** | pour que chaque écran ait quelque chose à afficher |

**L'ordre des insertions suit les niveaux** : on ne peut pas créer un colis avant son client.

### Le script de tests (`07`)

Il contient quatre familles de vérifications :

1. **Contrôles d'intégrité** - 7 requêtes qui doivent toutes renvoyer **zéro ligne**. Chacune cherche une incohérence : un colis sans historique, un statut courant qui ne correspond pas au dernier historique, etc. Zéro ligne = tout va bien.
2. **Requêtes métier** - une requête par cas d'utilisation important, avec son résultat.
3. **Scénarios d'écriture** - on simule un dépôt, un retrait, la bascule automatique à J+14. Ces blocs se terminent par `ROLLBACK`, ce qui **annule** les modifications : le jeu de données reste intact.
4. **Tests négatifs** - on tente exprès des écritures interdites (poids négatif, référence en double…) pour vérifier que la base les refuse. Un test qui *échoue* est ici un test qui *réussit*.

Ce dernier point est celui qu'on oublie le plus souvent, et c'est pourtant le plus convaincant en soutenance : il prouve que vos contraintes servent à quelque chose.

---

## 9. Ce qui a changé par rapport à la première version

Vous avez demandé un modèle plus simple. Voici précisément ce qui a été fait et ce que ça implique.

### Les suppressions

| Supprimé | Devenu quoi | Conséquence |
|---|---|---|
| Table `ADMINISTRATEUR` | *(rien)* | Plus de back-office. La consultation reste possible via les vues, mais on ne trace plus **qui** a fait une correction. |
| Table `TYPE_LOGEMENT` | colonne `par_type_logement` de type `ENUM` dans `particulier` | Les 4 types sont figés dans le schéma. Pour en ajouter un, il faudra modifier la table (`ALTER TABLE`) au lieu d'ajouter une ligne. |
| Table `LOGEMENT` | 6 colonnes ajoutées à `particulier` | Le lien 1-à-1 disparaît. C'est le cas où fusionner est **objectivement le bon choix** : une table qui a exactement autant de lignes qu'une autre n'a en général pas lieu d'exister. |
| Table `DISPONIBILITE` | colonne texte `par_disponibilites` dans `particulier` | ⚠️ C'est le seul point qui coûte vraiment quelque chose, voir juste en dessous. |
| Table `STATUT_COLIS` | colonnes `col_statut` et `his_statut` de type `ENUM` | Le libellé affichable n'est plus stocké (reconstruit par un `CASE` dans les vues), et un statut sans aucun colis n'apparaît plus dans les statistiques. En échange : une jointure de moins partout, des écritures plus courtes, et **trois nouvelles règles `CHECK` devenues possibles**. |

**Bilan : 12 tables → 7 tables, 16 clés étrangères → 10.**

### Le seul compromis réel : les disponibilités

Avant, chaque créneau était une ligne : `(Sophie, mardi, 18h00, 20h30)`. C'était interrogeable - on pouvait demander « qui est disponible mardi soir dans le 69003 ? » et la base répondait.

Maintenant, c'est du **texte libre** : `"Lun-Ven 18h-20h30, Sam 9h-12h"`. C'est parfaitement lisible par un humain, mais la base ne peut plus le comprendre : impossible de filtrer dessus, et rien n'empêche une saisie fantaisiste.

**Pourquoi c'est acceptable ici :** aucun scénario du cahier des charges n'exige de filtrer sur un créneau horaire. Le texte suffit pour afficher les horaires à un transporteur qui consulte une fiche.

**Comment le dire au client, s'il pose la question :**

> « On a volontairement fusionné les disponibilités dans une colonne texte pour simplifier le modèle, parce qu'aucun cas d'utilisation ne demande de rechercher par créneau. Si ce besoin apparaît - typiquement "trouver les relais ouverts samedi matin" -, il faudra ressortir une table `disponibilite` reliée en `0,n` au particulier. Le changement est isolé : il n'impacte aucune autre table. »

C'est exactement le genre de réponse qui montre qu'un choix a été **fait**, et non subi.

### Les deux règles générales à retenir

Ces cinq suppressions ne relèvent pas du même raisonnement. Il y en a deux, et savoir les distinguer est exactement ce que l'exercice cherche à évaluer.

> **① Fusionner deux tables est bénéfique quand la relation est « 1 pour 1 ». C'est une perte quand la relation est « 1 pour plusieurs ».**

`LOGEMENT` : un particulier, un logement → la fusion est un gain net, on supprime une table et une jointure sans rien perdre.
`DISPONIBILITE` : un particulier, plusieurs créneaux → la fusion écrase plusieurs lignes en une seule chaîne de caractères, on perd de la capacité d'interrogation.

> **② Une liste de valeurs devient une table de référence seulement si elle évolue, ou si elle porte des données propres. Sinon, un type énuméré suffit.**

`STATUT_COLIS` : 6 valeurs figées décrivant un parcours physique, sans données propres → énuméré. On ne perd rien sur l'intégrité (la base refuse toujours une valeur hors liste), on gagne une jointure en moins partout et trois règles `CHECK` qui étaient impossibles avant.
`TYPE_LOGEMENT` : même raisonnement.

**La façon de le présenter :** ne dites pas « on a supprimé des tables pour simplifier ». Dites « on a appliqué deux critères - la cardinalité pour les fusions, l'évolutivité pour les référentiels - et voici ce que chaque décision coûte ». C'est ce qui distingue un choix d'un raccourci.

---

## 10. Glossaire

| Terme | Définition |
|---|---|
| **Association** | Lien entre deux entités dans un MCD, nommé par un verbe. Devient une clé étrangère ou une table au MLD. |
| **Attribut** | Une information portée par une entité. Devient une colonne. |
| **Cardinalité** | Le « combien » d'un lien : `0,1` · `1,1` · `0,n` · `1,n`. Se lit du côté de l'entité. |
| **CHECK** | Contrainte SQL qui impose une condition sur les valeurs d'une colonne. |
| **Clé étrangère (FK)** | Colonne contenant l'identifiant d'une ligne d'une autre table. C'est ce qui relie les tables entre elles. |
| **Clé primaire (PK)** | Colonne (ou groupe de colonnes) qui identifie chaque ligne de façon unique. |
| **Dénormalisation** | Redondance acceptée volontairement pour gagner en performance. Doit toujours être documentée. |
| **Dictionnaire de données** | Liste exhaustive des informations à stocker, avant toute organisation. |
| **Entité** | Une « chose » du monde réel qu'on veut mémoriser. Devient une table. |
| **ENUM (type énuméré)** | Colonne dont les valeurs autorisées sont listées dans sa définition. La base refuse tout ce qui n'y figure pas. Attention : ce n'est **pas** du texte libre. Trie selon l'ordre de déclaration, pas alphabétiquement. |
| **Identifiant technique** | Clé primaire artificielle, un simple numéro auto-incrémenté. |
| **InnoDB** | Le moteur de stockage de MySQL/MariaDB qui gère les clés étrangères et les transactions. Toujours le choisir. |
| **Intégrité référentielle** | Garantie que toute clé étrangère pointe vers une ligne qui existe réellement. |
| **Jointure** | Opération SQL qui rassemble les données de plusieurs tables via leurs clés. |
| **MCD** | Modèle Conceptuel de Données. Le schéma entités/associations, indépendant de toute technologie. |
| **MLD** | Modèle Logique de Données. Le schéma des tables et des clés, obtenu mécaniquement à partir du MCD. |
| **Merise** | Méthode française de conception de systèmes d'information. |
| **NOT NULL** | « Cette colonne ne peut pas rester vide. » |
| **NULL** | L'absence de valeur. Différent de zéro et de la chaîne vide : `NULL` veut dire « inconnu » ou « sans objet ». |
| **Réification** | Transformer une association porteuse de données en entité à part entière. C'est ce qu'on a fait pour `MISSION`. |
| **Référentiel** | Petite table de valeurs fixes citée par d'autres tables. Notre modèle n'en contient aucun : les listes figées sont des types énumérés. |
| **ROLLBACK** | Annule toutes les modifications faites depuis le début de la transaction. |
| **Schéma** | La structure de la base : ses tables, colonnes, clés et contraintes. |
| **Transaction** | Bloc d'opérations « tout ou rien » : soit tout réussit, soit rien n'est appliqué. |
| **UNIQUE** | Contrainte interdisant deux fois la même valeur dans une colonne. |
| **Vue** | Requête enregistrée sous un nom, réutilisable comme une table. Ne stocke aucune donnée. |

---

## 11. Les questions que le client peut poser

Préparez ces réponses, ce sont les grands classiques :

**« Pourquoi une table `historique_statut` plutôt qu'une colonne statut ? »**
Parce que le cahier des charges demande de conserver l'historique des changements avec les dates. Une colonne écrasée à chaque étape perd l'information précédente.

**« Pourquoi `MISSION` est-elle une entité et pas une association ? »**
Parce qu'elle porte des données propres (période, statut, quota) et qu'elle doit être citée par `colis` et `historique_statut`. En Merise, une association ne peut pas être reliée à une autre association : on la réifie.

**« Pourquoi `colis.mis_id` peut-il être vide ? »**
Parce qu'un colis en cours de livraison n'a pas encore de point relais. La cardinalité est `0,1`, donc la clé étrangère est facultative. Mettre `1,1` rendrait impossible l'enregistrement d'un colis en tournée.

**« Vous avez à la fois `colis.col_statut` et la table d'historique, ce n'est pas redondant ? »**
Si, et c'est assumé. C'est une dénormalisation destinée à accélérer les écrans de consultation, qui sont appelés en permanence sur un gros volume. Les deux écritures sont faites dans la même transaction, et un contrôle vérifie qu'elles ne divergent pas.

**« Pourquoi les statuts ne sont-ils pas une table de référence ? »**
Parce qu'aucun des trois critères qui justifient une table de référence n'est rempli : la liste n'évolue pas (elle décrit le parcours physique décrit dans le cahier des charges), les valeurs ne portent pas de données propres, et l'intégrité est déjà garantie par le type énuméré - la base refuse `'PERDU_EN_ROUTE'` comme elle refuse `'depose_relai'`. En prime, le statut étant dans la table `colis`, on peut poser des règles `CHECK` qui le combinent à d'autres colonnes, ce qui était impossible avec une clé étrangère.

**« Et si le client veut ajouter un statut plus tard ? »**
Ce sera un `ALTER TABLE ... MODIFY COLUMN`, opération de maintenance sur une liste qui par définition ne bouge pas. Et si le besoin devenait vraiment évolutif - statuts administrables, libellés traduits, délais variables par statut - on recréerait une table de référence : la migration est directe, l'énuméré redevient une clé étrangère sans perte de données.

**« Comment garantissez-vous le délai de 14 jours ? »**
`col_date_limite_retrait` est une colonne **générée** par la base à partir de la date de dépôt. Elle ne peut pas être saisie ni modifiée, même par une requête directe : le test négatif du fichier 07 le démontre.

**« Pourquoi avoir fusionné les disponibilités ? »**
Voir la réponse rédigée au point 9 ci-dessus.

**« Que se passe-t-il si on supprime un transporteur ? »**
La base refuse (`ON DELETE RESTRICT`) tant qu'il a des colis ou des missions. C'est volontaire : ces données sont des traces contractuelles. Pour arrêter un partenariat, on passe `tra_est_actif` à faux, on ne supprime pas.
