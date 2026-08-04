# 6. Vérification - le script a-t-il vraiment fonctionné ?

> Le sujet (étape 1.6.3) demande de **lancer le script sur un serveur**, de **générer le schéma de la base créée** et de **comparer les deux schémas**. C'est ce que fait ce document.

**Environnement de test :** MariaDB 10.11.14 · moteur InnoDB · encodage `utf8mb4_unicode_ci` · exécuté le 2026-08-04.

---

## 6.1 Résultat de l'exécution

| Script | Résultat |
|---|---|
| `05_creation_bdd.sql` | ✅ 7 tables et 6 vues créées, **aucune erreur** |
| `06_insertion_donnees.sql` | ✅ **95 lignes** insérées, aucune erreur, contrôle de cohérence à 0 ligne |
| `07_tests_use_cases.sql` | ✅ 7 contrôles d'intégrité à 0 ligne, 12 requêtes métier, 4 scénarios d'écriture |

### Ce qui a été créé

**7 tables · 81 colonnes · 10 clés étrangères · 17 règles de validation (`CHECK`) · 6 vues**

| Table | Lignes insérées |
|---|---|
| `adresse` | 17 |
| `particulier` | 6 |
| `transporteur` | 3 |
| `client` | 8 |
| `mission` | 8 |
| `colis` | 14 |
| `historique_statut` | 39 |
| **Total** | **95** |

### Le jeu de données couvre bien tous les cas

| Statut de colis | Nb | Statut de mission | Nb |
|---|---|---|---|
| `EN_COURS_LIVRAISON` | 2 | `ACTIVE` | 4 |
| `DEPOSE_RELAIS` | 6 | `SUSPENDUE` | 1 |
| `RETIRE_CLIENT` | 2 | `EN_ATTENTE` | 1 |
| `NON_RECLAME` | 1 | `TERMINEE` | 1 |
| `EN_ATTENTE_REPRISE` | 1 | `REFUSEE` | 1 |
| `REPRIS_TRANSPORTEUR` | 2 | | |

Les **6 statuts de colis** et les **5 statuts de mission** sont représentés : chaque écran de consultation a donc quelque chose à afficher.

> ✅ **Vérification du tri des valeurs énumérées.** La requête `SELECT col_statut, COUNT(*) FROM colis GROUP BY col_statut ORDER BY col_statut` restitue bien les statuts **dans l'ordre du parcours** (`EN_COURS_LIVRAISON`, `DEPOSE_RELAIS`, `RETIRE_CLIENT`, `NON_RECLAME`, `EN_ATTENTE_REPRISE`, `REPRIS_TRANSPORTEUR`) et **non par ordre alphabétique**. MySQL trie un énuméré selon l'ordre de déclaration des valeurs : c'est ce qui remplace, gratuitement, la colonne `sta_ordre` de l'ancienne table de référence.

---

## 6.2 Comparaison entre le MLD (le plan) et la base réellement créée

Le schéma a été relu directement depuis la base (via `information_schema`, le catalogue interne de MySQL) puis comparé au MLD du document 04.

### Les tables

| Prévu au MLD | Réellement créé | Verdict |
|---|---|---|
| 7 tables | 7 tables + 6 vues | ✅ |
| Ordre de création par niveaux 0 → 4 | Aucune erreur de dépendance | ✅ |
| 81 colonnes | 81 colonnes | ✅ |

### Les 10 clés étrangères - toutes présentes, avec le comportement prévu

| Contrainte | Lien | Si on supprime la ligne citée |
|---|---|---|
| `fk_particulier_adresse` | `particulier.adr_id → adresse.adr_id` | refusé (`RESTRICT`) |
| `fk_transporteur_adresse` | `transporteur.adr_id → adresse.adr_id` | refusé |
| `fk_client_adresse` | `client.adr_id → adresse.adr_id` | refusé |
| `fk_mission_particulier` | `mission.par_id → particulier.par_id` | refusé |
| `fk_mission_transporteur` | `mission.tra_id → transporteur.tra_id` | refusé |
| `fk_colis_transporteur` | `colis.tra_id → transporteur.tra_id` | refusé |
| `fk_colis_client` | `colis.cli_id → client.cli_id` | refusé |
| `fk_colis_mission` | `colis.mis_id → mission.mis_id` | refusé |
| `fk_historique_colis` | `historique_statut.col_id → colis.col_id` | **suppression en cascade** |
| `fk_historique_mission` | `historique_statut.mis_id → mission.mis_id` | refusé |

### Les 17 règles de validation actives

`adresse` : format du code postal · `particulier` : format de l'e-mail, capacité positive, surface positive, cohérence de la désactivation · `transporteur` : format du SIRET, cohérence des dates de partenariat · `client` : au moins un moyen de contact · `mission` : cohérence des dates, présence d'une date de validation si acceptée · `colis` : poids positif, valeur positive, dépôt après prise en charge, cohérence dépôt ⇔ mission, **date de clôture si statut terminal**, **dépôt effectué si statut autre qu'en livraison** · `historique_statut` : **mission renseignée pour tout événement postérieur à la prise en charge**.

> 💡 **Trois de ces règles sont nouvelles et n'existaient pas quand le statut était une table de référence.** Une contrainte `CHECK` ne peut porter que sur des colonnes de sa propre table : tant que le statut vivait dans une table à part, la règle « un colis terminé a une date de clôture » aurait exigé une jointure - donc impossible à écrire en `CHECK`. Le statut étant désormais **dans** la table `colis`, la base peut la faire respecter elle-même.
>
> C'est un gain net d'optimisation

### Les écarts constatés

| # | Écart | Explication | Décision |
|---|---|---|---|
| 1 | `ON UPDATE RESTRICT` partout, alors qu'on écrit souvent `CASCADE` par réflexe | MariaDB refuse une règle `CHECK` sur une colonne portant un `ON UPDATE CASCADE` (erreur 1901) | ✅ Sans effet : nos clés primaires sont des numéros auto-incrémentés, elles ne changent jamais |
| 2 | Les noms `pk_adresse`, `pk_colis`… sont ignorés | MySQL et MariaDB appellent toujours la clé primaire `PRIMARY` | ⚠️ Purement cosmétique. On garde les noms dans le script : ils rendent le code lisible et portable vers d'autres SGBD |
| 3 | `col_date_limite_retrait` peut rester vide | C'est normal : elle est calculée à partir d'une date qui peut elle-même être vide (colis pas encore déposé) | ✅ Conforme |

---

## 6.3 Les 7 contrôles d'intégrité - tous à zéro ligne

Rappel : ces requêtes cherchent des incohérences. **Zéro ligne = aucune incohérence.**

| # | Ce qu'on vérifie | Règle | Résultat |
|---|---|---|---|
| T1 | Le statut courant est-il bien le dernier statut historisé ? | RG12 | ✅ 0 ligne |
| T2 | Existe-t-il un colis sans aucun historique ? | cardinalité `1,n` | ✅ 0 ligne |
| T3 | Le transporteur du colis est-il celui de sa mission ? | cohérence métier | ✅ 0 ligne |
| T4 | Un colis terminé a-t-il bien une date de clôture ? | parcours du colis | ✅ 0 ligne *(désormais aussi garanti par `ck_colis_cloture`)* |
| T5 | Un point relais dépasse-t-il sa capacité ? | RG13 | ✅ 0 ligne |
| T6 | Un particulier actif est-il sans mission active ? | RG04 | ✅ 0 ligne |
| T7 | Un événement post-dépôt est-il sans mission rattachée ? | RG09 | ✅ 0 ligne *(désormais aussi garanti par `ck_historique_mission`)* |

---

## 6.4 Les 12 tests négatifs - toutes les écritures interdites sont refusées

C'est la partie la plus convaincante en soutenance : elle prouve que les contraintes servent réellement à quelque chose.

| Ce qu'on a tenté | Ce que la base a répondu | Règle protégée |
|---|---|---|
| Deux colis avec la même référence | `1062 - Duplicate entry for key 'uq_colis_reference'` | RG14 |
| Un colis au poids négatif | `4025 - CONSTRAINT 'ck_colis_poids' failed` | validité des données |
| **Un statut inexistant (`'PERDU_EN_ROUTE'`)** | **`1265 - Data truncated for column 'col_statut'`** | **liste des 6 statuts** |
| **Une faute de frappe (`'depose_relai'`)** | **`1265 - Data truncated for column 'col_statut'`** | **liste des 6 statuts** |
| Un colis déposé sans mission | `4025 - CONSTRAINT 'ck_colis_depot_mission' failed` | RG09 |
| Un colis terminé sans date de clôture | `4025 - CONSTRAINT 'ck_colis_cloture' failed` | parcours du colis |
| Deux comptes avec le même e-mail | `1062 - Duplicate entry for key 'uq_particulier_email'` | RG01 |
| Une capacité de stockage nulle | `4025 - CONSTRAINT 'ck_particulier_capacite' failed` | RG13 |
| Un client sans e-mail ni téléphone | `4025 - CONSTRAINT 'ck_client_contact' failed` | UC16 |
| Un code postal à 4 chiffres | `4025 - CONSTRAINT 'ck_adresse_code_postal' failed` | validité des données |
| Supprimer un transporteur qui a des colis | `1451 - Cannot delete or update a parent row` | intégrité référentielle |
| Forcer la date limite de retrait | `1906 - value for generated column has been ignored` | **RG10** |

> **Les deux tests sur les statuts sont ceux à montrer si on vous demande ce qu'on a perdu en supprimant la table de référence : rien.** La base refuse `'PERDU_EN_ROUTE'` comme elle refusait un identifiant inexistant, et elle refuse aussi `'depose_relai'` - une faute de frappe qui, avec une colonne texte libre, serait passée sans broncher. L'intégrité est identique ; seul le mécanisme change.
>
> **Et le test sur la date limite reste le plus parlant** : le délai de 14 jours ne peut pas être falsifié, même par quelqu'un qui écrirait une requête à la main dans la base. Il est garanti par la **structure**, pas par la bonne volonté du programme.

---

## 6.5 Les scénarios métier rejoués

Chaque scénario est exécuté dans une transaction terminée par `ROLLBACK` : on vérifie que ça marche, sans abîmer le jeu de données.

| Scénario | Ce qu'on a vérifié | Résultat |
|---|---|---|
| **UC12** - dépôt d'un colis chez Sophie Marchand | La date limite est passée automatiquement au 18/08 (14 jours après le dépôt du 04/08) | ✅ |
| **UC17** - retrait par le client avec contrôle du code | 3 lignes d'historique, statut final `RETIRE_CLIENT` | ✅ |
| **UC24** - traitement automatique de nuit | 1 colis expiré basculé en `NON_RECLAME`, il apparaît aussitôt dans la liste des colis à retourner | ✅ |
| **UC14** - reprise d'un colis non réclamé | Parcours complet en 5 étapes, avec le point relais et le transporteur à chaque ligne | ✅ |
| **Traçabilité d'une correction** | L'historique conserve **à la fois** la saisie erronée et sa correction | ✅ |

> Au passage, les requêtes d'écriture se sont **nettement simplifiées**. Là où il fallait écrire
> `sta_id = (SELECT sta_id FROM statut_colis WHERE sta_code = 'DEPOSE_RELAIS')`,
> on écrit maintenant `col_statut = 'DEPOSE_RELAIS'`. Une sous-requête en moins à chaque changement d'état.

---

## 6.6 Ce qui reste à faire

Rien de bloquant, mais ce sont les prolongements naturels du travail :

1. **Des déclencheurs (`triggers`)** pour les règles encore portées par le programme : RG06 (une seule mission active par couple), RG13 (capacité de stockage), et l'ordre des étapes du parcours.
2. **Un partitionnement de `historique_statut` par année** si le volume explose : c'est la table qui grossira le plus vite.
3. **La sécurisation** : chiffrement des données sensibles, protection contre les injections SQL - c'est tout l'objet de l'itération 2.
4. **Une politique de purge RGPD** : combien de temps garde-t-on les colis clos et les données des clients finaux ?
5. **Les zones de couverture** des transporteurs, si le client confirme le besoin (question n°2 du §1.5).
6. **Deux marches arrière possibles**, si un besoin nouveau apparaît - et dans les deux cas le changement resterait isolé :
   - si l'on veut **rechercher par créneau horaire** → recréer une table `disponibilite` ;
   - si le client veut **administrer lui-même les statuts** ou leur associer des données (libellés traduits, délais variables) → recréer une table `statut_colis`. Un `ALTER TABLE` transforme l'énuméré en clé étrangère sans perte de données.
