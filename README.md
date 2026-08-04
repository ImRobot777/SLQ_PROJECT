# Contexte de conception - Livraison de colis via « Point relais à domicile »

Cahier des charges du projet concernant les besoins en matière de sauvegarde des données tel que recueilli par le commercial :

Une entreprise souhaite mettre en place une plateforme permettant à des particuliers de proposer leur domicile comme point relais pour la livraison de colis, en collaboration avec des transporteurs partenaires et à destination de clients finaux destinataires des colis.

Les particuliers souhaitant devenir point relais doivent créer un compte personnel sur la plateforme. Ce compte est associé à des informations d'identité, d'adresse, de contact, ainsi qu'à des informations décrivant leur logement et leurs disponibilités. Ces informations peuvent être modifiées dans le temps. Tous les particuliers inscrits ne sont pas nécessairement actifs en tant que point relais ; leur activation dépend de leur éligibilité vis-à-vis des besoins des transporteurs.

Les transporteurs partenaires utilisent la plateforme afin de s'appuyer sur ces points relais pour effectuer la livraison du dernier kilomètre. Lorsqu'un particulier est accepté par un transporteur, une mission de point relais est mise en place pour une période donnée. Cette mission permet au particulier de recevoir et de remettre des colis pour le compte du transporteur.

Les colis constituent l'élément central du système. Chaque colis est pris en charge par un transporteur et est destiné à un client final. Un colis est identifié de manière unique et possède des informations propres telles que ses caractéristiques physiques et son état d'avancement dans le processus de livraison.

Un colis suit un cycle de livraison précis. Il est d'abord en cours de livraison par le transporteur, puis il est remis au point relais lorsque la livraison à domicile du client n'est pas possible ou n'est pas souhaitée. Une fois arrivé au point relais, le colis est conservé temporairement par le particulier en attente de récupération par le client final.

Lorsque le client se présente au point relais, le colis lui est remis, ce qui marque la fin normale du processus de livraison. Toutefois, si le client ne récupère pas son colis dans un délai de quatorze jours, le colis doit être considéré comme non réclamé. Dans ce cas, le colis change de statut et entre dans un processus de retour.

Dans le cadre du retour, le colis reste temporairement au point relais dans l'attente de sa prise en charge par le transporteur. Une fois récupéré par le transporteur, le colis est retiré du point relais et le processus de livraison est considéré comme terminé, même si le colis n'a pas été remis au client final.

La plateforme doit conserver l'historique des changements d'état des colis, en incluant les dates correspondantes, le point relais concerné et le transporteur responsable. Un point relais peut gérer simultanément plusieurs colis, potentiellement pour plusieurs transporteurs, tant que des missions actives existent.

Une interface d'administration interne permet de consulter et gérer les points relais, les transporteurs, les missions et les colis. Elle permet notamment de suivre l'état des colis, d'identifier ceux en attente de retrait, ceux devant être retournés, et ceux ayant été récupérés par les transporteurs.

Le système devra être capable de gérer un volume important de colis tout en garantissant la cohérence des données, la traçabilité des colis et le respect des délais de conservation au point relais.


# Dossier de conception - Plateforme « Point relais à domicile »

Itération 1 - Conception d'une base de données relationnelle par la méthode **Merise**.
SGBD : **MySQL 8 / MariaDB 10.6+** · Encodage `utf8mb4` · Moteur InnoDB.

**7 tables · 81 colonnes · 10 clés étrangères · 17 règles de validation · 6 vues**

---

## 👉 Par où commencer ?

**Si vous n'êtes pas à l'aise avec Merise, les MCD, les MLD ou le SQL : lisez d'abord [`00_guide_pas_a_pas.md`](https://github.com/ImRobot777/SLQ_PROJECT/blob/main/00_guide_pas_a_pas.md).**
Ce document explique chaque notion au moment où elle sert, avec des exemples tirés de ce projet. Environ 25 minutes de lecture, et tout le reste devient limpide.

---

## Contenu du dossier

| Fichier | Étape du sujet | Ce que c'est |
|---|---|---|
| [**`00_guide_pas_a_pas.md`**](https://github.com/ImRobot777/SLQ_PROJECT/blob/main/00_guide_pas_a_pas.md) | - | **Le mode d'emploi.** Vocabulaire de base, Merise expliquée simplement, chaque étape commentée, glossaire, et les questions technique qui peuvent être posées. |
| [`01_analyse_et_conventions.md`](https://github.com/ImRobot777/SLQ_PROJECT/blob/main/01_analyse_et_conventions.md) | **1.1** + **1.2** | Analyse du cahier des charges, parcours du colis, 24 scénarios, 17 règles de gestion, questions au client, conventions de nommage et de typage. |
| [`02_dictionnaire_donnees.md`](https://github.com/ImRobot777/SLQ_PROJECT/blob/main/02_dictionnaire_donnees.md) | **1.3** | Le dictionnaire : 71 données à stocker + 7 données calculées, avec code, désignation, type, taille et contraintes. |
| [`03_mcd.md`](https://github.com/ImRobot777/SLQ_PROJECT/blob/main/03_mcd.md) | **1.4** | Le Modèle Conceptuel : 7 entités, 10 associations, cardinalités justifiées une par une. |
| [`mcd.mermaid`](https://github.com/ImRobot777/SLQ_PROJECT/blob/main/mcd.mermaid) | **1.4** | Le MCD en fichier autonome, à coller sur mermaid.live. |
| [`mcd.svg`](https://github.com/ImRobot777/SLQ_PROJECT/blob/main/mcd.svg) / [`mcd.png`](https://github.com/ImRobot777/SLQ_PROJECT/blob/main/mcd.png) | **1.4** | Le MCD en image, prêt à insérer dans un rapport. |
| [`04_mld.md`](https://github.com/ImRobot777/SLQ_PROJECT/blob/main/04_mld.md) | **1.5** | Le Modèle Logique : les 3 règles de transformation appliquées, le schéma des tables, le classement par niveaux, les politiques de suppression, les index. |
| [`mld.mermaid`](https://github.com/ImRobot777/SLQ_PROJECT/blob/main/mld.mermaid) | **1.5** | Le MLD en fichier autonome, à coller sur mermaid.live. |
| [`mld.svg`](https://github.com/ImRobot777/SLQ_PROJECT/blob/main/mld.svg) / [`mld.png`](https://github.com/ImRobot777/SLQ_PROJECT/blob/main/mld.png) | **1.5** | Le MLD en image. |
| [`05_creation_bdd.sql`](https://github.com/ImRobot777/SLQ_PROJECT/blob/main/05_creation_bdd.sql) | **1.6.1–3** | Création de la base, des 7 tables (dans l'ordre des niveaux) et des 6 vues. Entièrement commenté. |
| [`06_insertion_donnees.sql`](https://github.com/ImRobot777/SLQ_PROJECT/blob/main/06_insertion_donnees.sql) | **1.6.4** | Jeu de données : les cas nominaux et surtout les cas limites. |
| [`07_tests_use_cases.sql`](https://github.com/ImRobot777/SLQ_PROJECT/blob/main/07_tests_use_cases.sql) | **1.6.3** | 7 contrôles d'intégrité, 12 requêtes métier, 4 scénarios d'écriture, 12 tests négatifs. |
| [`08_verification.md`](https://github.com/ImRobot777/SLQ_PROJECT/blob/main/08_verification.md) | **1.6.3** | Compte rendu de l'exécution réelle et comparaison entre le MLD et la base créée. |

---

## Mise en route

```bash
mysql -u root -p < 05_creation_bdd.sql
mysql -u root -p < 06_insertion_donnees.sql
mysql -u root -p -t relais_domicile < 07_tests_use_cases.sql
```

Le premier script commence par `DROP DATABASE IF EXISTS` : vous pouvez le relancer autant de fois que nécessaire pendant la mise au point.

**Pour visualiser les diagrammes :** ouvrez https://mermaid.live et collez le contenu de `mcd.mermaid` ou `mld.mermaid`. (Les fichiers `.svg` et `.png` sont aussi fournis.)

---

## Le modèle en une page

```
Niveau 0 : adresse                             ← aucune clé étrangère
Niveau 1 : particulier · transporteur · client ← citent adresse
Niveau 2 : mission                             ← cite particulier et transporteur
Niveau 3 : colis                               ← cite mission, transporteur, client
Niveau 4 : historique_statut                   ← cite colis et mission
```

Ce classement donne l'ordre de création des tables **et** l'ordre d'insertion des données.

### Le parcours d'un colis

```
(1) EN_COURS_LIVRAISON ──► (2) DEPOSE_RELAIS ──► (3) RETIRE_CLIENT        [fin normale]
                                  │
                                  └─ 14 jours ─► (4) NON_RECLAME ──► (5) EN_ATTENTE_REPRISE
                                                                            │
                                                                            ▼
                                                             (6) REPRIS_TRANSPORTEUR  [fin]
```

Ces 6 valeurs sont un **type énuméré** (`col_statut`, `his_statut`), pas une table de référence. Elles sont déclarées **dans l'ordre du parcours**, ce qui fait qu'un simple `ORDER BY col_statut` trie chronologiquement.

---

## Les quatre décisions à savoir défendre

### 1. Le statut est un attribut énuméré, pas une entité

On crée une table de référence pour une liste de valeurs **seulement si** elle évolue, ou si elle porte des données propres, ou si son intégrité doit être garantie autrement. Aucun des trois n'est vrai ici : les 6 statuts décrivent un parcours physique décrit dans le cahier des charges, ils ne bougeront pas.

Et on ne perd **rien** sur l'intégrité : le type énuméré refuse `'PERDU_EN_ROUTE'` comme il refuse `'depose_relai'`. Les tests négatifs du fichier 07 le démontrent.

**On y gagne même quelque chose d'inattendu :** le statut vivant désormais dans la table `colis`, on peut poser des règles `CHECK` qui le combinent avec d'autres colonnes - « un colis terminé a forcément une date de clôture ». Avec une clé étrangère, cette règle aurait exigé une jointure, donc aurait été impossible à écrire.

### 2. `mission` est une entité, pas un simple lien

Le lien entre un particulier et un transporteur porte des données (période, statut, quota) **et** doit être désigné par le colis et par l'historique. Or en Merise, une association ne peut pas être reliée à une autre association : on la transforme en entité - c'est ce qu'on appelle une **réification**.

Le gain est très concret : quand une ligne d'historique cite une mission, elle indique **d'un seul coup** le point relais **et** le transporteur responsable, exactement les deux informations exigées par le cahier des charges.

### 3. L'historique est une table, pas une colonne

Le cahier des charges demande de « conserver l'historique des changements d'état ». Une simple colonne écrasée à chaque étape perdrait toute l'information précédente. La table `historique_statut` garde **une ligne par changement**.

La colonne `colis.col_statut` (le statut actuel) fait volontairement doublon, pour la rapidité des écrans de consultation. C'est une **dénormalisation assumée**, documentée, et vérifiée par un contrôle automatique.

### 4. Le délai de 14 jours est garanti par la base elle-même

`col_date_limite_retrait` est une **colonne calculée** : la base la déduit toute seule de la date de dépôt. Toute tentative de la modifier directement est rejetée.

---

## Les simplifications de ce modèle

Ce modèle compte 7 tables. La première version en comptait 12.

| Retiré | Devenu | Ce qu'on perd |
|---|---|---|
| `ADMINISTRATEUR` | *(rien)* | On ne trace plus qui, en interne, a fait une correction |
| `LOGEMENT` | 6 colonnes dans `particulier` | **Rien** - la relation était 1-pour-1, la fusion est un gain net |
| `TYPE_LOGEMENT` | un `ENUM` dans `particulier` | Ajouter un type demandera un `ALTER TABLE` |
| `DISPONIBILITE` | une colonne texte dans `particulier` | On ne peut plus interroger les créneaux horaires |
| `STATUT_COLIS` | un `ENUM` dans `colis` et `historique_statut` | Le libellé affichable n'est plus stocké (il est reconstruit par un `CASE` dans les vues), et un statut sans aucun colis n'apparaît plus dans les statistiques |

> **Les deux règles qui gouvernent ces choix :**
>
> **① Fusionner deux tables est un gain quand la relation est « 1 pour 1 », une perte quand elle est « 1 pour plusieurs ».**
> `LOGEMENT` était en 1-pour-1 → gain net. `DISPONIBILITE` était en 1-pour-plusieurs → on a écrasé plusieurs lignes dans une chaîne de caractères.
>
> **② Liste figée et sans données propres → énuméré. Liste administrable ou porteuse d'informations → table de référence.**
> Les statuts de colis, le type de logement et le statut de mission relèvent tous du premier cas.
>
> Le raisonnement détaillé, et la formulation à utiliser si le client pose la question, se trouvent au §9 du guide, au §2.5 du document 01 et au §4.5 du document 03.
