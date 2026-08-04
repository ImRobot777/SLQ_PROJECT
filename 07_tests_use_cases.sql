-- =============================================================================
--  PLATEFORME « POINT RELAIS À DOMICILE » - REQUÊTES DE VÉRIFICATION
-- =============================================================================
--  Fichier    : 07_tests_use_cases.sql
--  Pré-requis : 05_creation_bdd.sql puis 06_insertion_donnees.sql
--
--  OBJET : prouver que les scénarios du cahier des charges fonctionnent
--  réellement sur la base créée. Le fichier contient 4 familles de tests :
--
--    §1 CONTRÔLES D'INTÉGRITÉ - 7 requêtes qui doivent toutes renvoyer
--       ZÉRO LIGNE. Chacune cherche une incohérence. Zéro ligne = tout va bien.
--
--    §2 REQUÊTES MÉTIER - une requête par cas d'utilisation important.
--
--    §3 SCÉNARIOS D'ÉCRITURE - on simule un dépôt, un retrait, la bascule
--       automatique. Chaque bloc se termine par ROLLBACK, qui ANNULE les
--       modifications : le jeu de données reste intact, on peut rejouer le
--       fichier autant de fois qu'on veut.
--
--    §4 TESTS NÉGATIFS - on tente exprès des écritures interdites. Ici, un
--       test qui ÉCHOUE est un test qui RÉUSSIT : c'est la preuve que les
--       contraintes protègent réellement les données.
--
--  Exécution conseillée (l'option -t affiche de jolis tableaux) :
--      mysql -u root -p -t relais_domicile < 07_tests_use_cases.sql
-- =============================================================================

USE relais_domicile;


-- =============================================================================
--  §1. CONTRÔLES D'INTÉGRITÉ - chacun doit retourner ZÉRO ligne
-- =============================================================================

SELECT '=== T1 : le statut courant correspond-il au dernier historique ? (RG12) ===' AS test;
SELECT c.col_reference, c.col_statut AS courant, h.his_statut AS dernier_historise
FROM        colis c
JOIN        historique_statut h ON h.col_id = c.col_id
             AND h.his_date_changement = (SELECT MAX(h2.his_date_changement)
                                          FROM historique_statut h2 WHERE h2.col_id = c.col_id)
WHERE   c.col_statut <> h.his_statut;

SELECT '=== T2 : existe-t-il un colis sans aucun historique ? (cardinalité 1,n) ===' AS test;
SELECT c.col_reference
FROM      colis c
LEFT JOIN historique_statut h ON h.col_id = c.col_id
WHERE     h.his_id IS NULL;

SELECT '=== T3 : le transporteur du colis est-il bien celui de la mission ? ===' AS test;
SELECT c.col_reference, c.tra_id AS transporteur_du_colis, m.tra_id AS transporteur_de_la_mission
FROM  colis c
JOIN  mission m ON m.mis_id = c.mis_id
WHERE c.tra_id <> m.tra_id;

-- Depuis le passage du statut en type énuméré, cette règle est DÉJÀ garantie par
-- la contrainte ck_colis_cloture. Le test reste utile comme filet de sécurité.
SELECT '=== T4 : un colis terminé a-t-il bien une date de clôture ? ===' AS test;
SELECT c.col_reference, c.col_statut
FROM  colis c
WHERE c.col_statut IN ('RETIRE_CLIENT','REPRIS_TRANSPORTEUR')
  AND c.col_date_cloture IS NULL;

SELECT '=== T5 : un point relais dépasse-t-il sa capacité de stockage ? (RG13) ===' AS test;
SELECT point_relais, par_capacite_max_colis, nb_colis_en_garde
FROM  v_charge_point_relais
WHERE nb_colis_en_garde > par_capacite_max_colis;

SELECT '=== T6 : un particulier actif est-il sans aucune mission active ? (RG04) ===' AS test;
SELECT p.par_id, p.par_nom
FROM      particulier p
LEFT JOIN mission m ON m.par_id = p.par_id AND m.mis_statut = 'ACTIVE'
WHERE     p.par_est_actif = TRUE AND m.mis_id IS NULL;

-- Également garanti désormais par la contrainte ck_historique_mission.
SELECT '=== T7 : un événement postérieur au dépôt est-il sans mission ? (RG09) ===' AS test;
SELECT c.col_reference, h.his_statut, h.his_date_changement
FROM  historique_statut h
JOIN  colis c ON c.col_id = h.col_id
WHERE h.his_statut <> 'EN_COURS_LIVRAISON' AND h.mis_id IS NULL;


-- =============================================================================
--  §2. REQUÊTES MÉTIER - les scénarios du cahier des charges
-- =============================================================================

-- -----------------------------------------------------------------------------
--  UC19 - Voir l'état d'un colis et tout son historique
--  C'est LA requête qui prouve que l'exigence de traçabilité est satisfaite :
--  chaque ligne donne la date, le statut, le point relais ET le transporteur.
-- -----------------------------------------------------------------------------
SELECT '=== UC19 : historique complet du colis CE2026053000010 ===' AS requete;
SELECT his_date_changement, his_statut, statut_libelle, his_origine,
       transporteur_responsable, point_relais, his_commentaire
FROM  v_historique_colis
WHERE col_reference = 'CE2026053000010';

-- -----------------------------------------------------------------------------
--  Le colis dont la saisie a été corrigée : les DEUX événements sont conservés.
--  C'est l'argument décisif en faveur d'une table d'historique.
-- -----------------------------------------------------------------------------
SELECT '=== Traçabilité : un colis dont la saisie a été corrigée ===' AS requete;
SELECT his_date_changement, his_statut, his_origine, his_commentaire
FROM  v_historique_colis
WHERE col_reference = 'CE2026072700014';

-- UC20 - Les points relais réellement opérationnels aujourd'hui
SELECT '=== UC20 : points relais actifs ===' AS requete;
SELECT par_identite, adr_ville, par_type_logement, par_capacite_max_colis,
       nb_missions_actives, transporteurs, par_disponibilites
FROM v_point_relais_actif;

-- UC21 - Colis en attente de retrait, les plus urgents en tête
SELECT '=== UC21 : colis en attente de retrait ===' AS requete;
SELECT col_reference, point_relais, destinataire, col_date_limite_retrait, jours_restants
FROM v_colis_en_attente_retrait;

-- UC22 - Colis devant être retournés
SELECT '=== UC22 : colis devant être retournés ===' AS requete;
SELECT col_reference, statut_libelle, tra_raison_sociale, point_relais,
       relais_telephone, jours_depuis_expiration
FROM v_colis_a_retourner;

-- UC23 - Colis récupérés par les transporteurs
SELECT '=== UC23 : colis repris par les transporteurs ===' AS requete;
SELECT c.col_reference, t.tra_raison_sociale,
       CONCAT(p.par_prenom, ' ', p.par_nom) AS point_relais,
       c.col_date_depot_relais, c.col_date_cloture,
       DATEDIFF(c.col_date_cloture, c.col_date_limite_retrait) AS jours_pour_venir_reprendre
FROM  colis c
JOIN  transporteur t ON t.tra_id = c.tra_id
JOIN  mission     m  ON m.mis_id = c.mis_id
JOIN  particulier p  ON p.par_id = m.par_id
WHERE c.col_statut = 'REPRIS_TRANSPORTEUR'
ORDER BY c.col_date_cloture DESC;

-- UC07 - Les colis actuellement sous la garde d'un point relais donné
SELECT '=== UC07 : colis sous la garde de Sophie Marchand ===' AS requete;
SELECT c.col_reference, t.tra_raison_sociale, c.col_statut,
       c.col_date_depot_relais, c.col_date_limite_retrait, c.col_code_retrait
FROM  colis c
JOIN  mission      m ON m.mis_id = c.mis_id
JOIN  particulier  p ON p.par_id = m.par_id
JOIN  transporteur t ON t.tra_id = c.tra_id
WHERE p.par_email = 'sophie.marchand@example.fr'
  AND c.col_statut IN ('DEPOSE_RELAIS','NON_RECLAME','EN_ATTENTE_REPRISE')
ORDER BY c.col_date_limite_retrait;

-- UC09 - Chercher des points relais éligibles sur une zone géographique
SELECT '=== UC09 : points relais éligibles sur Lyon 3e et Villeurbanne ===' AS requete;
SELECT CONCAT(p.par_prenom,' ',p.par_nom) AS particulier,
       a.adr_code_postal, a.adr_ville, p.par_type_logement,
       p.par_capacite_max_colis, p.par_est_securise, p.par_disponibilites
FROM  particulier p
JOIN  adresse     a ON a.adr_id = p.adr_id
WHERE p.par_est_eligible = TRUE
  AND a.adr_code_postal IN ('69003','69100');

-- Tableau de bord des missions, tous statuts confondus
SELECT '=== Tableau de bord des missions ===' AS requete;
SELECT m.mis_id, CONCAT(p.par_prenom,' ',p.par_nom) AS particulier,
       t.tra_raison_sociale, m.mis_statut, m.mis_date_debut, m.mis_date_fin,
       COUNT(c.col_id) AS nb_colis_traites
FROM      mission      m
JOIN      particulier  p ON p.par_id = m.par_id
JOIN      transporteur t ON t.tra_id = m.tra_id
LEFT JOIN colis        c ON c.mis_id = m.mis_id
GROUP BY m.mis_id, p.par_prenom, p.par_nom, t.tra_raison_sociale,
         m.mis_statut, m.mis_date_debut, m.mis_date_fin
ORDER BY FIELD(m.mis_statut,'ACTIVE','SUSPENDUE','EN_ATTENTE','TERMINEE','REFUSEE'), m.mis_id;

-- -----------------------------------------------------------------------------
--  Indicateur : combien de colis dans chaque statut ?
--  ⚠️ Petite différence par rapport à une table de référence : ici, un statut
--  qui ne contient AUCUN colis n'apparaît pas dans le résultat (il n'y a plus
--  de table à parcourir en LEFT JOIN). Si l'affichage des lignes à zéro est
--  nécessaire, on écrit la liste des 6 valeurs dans la requête, comme ci-dessous.
--
--  Bonus du type énuméré : ORDER BY col_statut trie dans l'ORDRE DU PARCOURS
--  (ordre de déclaration des valeurs), et non par ordre alphabétique.
-- -----------------------------------------------------------------------------
SELECT '=== Indicateur : répartition des colis par statut ===' AS requete;
SELECT col_statut, COUNT(*) AS nb_colis
FROM   colis
GROUP BY col_statut
ORDER BY col_statut;

-- Variante affichant aussi les statuts vides
SELECT '=== Variante : répartition incluant les statuts à zéro ===' AS requete;
SELECT ref.statut, COUNT(c.col_id) AS nb_colis
FROM (
        SELECT 'EN_COURS_LIVRAISON'  AS statut, 1 AS rang UNION ALL
        SELECT 'DEPOSE_RELAIS',       2 UNION ALL
        SELECT 'RETIRE_CLIENT',       3 UNION ALL
        SELECT 'NON_RECLAME',         4 UNION ALL
        SELECT 'EN_ATTENTE_REPRISE',  5 UNION ALL
        SELECT 'REPRIS_TRANSPORTEUR', 6
     ) ref
LEFT JOIN colis c ON c.col_statut = ref.statut
GROUP BY ref.statut, ref.rang
ORDER BY ref.rang;

-- Indicateur : quel transporteur a le meilleur taux de retrait par le client ?
SELECT '=== Indicateur : taux de retrait par transporteur ===' AS requete;
SELECT t.tra_raison_sociale,
       COUNT(c.col_id)                                                                    AS colis_total,
       SUM(c.col_statut = 'RETIRE_CLIENT')                                                AS retires_par_le_client,
       SUM(c.col_statut IN ('NON_RECLAME','EN_ATTENTE_REPRISE','REPRIS_TRANSPORTEUR'))    AS partis_en_retour,
       ROUND(100 * SUM(c.col_statut = 'RETIRE_CLIENT') / COUNT(c.col_id), 1)              AS taux_retrait_pct
FROM  transporteur t
JOIN  colis        c ON c.tra_id = t.tra_id
GROUP BY t.tra_id, t.tra_raison_sociale;

-- Charge de chaque point relais
SELECT '=== RG13 : charge actuelle des points relais ===' AS requete;
SELECT * FROM v_charge_point_relais;


-- =============================================================================
--  §3. SCÉNARIOS D'ÉCRITURE (annulés par ROLLBACK - le jeu de données ne bouge pas)
-- =============================================================================

-- -----------------------------------------------------------------------------
--  UC12 - Le transporteur dépose un colis chez un point relais.
--  Les DEUX écritures (le colis + l'historique) sont dans la MÊME transaction :
--  c'est la condition pour que la dénormalisation reste sûre (RG12).
--
--  Notez comme les requêtes se sont simplifiées : plus besoin d'aller chercher
--  l'identifiant du statut dans une table de référence, on écrit la valeur.
-- -----------------------------------------------------------------------------
SELECT '=== UC12 : dépôt du colis CE2026080400001 chez Sophie Marchand ===' AS scenario;
START TRANSACTION;

UPDATE colis
SET    mis_id                = 1,
       col_statut            = 'DEPOSE_RELAIS',
       col_date_depot_relais = '2026-08-04 16:30:00',
       col_code_retrait      = 'X7Y2ZA'
WHERE  col_reference = 'CE2026080400001';

INSERT INTO historique_statut (col_id, his_statut, mis_id, his_date_changement, his_origine, his_commentaire)
SELECT col_id, 'DEPOSE_RELAIS', 1, '2026-08-04 16:30:00', 'POINT_RELAIS',
       'Dépôt après échec de livraison à domicile'
FROM   colis WHERE col_reference = 'CE2026080400001';

-- Vérification : la date limite s'est calculée TOUTE SEULE (RG10)
SELECT col_reference, col_date_depot_relais, col_date_limite_retrait, col_code_retrait
FROM   colis WHERE col_reference = 'CE2026080400001';

ROLLBACK;


-- -----------------------------------------------------------------------------
--  UC17 - Le client vient retirer son colis (fin normale du processus)
-- -----------------------------------------------------------------------------
SELECT '=== UC17 : retrait du colis CE2026073000003 par le client ===' AS scenario;
START TRANSACTION;

UPDATE colis
SET    col_statut       = 'RETIRE_CLIENT',
       col_date_cloture = NOW()
WHERE  col_reference    = 'CE2026073000003'
  AND  col_code_retrait = 'K4M9TR';        -- RG15 : le code de retrait est contrôlé

INSERT INTO historique_statut (col_id, his_statut, mis_id, his_date_changement, his_origine, his_commentaire)
SELECT col_id, 'RETIRE_CLIENT', mis_id, NOW(), 'CLIENT', 'Code de retrait validé'
FROM   colis WHERE col_reference = 'CE2026073000003';

SELECT his_statut, statut_libelle, his_origine, his_commentaire
FROM   v_historique_colis WHERE col_reference = 'CE2026073000003';

ROLLBACK;


-- -----------------------------------------------------------------------------
--  UC24 - Le traitement automatique de nuit : bascule des colis non réclamés.
--  Une seule paire de requêtes traite TOUS les colis expirés d'un coup.
-- -----------------------------------------------------------------------------
SELECT '=== UC24 : bascule automatique en NON_RECLAME ===' AS scenario;
START TRANSACTION;

-- 1) On historise D'ABORD (sinon on perdrait la liste des colis à traiter)
INSERT INTO historique_statut (col_id, his_statut, mis_id, his_date_changement, his_origine, his_commentaire)
SELECT c.col_id, 'NON_RECLAME', c.mis_id, NOW(), 'SYSTEME',
       'Délai de 14 jours dépassé - bascule automatique'
FROM   colis c
WHERE  c.col_statut = 'DEPOSE_RELAIS'
  AND  c.col_date_limite_retrait < CURDATE();

-- 2) Puis on met à jour le statut courant
UPDATE colis
SET    col_statut = 'NON_RECLAME'
WHERE  col_statut = 'DEPOSE_RELAIS'
  AND  col_date_limite_retrait < CURDATE();

SELECT ROW_COUNT() AS nb_colis_bascules;
SELECT col_reference, col_statut, jours_depuis_expiration FROM v_colis_a_retourner;

ROLLBACK;


-- -----------------------------------------------------------------------------
--  UC14 - Le transporteur vient reprendre un colis non réclamé
-- -----------------------------------------------------------------------------
SELECT '=== UC14 : reprise du colis RL2026062600009 par RapidLog ===' AS scenario;
START TRANSACTION;

UPDATE colis
SET    col_statut       = 'REPRIS_TRANSPORTEUR',
       col_date_cloture = NOW()
WHERE  col_reference = 'RL2026062600009';

INSERT INTO historique_statut (col_id, his_statut, mis_id, his_date_changement, his_origine, his_commentaire)
SELECT col_id, 'REPRIS_TRANSPORTEUR', mis_id, NOW(), 'TRANSPORTEUR',
       'Colis repris - processus de livraison clos'
FROM   colis WHERE col_reference = 'RL2026062600009';

SELECT his_statut, statut_libelle, his_date_changement, point_relais
FROM   v_historique_colis WHERE col_reference = 'RL2026062600009';

ROLLBACK;


-- =============================================================================
--  §4. TESTS NÉGATIFS - la base doit REFUSER chacune de ces écritures
--
--  Ces requêtes sont volontairement commentées : décommentez-les UNE PAR UNE
--  pour constater le message d'erreur. Ici, une erreur = un succès.
-- =============================================================================
/*
-- 1) Deux colis avec la même référence de suivi        → uq_colis_reference (RG14)
INSERT INTO colis (col_reference, tra_id, cli_id, col_statut, col_poids_kg, col_date_prise_en_charge)
VALUES ('CE2026080400001', 1, 1, 'EN_COURS_LIVRAISON', 1.000, NOW());

-- 2) Un colis au poids négatif                         → ck_colis_poids
INSERT INTO colis (col_reference, tra_id, cli_id, col_statut, col_poids_kg, col_date_prise_en_charge)
VALUES ('TEST000000000001', 1, 1, 'EN_COURS_LIVRAISON', -3.000, NOW());

-- 3) UN STATUT QUI N'EXISTE PAS                        → type énuméré
--    C'est LE test qui prouve qu'on n'a rien perdu en supprimant la table de
--    référence : la base refuse toute valeur hors de la liste des 6.
INSERT INTO colis (col_reference, tra_id, cli_id, col_statut, col_poids_kg, col_date_prise_en_charge)
VALUES ('TEST000000000002', 1, 1, 'PERDU_EN_ROUTE', 1.000, NOW());

-- 4) Une faute de frappe sur un statut existant        → type énuméré
UPDATE colis SET col_statut = 'depose_relai' WHERE col_id = 3;

-- 5) Un colis déposé mais rattaché à aucune mission    → ck_colis_depot_mission (RG09)
INSERT INTO colis (col_reference, tra_id, cli_id, col_statut, col_poids_kg,
                   col_date_prise_en_charge, col_date_depot_relais)
VALUES ('TEST000000000003', 1, 1, 'DEPOSE_RELAIS', 1.000, NOW(), NOW());

-- 6) Un colis terminé sans date de clôture             → ck_colis_cloture
UPDATE colis SET col_statut = 'RETIRE_CLIENT' WHERE col_id = 3;

-- 7) Deux comptes avec la même adresse e-mail          → uq_particulier_email (RG01)
INSERT INTO particulier (adr_id, par_nom, par_prenom, par_date_naissance, par_email,
                         par_telephone, par_mot_de_passe_hash, par_type_logement, par_capacite_max_colis)
VALUES (4, 'Dupont', 'Jean', '1990-01-01', 'sophie.marchand@example.fr', '0600000000',
        '$2y$10$K7Lm3qZ8vN1pR4tW6yA0bOxCdEfGhIjKlMnOpQrStUvWxYz012345', 'MAISON', 3);

-- 8) Une capacité de stockage nulle                    → ck_particulier_capacite (RG13)
INSERT INTO particulier (adr_id, par_nom, par_prenom, par_date_naissance, par_email,
                         par_telephone, par_mot_de_passe_hash, par_type_logement, par_capacite_max_colis)
VALUES (4, 'Test', 'Zero', '1990-01-01', 'zero@example.fr', '0600000000',
        '$2y$10$K7Lm3qZ8vN1pR4tW6yA0bOxCdEfGhIjKlMnOpQrStUvWxYz012345', 'MAISON', 0);

-- 9) Un client sans e-mail NI téléphone                → ck_client_contact
INSERT INTO client (adr_id, cli_nom, cli_prenom) VALUES (10, 'Sansmoyen', 'Decontact');

-- 10) Un code postal à 4 chiffres                      → ck_adresse_code_postal
INSERT INTO adresse (adr_voie, adr_code_postal, adr_ville) VALUES ('Rue Test', '6900', 'Lyon');

-- 11) Supprimer un transporteur qui a encore des colis → fk_colis_transporteur
DELETE FROM transporteur WHERE tra_id = 1;

-- 12) Forcer la date limite de retrait                 → colonne générée (RG10)
--     Le test le plus parlant : le délai de 14 jours ne peut PAS être falsifié.
UPDATE colis SET col_date_limite_retrait = '2030-01-01' WHERE col_id = 3;
*/

-- =============================================================================
--  FIN DES TESTS
-- =============================================================================
