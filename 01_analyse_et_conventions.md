# Dossier de conception - Plateforme « Point relais à domicile »

**Itération 1 - Conception de la base de données**
Méthode : Merise (Dictionnaire → MCD → MLD → SQL)
SGBD cible : MySQL 8 / MariaDB 10.6+
Modèle **simplifié** : 7 tables
---

# 1. Analyse du cahier des charges

## 1.1 De quoi parle-t-on ?

Une entreprise met en relation **trois populations** autour d'un objet central, le **colis** :

| Qui | Son rôle | Ce que la plateforme doit en savoir |
|---|---|---|
| **Le particulier** | Prête son domicile comme point relais | Qui il est, où il habite, comment le joindre, ce que son logement permet de stocker, quand il est disponible, s'il est actif |
| **Le transporteur** | Confie le « dernier kilomètre » aux points relais | Identité de la société, contact, dates du partenariat |
| **Le client final** | Reçoit le colis et vient le retirer | Qui il est, comment le prévenir, son adresse de livraison |

Le lien entre un particulier et un transporteur s'appelle une **mission** : elle est bornée dans le temps, et c'est elle qui autorise le particulier à recevoir des colis pour ce transporteur.

Le **colis** traverse un parcours strict, et **chaque étape doit être conservée** (date, point relais, transporteur). C'est le point le plus structurant du sujet.

## 1.2 Le parcours du colis

```
        (1) EN_COURS_LIVRAISON
                  │  livraison à domicile impossible ou non souhaitée
                  ▼
        (2) DEPOSE_RELAIS ──────────────► (3) RETIRE_CLIENT   [fin normale]
             │   ← le compte à rebours          le client est venu
             │      de 14 jours démarre ici
             │
             │ 14 jours écoulés → traitement automatique
             ▼
        (4) NON_RECLAME
                  │  le colis entre en processus de retour
                  ▼
        (5) EN_ATTENTE_REPRISE
                  │  le transporteur repasse
                  ▼
        (6) REPRIS_TRANSPORTEUR  [fin sans remise au client]
```

> **Pourquoi distinguer (4) et (5) ?** L'étape 4 est un **événement** : « le délai vient d'expirer », détecté automatiquement. L'étape 5 est un **état logistique** : « le colis est toujours chez le particulier et attend le camion ». Les séparer permet de mesurer combien de temps le transporteur met à venir récupérer ses retours - un indicateur que le cahier des charges appelle implicitement en demandant d'« identifier ceux devant être retournés ».

## 1.3 Les scénarios (cas d'utilisation)

C'est la liste de tout ce que quelqu'un voudra faire avec le système. Chaque scénario doit trouver sa réponse dans le modèle - sinon il manque une donnée.

### Le particulier

| # | Scénario | Tables concernées |
|---|---|---|
| UC01 | Créer son compte : identité, adresse, description du logement, disponibilités | `particulier`, `adresse` |
| UC02 | Mettre à jour ses informations ou ses disponibilités | `particulier` |
| UC03 | Candidater auprès d'un transporteur | `mission` |
| UC04 | Réceptionner un colis déposé par un transporteur | `colis`, `historique_statut` |
| UC05 | Remettre un colis au client (avec contrôle du code de retrait) | `colis`, `historique_statut` |
| UC06 | Rendre un colis non réclamé au transporteur | `colis`, `historique_statut` |
| UC07 | Consulter les colis actuellement sous sa garde | consultation |
| UC08 | Cesser son activité | `particulier`, `mission` |

### Le transporteur

| # | Scénario | Tables concernées |
|---|---|---|
| UC09 | Rechercher des points relais disponibles sur une zone | consultation |
| UC10 | Accepter ou refuser une candidature, ouvrir une mission datée | `mission` |
| UC11 | Enregistrer la prise en charge d'un colis | `colis`, `historique_statut` |
| UC12 | Déposer un colis chez un point relais | `colis`, `historique_statut` |
| UC13 | Consulter les colis à venir récupérer | consultation |
| UC14 | Reprendre un colis non réclamé | `colis`, `historique_statut` |
| UC15 | Clôturer une mission | `mission` |

### Le client final

| # | Scénario | Tables concernées |
|---|---|---|
| UC16 | Être prévenu que son colis est disponible | consultation |
| UC17 | Retirer son colis au point relais | `colis`, `historique_statut` |
| UC18 | Suivre l'état de son colis | consultation |

### La consultation / le pilotage

| # | Scénario | Réponse fournie |
|---|---|---|
| UC19 | Voir l'état d'un colis et tout son historique | vue `v_historique_colis` |
| UC20 | Lister les points relais réellement actifs | vue `v_point_relais_actif` |
| UC21 | Lister les colis **en attente de retrait** | vue `v_colis_en_attente_retrait` |
| UC22 | Lister les colis **à retourner** | vue `v_colis_a_retourner` |
| UC23 | Lister les colis **repris par les transporteurs** | requête dans `07_tests_use_cases.sql` |

### Le traitement automatique

| # | Scénario | Tables concernées |
|---|---|---|
| UC24 | Chaque nuit, basculer en `NON_RECLAME` tout colis dont le délai de 14 jours est dépassé | `colis`, `historique_statut` |

## 1.4 Les règles de gestion

Ce sont les affirmations du métier qu'il faut traduire dans le modèle. On les numérote pour pouvoir y faire référence partout ailleurs.

| Réf. | Règle | Où elle est appliquée |
|---|---|---|
| RG01 | Un particulier a un compte unique, identifié par son adresse e-mail | contrainte `UNIQUE` sur `par_email` |
| RG02 | Un particulier décrit son logement dans sa fiche : type, capacité, sécurisation | colonnes de `particulier` |
| RG03 | Un particulier indique ses disponibilités sous forme de texte libre | colonne `par_disponibilites` |
| RG04 | Un particulier est un point relais **actif** s'il a au moins une mission en cours à la date du jour | vue `v_point_relais_actif` |
| RG05 | Une mission lie **un** particulier et **un** transporteur sur une période donnée | table `mission` |
| RG06 | Un même couple (particulier, transporteur) n'a qu'une seule mission active à la fois | contrainte `UNIQUE` partielle + contrôle applicatif |
| RG07 | Un colis est pris en charge par **un seul** transporteur | clé étrangère obligatoire |
| RG08 | Un colis est destiné à **un seul** client final | clé étrangère obligatoire |
| RG09 | Un colis n'est rattaché à une mission qu'**au moment de son dépôt** | clé étrangère facultative + contrainte `CHECK` |
| RG10 | Date limite de retrait = date de dépôt **+ 14 jours** | colonne calculée par la base |
| RG11 | Tout changement d'état est conservé, avec sa date, le point relais et le transporteur | table `historique_statut` |
| RG12 | Le statut courant d'un colis est celui de son dernier changement d'état | colonne `colis.col_statut` (voir §2.4) |
| RG13 | Le nombre de colis simultanément gardés ne dépasse pas la capacité déclarée | contrôle applicatif + vue de suivi |
| RG14 | La référence d'un colis est unique sur toute la plateforme | contrainte `UNIQUE` |
| RG15 | La remise au client exige un code de retrait à 6 caractères | colonne `col_code_retrait` |
| RG16 | Les mots de passe ne sont jamais stockés en clair | colonne de hachage `CHAR(60)` |
| RG17 | Un point relais peut gérer plusieurs colis, pour plusieurs transporteurs à la fois | cardinalités du modèle |


## 1.5 Les questions à poser au futur client (Besoins clients)

Le cahier des charges ne tranche pas ces points. Les poser vaut des points en soutenance : ça montre qu'on a lu en cherchant les zones d'ombre, pas seulement les évidences.

1. **Rémunération** - le particulier est-il payé au colis ou à la mission ? Faut-il tracer une facturation ? *(non modélisé à ce stade)*
2. **Zones de couverture** - le transporteur définit-il des zones géographiques d'éligibilité ? *(on se contente aujourd'hui de l'adresse du particulier)*
3. **Le délai de 14 jours** - est-il le même pour tous les transporteurs, ou négociable par contrat ? *(hypothèse retenue : constante ; sinon il faudrait une colonne `mis_delai_conservation_jours`)*
4. **Le client final** - a-t-il un compte, ou est-il seulement une donnée transmise par le transporteur ? *(hypothèse : pas de compte)*
5. **Refus à la livraison** - le particulier peut-il refuser un colis trop volumineux ? Faut-il un statut `REFUSE_RELAIS` ?
6. **Historique des modifications de profil** - faut-il garder trace des anciennes adresses et disponibilités, ou la dernière valeur suffit-elle ? *(hypothèse : la dernière valeur suffit)*
7. **Interface d'administration** - le cahier des charges mentionne un back-office interne. Nous ne stockons pas encore les comptes administrateurs (voir §2.5) : à confirmer.
8. **RGPD** - combien de temps garde-t-on les données personnelles après clôture d'un compte ? Faut-il anonymiser ?

---

# 2. Préparation - conventions et méthode

## 2.1 Conventions de nommage

### Règles générales

| Élément | Convention | Exemple |
|---|---|---|
| Langue | **Français** - le métier est décrit en français, on évite les traductions approximatives | `colis`, `transporteur` |
| Casse | `snake_case`, **minuscules uniquement** | `historique_statut` |
| Accents et espaces | **Interdits** dans tous les noms de tables et de colonnes | `disponibilites`, jamais `disponibilités` |
| Longueur | 30 caractères maximum | |
| Mots réservés SQL | Interdits comme noms (`order`, `group`, `date`…) | |

### Les tables

- Nom au **singulier** : une ligne représente **une** occurrence → `colis`, `mission`, `client`.
- Table d'historique : préfixe `historique_` → `historique_statut`.
- Vues : préfixe `v_` → `v_colis_en_attente_retrait`.

### Les colonnes

Chaque colonne porte un **préfixe de 3 lettres** rappelant sa table :

| Table | Préfixe | Table | Préfixe |
|---|---|---|---|
| `adresse` | `adr_` | `mission` | `mis_` |
| `particulier` | `par_` | `colis` | `col_` |
| `transporteur` | `tra_` | `colis` | `col_` |
| `client` | `cli_` | `historique_statut` | `his_` |

Le bénéfice est immédiat dès qu'une requête assemble plusieurs tables : on lit `tra_raison_sociale` et on sait d'où ça vient, sans avoir à déchiffrer les alias.

- **Clé primaire** : `<préfixe>_id`, un simple numéro auto-incrémenté → `col_id`.
- **Clé étrangère** : elle **garde le nom** de la clé primaire qu'elle cite → `colis.tra_id` cite `transporteur.tra_id`. Aucun renommage, ce qui permet d'écrire `USING (tra_id)` en SQL.
- **Booléen** (vrai/faux) : préfixe `est_` ou `a_` → `par_est_actif`, `par_a_ascenseur`.
- **Date** : préfixe `date_` → `col_date_depot_relais`.
- **Unité de mesure** dans le nom → `col_poids_kg`, `par_surface_stockage_m2`.

### Les contraintes et les index

| Type | Préfixe | Exemple |
|---|---|---|
| Clé primaire | `pk_` | `pk_colis` |
| Clé étrangère | `fk_<table>_<table_citée>` | `fk_colis_transporteur` |
| Unicité | `uq_<table>_<colonne>` | `uq_colis_reference` |
| Règle de validation | `ck_<table>_<règle>` | `ck_colis_poids` |
| Index | `idx_<table>_<colonnes>` | `idx_colis_statut` |

**Pourquoi nommer ses contraintes ?** Parce que le message d'erreur devient lisible. Comparez :

```
ERROR 4025: CONSTRAINT `colis_chk_1` failed        ← nom automatique, inexploitable
ERROR 4025: CONSTRAINT `ck_colis_poids` failed     ← on sait immédiatement quoi corriger
```

### Le choix des types

| Nature de la donnée | Type retenu | Pourquoi |
|---|---|---|
| Identifiant technique | `INT UNSIGNED AUTO_INCREMENT` - `BIGINT` pour `colis` et `historique_statut`, `SMALLINT`/`TINYINT` pour les petites tables | On dimensionne selon le volume attendu. Le cahier des charges annonce « un volume important de colis ». |
| Texte de longueur variable | `VARCHAR(n)` | |
| Texte de longueur **fixe** | `CHAR(n)` | code postal `CHAR(5)`, SIRET `CHAR(14)`, hachage `CHAR(60)` |
| Vrai / faux | `BOOLEAN` | |
| Date seule | `DATE` | date de naissance, bornes de mission |
| Date **et heure** | `DATETIME` | horodatage des changements d'état |
| Montant, poids, mesure | `DECIMAL(p,s)` | **jamais** `FLOAT` : erreurs d'arrondi inacceptables |
| Liste courte et figée | `ENUM(...)` | `col_statut`, `his_statut`, `mis_statut`, `par_type_logement`, `par_civilite` |
| Liste évolutive ou porteuse de données | table de référence + clé étrangère | *(aucune dans ce modèle)* |

> **Comment choisir entre `ENUM` et une table de référence ?**
> Posons-nous ces trois questions. **Une seule réponse « oui » suffit à justifier une table de référence :**
> 1. Le client doit-il pouvoir **ajouter ou renommer** des valeurs lui-même ?
> 2. Chaque valeur porte-t-elle des **données propres** à maintenir (libellé traduit, couleur, délai spécifique) ?
> 3. La liste doit-elle être **partagée** avec d'autres systèmes ou alimentée dynamiquement ?
>
> Trois « non » → **`ENUM`**. C'est le cas de toutes nos listes, y compris les 6 statuts de colis.
>
> ⚠️ **Le malentendu à éviter :** un `ENUM` n'est pas une colonne de texte libre. La base **refuse** toute valeur hors de la liste déclarée, exactement comme une clé étrangère refuse un identifiant inexistant. Le choix `ENUM` vs table de référence est une question d'**évolutivité**, jamais une question d'**intégrité**.
>
> 💡 **Deux avantages peu connus de l'`ENUM` :** MySQL le trie selon l'**ordre de déclaration** des valeurs (donc déclarer les statuts dans l'ordre du parcours donne un tri chronologique gratuit) ; et comme la valeur est stockée dans la table, elle peut être utilisée dans une contrainte `CHECK` combinée à d'autres colonnes - ce qu'une clé étrangère vers une table externe ne permet pas.

### Les autres règles

- Encodage `utf8mb4` / collation `utf8mb4_unicode_ci` : les accents et les caractères spéciaux passent sans problème, et les comparaisons ignorent les majuscules.
- Moteur **InnoDB** exclusivement : c'est le seul de MySQL qui gère les clés étrangères et les transactions.
- `NOT NULL` par défaut. Chaque colonne autorisée à rester vide doit avoir une raison métier claire - par exemple `col_date_depot_relais` reste vide tant que le colis est dans le camion.
- Mots-clés SQL en **MAJUSCULES**, noms de tables et colonnes en minuscules.

## 2.2 La notation Merise que nous utilisons

- **Entité** : rectangle. Nom au singulier en majuscules en en-tête, identifiant en première ligne.
- **Association** : ovale, nommée par un **verbe**.
- **Cardinalités** : notées **sur le trait, du côté de l'entité**, sous la forme `min,max`. Elles décrivent ce que fait **une seule** occurrence de cette entité.
- Quatre valeurs seulement : `0,1` · `1,1` · `0,n` · `1,n`.

## 2.3 L'outillage

| Étape | Outil | Pourquoi |
|---|---|---|
| Dictionnaire | Markdown (ou un tableur) | versionnable, facile à relire à deux |
| MCD | **Mermaid** (`mcd.mermaid`) | s'affiche dans GitHub, VS Code, mermaid.live |
| MLD | **Mermaid** (`mld.mermaid`) | notation clé primaire / clé étrangère native |
| Scripts | Fichiers `.sql` | directement exécutables |
| Alternatives | AnalyseSI, Looping, Mocodo, DB Designer | génèrent le MLD automatiquement à partir du MCD |

> **Pourquoi du texte plutôt que des images ?** Parce qu'on travaille à deux. Un fichier Mermaid se modifie en parallèle et se fusionne ; un fichier image, non. Et les diagrammes restent versionnés avec le reste du dossier.
>
> Pour visualiser : ouvrez https://mermaid.live et collez le contenu de `mcd.mermaid` ou `mld.mermaid`. Les rendus PNG/SVG sont aussi fournis dans le dossier.

## 2.4 Une décision à savoir défendre : `colis.col_statut`

La table `colis` contient une colonne `col_statut` qui donne son **statut actuel**. Cette information est théoriquement déductible de la table d'historique : il suffirait de chercher la ligne la plus récente pour ce colis.

**Alors pourquoi la stocker quand même ?** Parce que la question « quels colis sont en attente de retrait ? » sera posée en permanence, sur un volume important. Sans cette colonne, il faudrait parcourir l'historique complet de chaque colis à chaque affichage.

On appelle ça une **dénormalisation** : une redondance acceptée volontairement, en échange de rapidité. Elle n'est acceptable qu'à deux conditions, toutes deux respectées ici :

1. **Elle est documentée** (ce paragraphe), sinon un relecteur y verra une erreur de conception.
2. **Les deux écritures sont toujours faites ensemble**, dans la même transaction. Le script `07_tests_use_cases.sql` contient un contrôle (test T1) qui vérifie que les deux informations n'ont jamais divergé.

## 2.5 Les simplifications assumées de ce modèle

Ce modèle compte **7 tables**. Une version plus complète en comptait 12. Voici ce qui a été retiré et ce que ça implique - savoir l'expliquer vaut mieux que d'avoir le modèle le plus gros.

| Retiré | Devenu | Ce qu'on perd |
|---|---|---|
| Table `ADMINISTRATEUR` | *(rien)* | On ne trace plus **qui**, dans l'entreprise, a effectué une correction. La consultation reste possible via les vues. |
| Table `LOGEMENT` | 6 colonnes dans `particulier` | **Rien.** La relation était « un particulier = un logement » : deux tables avec le même nombre de lignes n'ont pas lieu d'être séparées. C'est un gain net. |
| Table `TYPE_LOGEMENT` | colonne `par_type_logement` (`ENUM`) | Ajouter un type demandera de modifier la table (`ALTER TABLE`) au lieu d'insérer une ligne. |
| Table `STATUT_COLIS` | colonnes `col_statut` et `his_statut` (`ENUM`) | Le libellé affichable n'est plus stocké, et un statut sans aucun colis n'apparaît plus dans les statistiques. Voir ci-dessous. |
| Table `DISPONIBILITE` | colonne texte `par_disponibilites` | **On perd la capacité d'interroger les créneaux.** Voir ci-dessous. |

> **Attention : ces quatre suppressions ne relèvent pas du même raisonnement.** Deux critères distincts sont à l'œuvre et à valider :
> - **la cardinalité**, pour décider si deux tables doivent fusionner (`LOGEMENT`, `DISPONIBILITE`) ;
> - **l'évolutivité**, pour décider si une liste de valeurs mérite une table de référence (`TYPE_LOGEMENT`, `STATUT_COLIS`).

### Le cas des statuts : pourquoi un énuméré suffit

Une table de référence ne se justifie que si **au moins l'un** de ces trois points est vrai :

| Critère | Est-ce le cas pour les statuts de colis ? |
|---|---|
| La liste **évolue** - le client doit pouvoir en ajouter ou en renommer | ❌ Non : les 6 statuts décrivent le parcours physique du colis, écrit noir sur blanc dans le cahier des charges. |
| Chaque valeur **porte des données propres** à maintenir | ❌ Non : le code du statut se suffit à lui-même. |
| L'**intégrité** ne peut être garantie autrement | ❌ Non : le type énuméré la garantit lui-même. |

**Le point le plus important à comprendre :** un `ENUM` n'est **pas** du texte libre. La colonne n'accepte que les 6 valeurs déclarées ; écrire `'PERDU_EN_ROUTE'` - ou `'depose_relai'` avec une faute de frappe - provoque une erreur, exactement comme une clé étrangère invalide. Les tests négatifs du fichier 07 le démontrent.

**Ce que le changement apporte :**

- une jointure de moins dans **chaque** requête de consultation ;
- des écritures plus courtes : `col_statut = 'DEPOSE_RELAIS'` au lieu d'une sous-requête pour retrouver l'identifiant ;
- le **tri chronologique gratuit** : les 6 valeurs sont déclarées dans l'ordre du parcours, et MySQL trie un énuméré selon cet ordre de déclaration. C'est ce qui remplace l'ancienne colonne `sta_ordre` ;
- **et surtout trois règles nouvelles**, jusqu'ici impossibles. Une contrainte `CHECK` ne peut porter que sur des colonnes de **sa propre table** : tant que le statut vivait ailleurs, la règle « un colis terminé a forcément une date de clôture » aurait exigé une jointure. Elle est désormais garantie par la base (`ck_colis_cloture`, `ck_colis_statut_depot`, `ck_historique_mission`).

**Ce que ça coûte :** ajouter un 7ᵉ statut demandera un `ALTER TABLE` ; et le libellé lisible (« Déposé au point relais ») est reconstruit par une expression `CASE` dans les vues plutôt que stocké - ce qui, accessoirement, facilitera une future traduction.

### Le seul vrai compromis : les disponibilités

Avant, un créneau était une ligne : `(Sophie, mardi, 18h00, 20h30)`. On pouvait demander à la base « qui est disponible mardi soir dans le 69003 ? » et elle savait répondre.

Maintenant c'est du texte : `"Lun-Ven 18h-20h30, Sam 9h-12h"`. Lisible par un humain, opaque pour la base : impossible de filtrer dessus, et rien n'interdit une saisie fantaisiste.

**Pourquoi c'est acceptable ici :** aucun des 24 scénarios n'exige de rechercher par créneau horaire. Le texte suffit à afficher les horaires sur la fiche d'un point relais.

**La formulation à retenir si l'on veut fournir une explication technique :**

> « Nous avons fusionné les disponibilités dans une colonne texte pour simplifier le modèle, parce qu'aucun cas d'utilisation ne demande de filtrer par créneau. Si ce besoin apparaît - typiquement "trouver les relais ouverts le samedi matin" -, il faudra ressortir une table `disponibilite` reliée en `0,n` au particulier. Le changement resterait isolé : aucune autre table n'est impactée. »

### La règle à retenir

> **Fusionner deux tables est un gain quand la relation est « 1 pour 1 ».
> C'est une perte quand la relation est « 1 pour plusieurs ».**

`LOGEMENT` était en 1-pour-1 → la fusion supprime une table et une jointure sans rien coûter.
`DISPONIBILITE` était en 1-pour-plusieurs → la fusion écrase plusieurs lignes dans une chaîne de caractères.

C'est précisément le raisonnement que l'exercice cherche à évaluer.
