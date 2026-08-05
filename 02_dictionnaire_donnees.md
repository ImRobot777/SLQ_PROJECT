# 3. Dictionnaire des données

> **À quoi sert ce document ?** À lister **toutes** les informations qu'il faudra mémoriser, **sans se demander encore dans quelle table elles iront**. C'est la matière première du modèle : à l'étape suivante (le MCD), on les regroupera en paquets.

**Comment lire les colonnes :**

| Colonne | Signification |
|---|---|
| **Code mnémonique** | Le nom technique de la donnée, tel qu'il apparaîtra dans la base |
| **Désignation** | Ce que c'est, en français |
| **Type** | La nature de la donnée (texte, entier, date…) |
| **Taille** | La place qu'elle occupe |
| **Contraintes** | Est-elle obligatoire ? unique ? quelles valeurs sont permises ? |
| **Nature** | `E` = à stocker · `C` = calculable, donc **non stockée** · `CC` = assemblage de plusieurs données |

> **La règle importante :** on **ne stocke pas** les données de nature `C`. L'âge d'une personne se déduit de sa date de naissance : le stocker, ce serait avoir une valeur fausse dès le lendemain de son anniversaire. On les repère quand même dans le dictionnaire, pour montrer qu'on y a pensé.
>
> Deux exceptions assumées sont signalées **`C stockée`** : elles sont justifiées au §2.4 du document 01.

---

## 3.1 Adresse

*Une seule table d'adresses, partagée par les particuliers, les transporteurs et les clients - plutôt que trois blocs de colonnes recopiés.*

| Code mnémonique | Désignation | Type | Taille | Contraintes / observations | Nature |
|---|---|---|---|---|---|
| `adr_id` | Identifiant de l'adresse | Entier | INT UNSIGNED | Clé primaire, auto-incrémentée | E |
| `adr_numero` | Numéro dans la voie | Texte | 10 | Facultatif ; alphanumérique pour gérer « 12 bis » | E |
| `adr_voie` | Nom de la voie | Texte | 150 | Obligatoire | E |
| `adr_complement` | Complément d'adresse | Texte | 150 | Bâtiment, résidence, étage - facultatif | E |
| `adr_code_postal` | Code postal | Texte fixe | 5 | Obligatoire, exactement 5 chiffres | E |
| `adr_ville` | Ville | Texte | 100 | Obligatoire | E |
| `adr_pays` | Pays | Texte | 60 | Obligatoire, « France » par défaut | E |
| `adr_latitude` | Latitude GPS | Décimal | 9,6 | Facultatif - pour situer les points relais sur une carte (UC09) | E |
| `adr_longitude` | Longitude GPS | Décimal | 9,6 | Facultatif | E |
| *adresse complète* | Adresse formatée sur une ligne | - | - | Assemblage des colonnes ci-dessus | CC |

## 3.2 Particulier (candidat / point relais)

*C'est la table qui a le plus grossi lors de la simplification : elle absorbe les anciennes tables `LOGEMENT`, `TYPE_LOGEMENT` et `DISPONIBILITE`.*

### Identité et compte

| Code mnémonique | Désignation | Type | Taille | Contraintes / observations | Nature |
|---|---|---|---|---|---|
| `par_id` | Identifiant du particulier | Entier | INT UNSIGNED | Clé primaire, auto-incrémentée | E |
| `par_civilite` | Civilité | Liste figée | M / MME / AUTRE | Obligatoire | E |
| `par_nom` | Nom de famille | Texte | 80 | Obligatoire | E |
| `par_prenom` | Prénom | Texte | 80 | Obligatoire | E |
| `par_date_naissance` | Date de naissance | Date | - | Obligatoire - permet de vérifier la majorité | E |
| `par_email` | Adresse e-mail | Texte | 150 | Obligatoire, **unique** - sert d'identifiant de connexion (RG01) | E |
| `par_telephone` | Téléphone | Texte | 20 | Obligatoire - le client doit pouvoir le joindre | E |
| `par_mot_de_passe_hash` | Empreinte du mot de passe | Texte fixe | 60 | Obligatoire - hachage bcrypt, **jamais le mot de passe lui-même** (RG16) | E |
| `par_date_inscription` | Date de création du compte | Date + heure | - | Obligatoire, date du jour par défaut | E |

### Description du logement *(ex-tables `LOGEMENT` et `TYPE_LOGEMENT`)*

| Code mnémonique | Désignation | Type | Taille | Contraintes / observations | Nature |
|---|---|---|---|---|---|
| `par_type_logement` | Type de logement | Liste figée | MAISON / APPARTEMENT / LOCAL_PRO / ATELIER | Obligatoire | E |
| `par_etage` | Étage | Entier | TINYINT | 0 = rez-de-chaussée ; facultatif | E |
| `par_a_ascenseur` | Présence d'un ascenseur | Vrai/Faux | - | Faux par défaut | E |
| `par_surface_stockage_m2` | Surface dédiée au stockage | Décimal | 5,2 | En m², doit être positive ; facultatif | E |
| `par_capacite_max_colis` | Nombre maximal de colis stockés en même temps | Entier | SMALLINT | Obligatoire, supérieur à 0 (RG13) | E |
| `par_est_securise` | Espace de stockage sécurisé | Vrai/Faux | - | Faux par défaut - critère d'éligibilité pour les transporteurs | E |
| `par_commentaire_acces` | Précisions sur l'accès au logement | Texte | 255 | Facultatif - « portail automatique », « sonner à l'interphone »… | E |

### Disponibilités *(ex-table `DISPONIBILITE`)*

| Code mnémonique | Désignation | Type | Taille | Contraintes / observations | Nature |
|---|---|---|---|---|---|
| `par_disponibilites` | Créneaux de disponibilité | Texte | 255 | Texte libre : « Lun-Ven 18h-20h30, Sam 9h-12h ». ⚠️ Non interrogeable par la base - compromis assumé (§2.5) | E |

### Statut du compte

| Code mnémonique | Désignation | Type | Taille | Contraintes / observations | Nature |
|---|---|---|---|---|---|
| `par_est_eligible` | Éligibilité validée | Vrai/Faux | - | Faux par défaut - le logement répond aux besoins des transporteurs | E |
| `par_est_actif` | Compte actif | Vrai/Faux | - | Faux par défaut - tous les inscrits ne sont pas points relais | E |
| `par_date_desactivation` | Date de désactivation | Date + heure | - | Vide si le compte est actif | E |
| *par_age* | Âge du particulier | Entier | - | Se déduit de la date de naissance | C |
| *par_est_point_relais_actif* | Point relais réellement opérationnel | Vrai/Faux | - | Se déduit : compte actif **et** au moins une mission en cours (RG04) | C |
| *par_places_disponibles* | Places de stockage restantes | Entier | - | Capacité maximale − colis actuellement gardés | C |

## 3.3 Transporteur partenaire

| Code mnémonique | Désignation | Type | Taille | Contraintes / observations | Nature |
|---|---|---|---|---|---|
| `tra_id` | Identifiant du transporteur | Entier | SMALLINT UNSIGNED | Clé primaire - quelques dizaines de partenaires attendus, inutile de prévoir plus grand | E |
| `tra_raison_sociale` | Raison sociale | Texte | 120 | Obligatoire | E |
| `tra_siret` | Numéro SIRET | Texte fixe | 14 | Obligatoire, **unique**, exactement 14 chiffres | E |
| `tra_email` | E-mail de contact | Texte | 150 | Obligatoire | E |
| `tra_telephone` | Téléphone de contact | Texte | 20 | Obligatoire | E |
| `tra_contact_nom` | Nom de l'interlocuteur | Texte | 120 | Facultatif | E |
| `tra_date_debut_partenariat` | Début du partenariat | Date | - | Obligatoire | E |
| `tra_date_fin_partenariat` | Fin du partenariat | Date | - | Vide = partenariat toujours en cours | E |
| `tra_est_actif` | Partenaire actif | Vrai/Faux | - | Vrai par défaut | E |

## 3.4 Client final

| Code mnémonique | Désignation | Type | Taille | Contraintes / observations | Nature |
|---|---|---|---|---|---|
| `cli_id` | Identifiant du client | Entier | INT UNSIGNED | Clé primaire | E |
| `cli_civilite` | Civilité | Liste figée | M / MME / AUTRE | Facultatif | E |
| `cli_nom` | Nom du destinataire | Texte | 80 | Obligatoire | E |
| `cli_prenom` | Prénom du destinataire | Texte | 80 | Obligatoire | E |
| `cli_email` | E-mail | Texte | 150 | Facultatif - sert à prévenir de la mise à disposition (UC16) | E |
| `cli_telephone` | Téléphone | Texte | 20 | Facultatif - SMS de mise à disposition | E |

> ⚠️ E-mail **et** téléphone sont facultatifs individuellement, mais **au moins l'un des deux** est obligatoire : sans aucun moyen de contact, impossible de prévenir le client. C'est une contrainte `CHECK` dans le script de création.

## 3.5 Mission de point relais

*Une mission, c'est le contrat entre un particulier et un transporteur, sur une période donnée.*

| Code mnémonique | Désignation | Type | Taille | Contraintes / observations | Nature |
|---|---|---|---|---|---|
| `mis_id` | Identifiant de la mission | Entier | INT UNSIGNED | Clé primaire | E |
| `mis_date_candidature` | Date de la candidature | Date + heure | - | Obligatoire (UC03) | E |
| `mis_date_validation` | Date d'acceptation par le transporteur | Date + heure | - | Vide tant que la candidature n'est pas traitée | E |
| `mis_date_debut` | Début de la mission | Date | - | Obligatoire (RG05) | E |
| `mis_date_fin` | Fin de la mission | Date | - | Vide = durée indéterminée ; sinon postérieure au début | E |
| `mis_statut` | Statut de la mission | Liste figée | EN_ATTENTE / ACTIVE / SUSPENDUE / TERMINEE / REFUSEE | Obligatoire, `EN_ATTENTE` par défaut | E |
| `mis_capacite_max_colis` | Quota de colis alloué à ce transporteur | Entier | SMALLINT | Facultatif, inférieur ou égal à la capacité du particulier | E |
| `mis_commentaire` | Motif de refus ou remarque | Texte | 255 | Facultatif | E |
| *mis_est_en_cours* | Mission active aujourd'hui | Vrai/Faux | - | Se déduit du statut et des dates | C |

## 3.6 Les 6 statuts d'un colis

*Ce n'est **pas** une rubrique de données au même titre que les autres : les statuts ne sont pas une table, mais une **liste de valeurs autorisées** inscrite directement dans la définition de deux colonnes - `col_statut` (le statut courant du colis) et `his_statut` (le statut atteint à chaque événement de l'historique).*

**Les 6 valeurs, déclarées dans l'ordre du parcours :**

| Rang | Valeur | Ce que ça veut dire | Statut terminal ? |
|---|---|---|---|
| 1 | `EN_COURS_LIVRAISON` | En cours de livraison par le transporteur | non |
| 2 | `DEPOSE_RELAIS` | Déposé au point relais | non |
| 3 | `RETIRE_CLIENT` | Retiré par le client final | **oui** |
| 4 | `NON_RECLAME` | Non réclamé - délai de 14 jours dépassé | non |
| 5 | `EN_ATTENTE_REPRISE` | En attente de reprise par le transporteur | non |
| 6 | `REPRIS_TRANSPORTEUR` | Repris par le transporteur | **oui** |

> **L'ordre de déclaration compte.** MySQL trie un type énuméré selon l'ordre dans lequel les valeurs ont été déclarées, et non par ordre alphabétique. En les inscrivant dans l'ordre du parcours, un simple `ORDER BY his_statut` restitue donc le déroulé chronologique du colis - sans avoir besoin d'une colonne « rang » dédiée.
>
> **Ce qui n'est plus stocké :** le libellé lisible (« Déposé au point relais ») et l'indicateur « statut terminal ». Le premier est reconstruit par une expression `CASE` dans les vues ; le second est écrit directement dans les règles qui en ont besoin. Le raisonnement complet est au §2.5 du document 01.

## 3.7 Colis

| Code mnémonique | Désignation | Type | Taille | Contraintes / observations | Nature |
|---|---|---|---|---|---|
| `col_id` | Identifiant du colis | Entier | BIGINT UNSIGNED | Clé primaire - **grand entier**, le cahier des charges annonce un volume important | E |
| `col_reference` | Référence de suivi | Texte | 30 | Obligatoire, **unique** (RG14) - c'est le numéro que voit le client | E |
| `col_statut` | Statut courant du colis | Liste figée | 6 valeurs (voir §3.6) | Obligatoire, `EN_COURS_LIVRAISON` par défaut. Redondant avec l'historique - **stocké volontairement** (RG12, §2.4) | **C stockée** |
| `col_poids_kg` | Poids | Décimal | 5,2 | Obligatoire, positif (ex. 124,50 g) | E |
| `col_longueur_cm` | Longueur | Entier | SMALLINT | En cm, facultatif | E |
| `col_largeur_cm` | Largeur | Entier | SMALLINT | En cm, facultatif | E |
| `col_hauteur_cm` | Hauteur | Entier | SMALLINT | En cm, facultatif | E |
| `col_valeur_declaree_eur` | Valeur déclarée | Décimal | 8,2 | En euros, facultatif - `DECIMAL` et jamais `FLOAT` | E |
| `col_est_fragile` | Colis fragile | Vrai/Faux | - | Faux par défaut | E |
| `col_code_retrait` | Code à présenter pour le retrait | Texte fixe | 6 | Généré au moment du dépôt (RG15) ; vide avant | E |
| `col_date_prise_en_charge` | Prise en charge par le transporteur | Date + heure | - | Obligatoire - c'est l'entrée du colis dans le système | E |
| `col_date_depot_relais` | Dépôt au point relais | Date + heure | - | Vide tant que le colis est en tournée | E |
| `col_date_limite_retrait` | Date limite de retrait | Date | - | **Calculée par la base** : dépôt + 14 jours (RG10) | **C stockée** |
| `col_date_cloture` | Fin du processus | Date + heure | - | Renseignée quand le colis atteint un statut terminal | E |
| *col_volume_cm3* | Volume | Entier | - | Longueur × largeur × hauteur | C |
| *col_jours_restants* | Jours restants avant expiration | Entier | - | Date limite − date du jour | C |

## 3.8 Historique des statuts

*Une ligne par changement d'état. C'est le cœur de l'exigence de traçabilité.*

| Code mnémonique | Désignation | Type | Taille | Contraintes / observations | Nature |
|---|---|---|---|---|---|
| `his_id` | Identifiant de l'événement | Entier | BIGINT UNSIGNED | Clé primaire - ce sera la table la plus volumineuse | E |
| `his_statut` | Statut atteint à cette date | Liste figée | 6 valeurs (voir §3.6) | Obligatoire - mêmes valeurs et même ordre que `col_statut` | E |
| `his_date_changement` | Date et heure du changement | Date + heure | - | Obligatoire, date du jour par défaut (RG11) | E |
| `his_origine` | Qui a déclenché le changement | Liste figée | TRANSPORTEUR / POINT_RELAIS / CLIENT / SYSTEME | Obligatoire | E |
| `his_commentaire` | Commentaire libre | Texte | 255 | Facultatif - « client absent », « saisie corrigée »… | E |

> Cette table portera aussi, par clé étrangère : **le colis** concerné et **la mission** - cette dernière donnant d'un seul coup le **point relais** et le **transporteur responsable**, exactement ce que le cahier des charges exige.

---

## 3.9 Récapitulatif

| Rubrique | Données à stocker | Données calculées |
|---|---|---|
| Adresse | 9 | 1 |
| Particulier | 20 | 3 |
| Transporteur | 9 | 0 |
| Client | 6 | 0 |
| Mission | 8 | 1 |
| Colis | 14 *(dont 2 « calculées mais stockées »)* | 2 |
| Historique | 5 | 0 |
| **Total** | **71** | **7** |

> Les clés étrangères n'apparaissent pas ici : elles n'existent pas encore. Elles seront **créées** à l'étape suivante, quand on transformera le MCD en MLD.

