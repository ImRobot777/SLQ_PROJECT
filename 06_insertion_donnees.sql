-- =============================================================================
--  PLATEFORME « POINT RELAIS À DOMICILE » - SCRIPT DE REMPLISSAGE
-- =============================================================================
--  Fichier    : 06_insertion_donnees.sql
--  Pré-requis : avoir exécuté 05_creation_bdd.sql
--  Date de référence du jeu de données : 2026-08-04
--
--  POURQUOI CE SCRIPT ? Sans données, impossible de vérifier que les scénarios
--  du cahier des charges fonctionnent. On insère donc :
--    1. de quoi rejouer chaque cas d'utilisation
--    2. surtout : les CAS LIMITES, qui sont les plus utiles à tester
--
--  Il n'y a plus de table de référence à alimenter : les statuts sont des
--  valeurs énumérées, inscrites directement dans la définition des colonnes.
--
--  L'ORDRE DES INSERTIONS SUIT LES NIVEAUX DE DÉPENDANCE : on ne peut pas créer
--  un colis avant son client, ni une mission avant son particulier.
--    Niveau 0 : adresse
--    Niveau 1 : transporteur, particulier, client
--    Niveau 2 : mission
--    Niveau 3 : colis
--    Niveau 4 : historique_statut
--
--  Les identifiants sont saisis explicitement pour que le jeu de données soit
--  reproductible et les jointures faciles à relire.
-- =============================================================================

USE relais_domicile;

START TRANSACTION;   -- tout ou rien : soit tout s'insère, soit rien du tout


-- =============================================================================
--  1. ADRESSES (niveau 0)
-- =============================================================================

INSERT INTO adresse (adr_id, adr_numero, adr_voie, adr_complement, adr_code_postal, adr_ville, adr_latitude, adr_longitude) VALUES
    -- Sièges des transporteurs
    ( 1, '145', 'Boulevard Stalingrad',      'Bâtiment C',           '69100', 'Villeurbanne', 45.771400,  4.878900),
    ( 2, '8',   'Rue de la Logistique',      'Zone d''activité Est', '69800', 'Saint-Priest', 45.696300,  4.944200),
    ( 3, '22',  'Avenue des Frères Lumière', NULL,                   '69008', 'Lyon',         45.741900,  4.870100),
    -- Domiciles des particuliers
    ( 4, '17',  'Rue Paul Bert',             'Appartement 4B',       '69003', 'Lyon',         45.760200,  4.850300),
    ( 5, '3',   'Impasse des Tilleuls',      NULL,                   '69100', 'Villeurbanne', 45.766800,  4.889500),
    ( 6, '54',  'Avenue Jean Jaurès',        'Rez-de-chaussée',      '69007', 'Lyon',         45.741100,  4.840600),
    ( 7, '9',   'Rue Vendôme',               'Appartement 12',       '69006', 'Lyon',         45.769300,  4.849700),
    ( 8, '31',  'Rue de la République',      'Étage 2',              '69500', 'Bron',         45.736400,  4.914200),
    ( 9, '5',   'Allée des Peupliers',       NULL,                   '69200', 'Vénissieux',   45.696900,  4.885300),
    -- Adresses des clients finaux
    (10, '76',  'Cours Gambetta',            'Appartement 8',        '69003', 'Lyon',         45.755800,  4.848200),
    (11, '12',  'Rue Garibaldi',             NULL,                   '69006', 'Lyon',         45.766100,  4.851900),
    (12, '40',  'Rue Anatole France',        'Bâtiment B',           '69100', 'Villeurbanne', 45.769900,  4.877300),
    (13, '2',   'Place Jean Macé',           NULL,                   '69007', 'Lyon',         45.745700,  4.841800),
    (14, '88',  'Route de Genas',            'Appartement 21',       '69500', 'Bron',         45.744300,  4.919800),
    (15, '15',  'Rue des Docteurs Cordier',  NULL,                   '69200', 'Vénissieux',   45.698100,  4.888700),
    (16, '61',  'Avenue Berthelot',          'Studio 3',             '69007', 'Lyon',         45.746900,  4.849200),
    (17, '27',  'Rue Duguesclin',            NULL,                   '69006', 'Lyon',         45.766500,  4.852600);


-- =============================================================================
--  2. LES ACTEURS (niveau 1)
-- =============================================================================

-- -----------------------------------------------------------------------------
--  2.1 Transporteurs partenaires
-- -----------------------------------------------------------------------------
INSERT INTO transporteur
    (tra_id, adr_id, tra_raison_sociale, tra_siret, tra_email, tra_telephone,
     tra_contact_nom, tra_date_debut_partenariat, tra_date_fin_partenariat, tra_est_actif) VALUES
    (1, 1, 'ColiExpress France',      '81234567800017', 'partenariat@coliexpress.fr', '0472451200', 'Nadia Berger',  '2025-01-10', NULL, TRUE),
    (2, 2, 'RapidLog Transport',      '79856214300025', 'contact@rapidlog.fr',        '0478903355', 'Marc Delaunay', '2025-06-01', NULL, TRUE),
    (3, 3, 'Nord Express Logistique', '84512369700033', 'relais@nordexpress.fr',      '0426889044', 'Julie Tanguy',  '2026-02-15', NULL, TRUE);


-- -----------------------------------------------------------------------------
--  2.2 Particuliers - 6 profils, choisis pour couvrir tous les cas de figure
--
--    n°1 Sophie    : point relais actif, travaille pour DEUX transporteurs
--    n°2 Karim     : point relais actif, un seul transporteur, maison
--    n°3 Élodie    : point relais actif, grosse capacité
--    n°4 Thomas    : inscrit mais REFUSÉ (studio, capacité insuffisante)
--    n°5 Marie     : inscrite, candidature EN ATTENTE de réponse
--    n°6 Jean-Paul : ANCIEN point relais, compte désactivé
--
--  Les hachages de mot de passe sont fictifs mais au bon format (RG16) :
--  la base ne contient jamais de mot de passe en clair, même en jeu de test.
-- -----------------------------------------------------------------------------
INSERT INTO particulier
    (par_id, adr_id, par_civilite, par_nom, par_prenom, par_date_naissance, par_email,
     par_telephone, par_mot_de_passe_hash, par_date_inscription,
     par_type_logement, par_etage, par_a_ascenseur, par_surface_stockage_m2,
     par_capacite_max_colis, par_est_securise, par_commentaire_acces, par_disponibilites,
     par_est_eligible, par_est_actif, par_date_desactivation) VALUES

    (1, 4, 'MME', 'Marchand', 'Sophie', '1988-03-14', 'sophie.marchand@example.fr', '0612345678',
     '$2y$10$K7Lm3qZ8vN1pR4tW6yA0bOxCdEfGhIjKlMnOpQrStUvWxYz012345', '2025-11-20 10:22:00',
     'APPARTEMENT', 4, TRUE,  6.50,  8, TRUE,
     'Cellier fermé à clé, accès par l''ascenseur. Interphone code A2571.',
     'Lun-Jeu 18h-20h30, Ven 17h30-21h, Sam 9h-12h',
     TRUE, TRUE, NULL),

    (2, 5, 'M', 'Benali', 'Karim', '1979-11-02', 'karim.benali@example.fr', '0623456789',
     '$2y$10$K7Lm3qZ8vN1pR4tW6yA0bOxCdEfGhIjKlMnOpQrStUvWxYz012345', '2025-09-05 14:48:00',
     'MAISON', 0, FALSE, 12.00,  6, TRUE,
     'Garage attenant, portail automatique. Sonner au portail.',
     'Lun-Ven 8h-20h (télétravail)',
     TRUE, TRUE, NULL),

    (3, 6, 'MME', 'Fabre', 'Élodie', '1992-06-27', 'elodie.fabre@example.fr', '0634567890',
     '$2y$10$K7Lm3qZ8vN1pR4tW6yA0bOxCdEfGhIjKlMnOpQrStUvWxYz012345', '2026-04-11 09:05:00',
     'APPARTEMENT', 0, FALSE, 10.00, 10, TRUE,
     'Local à vélos privatif au rez-de-chaussée, interphone B0432.',
     'Mer 10h-19h, Sam 9h30-18h, Dim 10h-13h',
     TRUE, TRUE, NULL),

    -- Inscrit mais NON éligible : sa candidature a été refusée
    (4, 7, 'M', 'Nguyen', 'Thomas', '1995-01-19', 'thomas.nguyen@example.fr', '0645678901',
     '$2y$10$K7Lm3qZ8vN1pR4tW6yA0bOxCdEfGhIjKlMnOpQrStUvWxYz012345', '2026-06-02 18:33:00',
     'APPARTEMENT', 3, FALSE,  1.20,  2, FALSE,
     'Studio - pas d''espace de stockage dédié.',
     'Sur rendez-vous uniquement',
     FALSE, FALSE, NULL),

    -- Éligible, mais sa candidature n'a pas encore reçu de réponse
    (5, 8, 'MME', 'Lefèvre', 'Marie', '1983-09-08', 'marie.lefevre@example.fr', '0656789012',
     '$2y$10$K7Lm3qZ8vN1pR4tW6yA0bOxCdEfGhIjKlMnOpQrStUvWxYz012345', '2026-07-25 11:12:00',
     'APPARTEMENT', 2, TRUE,   4.00,  5, FALSE,
     'Entrée dégagée, code d''immeuble communiqué au transporteur.',
     'Mar et Jeu 17h-21h',
     TRUE, FALSE, NULL),

    -- Ancien point relais : mission terminée, compte désactivé
    (6, 9, 'M', 'Roussel', 'Jean-Paul', '1966-12-30', 'jp.roussel@example.fr', '0667890123',
     '$2y$10$K7Lm3qZ8vN1pR4tW6yA0bOxCdEfGhIjKlMnOpQrStUvWxYz012345', '2025-02-17 08:40:00',
     'ATELIER', 0, FALSE,  8.00,  4, TRUE,
     'Ancien atelier, activité arrêtée.',
     NULL,
     TRUE, FALSE, '2026-05-02 12:00:00');


-- -----------------------------------------------------------------------------
--  2.3 Clients finaux
--  Note : le client n°3 n'a pas d'e-mail et le n°4 pas de téléphone - la
--  contrainte ck_client_contact exige au moins l'un des deux.
-- -----------------------------------------------------------------------------
INSERT INTO client (cli_id, adr_id, cli_civilite, cli_nom, cli_prenom, cli_email, cli_telephone) VALUES
    (1, 10, 'M',     'Perrin',    'Lucas',   'lucas.perrin@example.fr',    '0678901234'),
    (2, 11, 'MME',   'Da Silva',  'Ana',     'ana.dasilva@example.fr',     '0689012345'),
    (3, 12, 'M',     'Girard',    'Étienne', NULL,                         '0690123456'),
    (4, 13, 'MME',   'Chevalier', 'Laura',   'laura.chevalier@example.fr', NULL),
    (5, 14, 'AUTRE', 'Bouchard',  'Alex',    'alex.bouchard@example.fr',   '0601234567'),
    (6, 15, 'M',     'Leroy',     'Mehdi',   'mehdi.leroy@example.fr',     '0611223344'),
    (7, 16, 'MME',   'Colin',     'Inès',    'ines.colin@example.fr',      '0622334455'),
    (8, 17, 'M',     'Rousseau',  'Victor',  'victor.rousseau@example.fr', '0633445566');


-- =============================================================================
--  3. MISSIONS (niveau 2)
--  Les 5 statuts possibles d'une mission sont représentés.
-- =============================================================================

INSERT INTO mission
    (mis_id, par_id, tra_id, mis_date_candidature, mis_date_validation,
     mis_date_debut, mis_date_fin, mis_statut, mis_capacite_max_colis, mis_commentaire) VALUES

    -- Sophie travaille pour DEUX transporteurs en même temps (RG17) :
    -- c'est explicitement autorisé par le cahier des charges.
    (1, 1, 1, '2026-01-05 09:14:00', '2026-01-12 16:20:00', '2026-01-15', NULL,         'ACTIVE',      5, 'Zone Lyon 3 - flux quotidien'),
    (2, 1, 2, '2026-02-18 20:02:00', '2026-02-25 10:45:00', '2026-03-01', '2026-12-31', 'ACTIVE',      3, 'Contrat annuel reconductible'),

    -- Karim : un seul transporteur, mission à durée indéterminée
    (3, 2, 1, '2025-10-20 12:30:00', '2025-10-28 09:00:00', '2025-11-02', NULL,         'ACTIVE',      6, NULL),

    -- Élodie : mission bornée dans le temps
    (4, 3, 2, '2026-05-06 08:55:00', '2026-05-14 15:10:00', '2026-05-20', '2026-12-31', 'ACTIVE',     10, 'Fort volume - local sécurisé'),

    -- Thomas : candidature REFUSÉE
    (5, 4, 1, '2026-06-10 19:41:00', NULL,                  '2026-07-01', NULL,         'REFUSEE',  NULL, 'Capacité de stockage insuffisante (2 colis, minimum requis 4)'),

    -- Marie : candidature EN ATTENTE de décision
    (6, 5, 3, '2026-07-28 11:26:00', NULL,                  '2026-08-15', NULL,         'EN_ATTENTE', NULL, 'Dossier en cours d''instruction'),

    -- Jean-Paul : mission TERMINÉE
    (7, 6, 1, '2025-02-20 10:00:00', '2025-02-25 14:30:00', '2025-03-01', '2026-04-30', 'TERMINEE',    4, 'Arrêt à la demande du particulier'),

    -- Élodie chez un second transporteur : mission SUSPENDUE (congés)
    (8, 3, 3, '2026-06-02 21:15:00', '2026-06-09 09:30:00', '2026-06-15', NULL,         'SUSPENDUE',   4, 'Suspendue du 15/07 au 31/08 - congés déclarés');


-- =============================================================================
--  4. COLIS (niveau 3)
-- =============================================================================
--  ⚠️ POINT IMPORTANT (RG12) : la colonne colis.col_statut (statut courant) fait
--  double emploi avec la table historique_statut. C'est une redondance VOLONTAIRE
--  (voir §2.4 du document 01). Les deux écritures doivent donc toujours être
--  faites DANS LA MÊME TRANSACTION - c'est ce que fait ce script.
--
--  ⚠️ col_date_limite_retrait n'est PAS insérée : c'est une colonne calculée
--  par la base (date de dépôt + 14 jours). Toute tentative d'écriture est rejetée.
-- =============================================================================

INSERT INTO colis
    (col_id, col_reference, tra_id, cli_id, mis_id, col_statut, col_poids_kg,
     col_longueur_cm, col_largeur_cm, col_hauteur_cm, col_valeur_declaree_eur,
     col_est_fragile, col_code_retrait, col_date_prise_en_charge,
     col_date_depot_relais, col_date_cloture) VALUES

    -- ---- EN_COURS_LIVRAISON --------------------------------------------------
    -- Pas encore de point relais, donc mis_id VIDE : c'est la cardinalité 0,1.
    ( 1, 'CE2026080400001', 1, 1, NULL, 'EN_COURS_LIVRAISON',  2.40, 40, 30, 15,  89.90, FALSE, NULL, '2026-08-03 09:12:00', NULL, NULL),
    ( 2, 'RL2026080400002', 2, 2, NULL, 'EN_COURS_LIVRAISON',  0.85, 25, 20,  8,  34.50, FALSE, NULL, '2026-08-04 07:45:00', NULL, NULL),

    -- ---- DEPOSE_RELAIS - en attente de retrait (UC21) -------------------------
    ( 3, 'CE2026073000003', 1, 3,    1, 'DEPOSE_RELAIS',  1.75, 35, 25, 12,  59.00, FALSE, 'K4M9TR', '2026-07-30 08:05:00', '2026-08-01 17:20:00', NULL),
    ( 4, 'CE2026072300004', 1, 4,    3, 'DEPOSE_RELAIS',  14.10, 50, 35, 20, 149.99, TRUE,  'P7X2ZQ', '2026-07-23 10:30:00', '2026-07-25 11:05:00', NULL),
    (11, 'RL2026080100011', 2, 6,    4, 'DEPOSE_RELAIS',  100.32, 22, 16,  5,  19.90, FALSE, 'D3H8LM', '2026-08-01 06:50:00', '2026-08-02 16:00:00', NULL),
    (12, 'RL2026072900012', 2, 7,    2, 'DEPOSE_RELAIS',  6.90, 60, 40, 30, 320.00, TRUE,  'W5N1YB', '2026-07-29 09:15:00', '2026-07-31 18:10:00', NULL),

    -- ---- CAS LIMITE : déposé le 20/07, limite au 03/08 => DÉPASSÉE au 04/08.
    --      C'est exactement le colis que le traitement automatique (UC24)
    --      doit attraper cette nuit.
    ( 5, 'RL2026071800005', 2, 5,    2, 'DEPOSE_RELAIS',  1.20, 30, 22, 10,  45.00, FALSE, 'T8R6VC', '2026-07-18 14:20:00', '2026-07-20 16:40:00', NULL),

    -- ---- RETIRE_CLIENT - fin normale -----------------------------------------
    ( 6, 'RL2026070800006', 2, 6,    4, 'RETIRE_CLIENT',  0.60, 28, 18,  6,  24.90, FALSE, 'F2J7QK', '2026-07-08 11:40:00', '2026-07-10 10:15:00', '2026-07-14 18:30:00'),
    ( 7, 'CE2026071500007', 1, 7,    1, 'RETIRE_CLIENT',  3.30, 45, 30, 18, 110.00, FALSE, 'S9L4MD', '2026-07-15 07:55:00', '2026-07-17 14:00:00', '2026-07-19 11:00:00'),

    -- ---- NON_RECLAME - délai dépassé, entrée en retour ------------------------
    ( 8, 'CE2026070300008', 1, 8,    3, 'NON_RECLAME',  2.05, 38, 28, 14,  75.00, FALSE, 'G6B3NP', '2026-07-03 13:10:00', '2026-07-05 09:30:00', NULL),

    -- ---- EN_ATTENTE_REPRISE - attend le camion --------------------------------
    ( 9, 'RL2026062600009', 2, 1,    4, 'EN_ATTENTE_REPRISE',  5.40, 55, 38, 25, 210.00, TRUE,  'H1V8XW', '2026-06-26 15:05:00', '2026-06-28 15:45:00', NULL),

    -- ---- REPRIS_TRANSPORTEUR - fin sans remise au client ----------------------
    (10, 'CE2026053000010', 1, 2,    1, 'REPRIS_TRANSPORTEUR',  1.90, 36, 26, 13,  68.00, FALSE, 'Z4C7RF', '2026-05-30 08:45:00', '2026-06-01 12:00:00', '2026-06-22 10:15:00'),
    (13, 'CE2026040500013', 1, 3,    7, 'REPRIS_TRANSPORTEUR',  2.70, 42, 32, 16,  95.00, FALSE, 'Q8M2TD', '2026-04-05 09:20:00', '2026-04-07 11:30:00', '2026-04-28 15:40:00'),

    -- ---- CAS D'UNE SAISIE CORRIGÉE -------------------------------------------
    --      Le point relais avait marqué le colis « retiré » par erreur, puis
    --      s'est corrigé. L'historique garde LES DEUX événements : c'est tout
    --      l'intérêt d'une table d'historique plutôt qu'une colonne écrasée.
    (14, 'CE2026072700014', 1, 5,    3, 'DEPOSE_RELAIS',  0.95, 26, 20,  9,  39.90, FALSE, 'N5K9WJ', '2026-07-27 12:00:00', '2026-07-29 09:50:00', NULL);


-- =============================================================================
--  5. HISTORIQUE DES CHANGEMENTS D'ÉTAT (niveau 4) - RG11
-- =============================================================================
--  Chaque ligne porte : le colis, le statut atteint, la date, l'origine du
--  changement, et la mission - laquelle donne d'un seul coup LE POINT RELAIS
--  et LE TRANSPORTEUR RESPONSABLE, exactement ce qu'exige le cahier des charges.
--
--  mis_id est VIDE pour les événements antérieurs au dépôt : à ce moment-là,
--  le colis n'est encore rattaché à aucun point relais.
-- =============================================================================

INSERT INTO historique_statut
    (col_id, his_statut, mis_id, his_date_changement, his_origine, his_commentaire) VALUES

    -- Colis 1 et 2 - encore dans le camion
    ( 1, 'EN_COURS_LIVRAISON', NULL, '2026-08-03 09:12:00', 'TRANSPORTEUR', 'Prise en charge au centre de tri de Villeurbanne'),
    ( 2, 'EN_COURS_LIVRAISON', NULL, '2026-08-04 07:45:00', 'TRANSPORTEUR', 'Prise en charge au dépôt de Saint-Priest'),

    -- Colis 3 - déposé, le client a 11 jours pour venir
    ( 3, 'EN_COURS_LIVRAISON', NULL, '2026-07-30 08:05:00', 'TRANSPORTEUR', NULL),
    ( 3, 'DEPOSE_RELAIS',         1, '2026-08-01 17:20:00', 'POINT_RELAIS', 'Client absent lors du passage à domicile'),

    -- Colis 4 - déposé, échéance proche
    ( 4, 'EN_COURS_LIVRAISON', NULL, '2026-07-23 10:30:00', 'TRANSPORTEUR', NULL),
    ( 4, 'DEPOSE_RELAIS',         3, '2026-07-25 11:05:00', 'POINT_RELAIS', 'Livraison en relais demandée par le client'),

    -- Colis 5 - déposé le 20/07, échéance dépassée : à basculer (UC24)
    ( 5, 'EN_COURS_LIVRAISON', NULL, '2026-07-18 14:20:00', 'TRANSPORTEUR', NULL),
    ( 5, 'DEPOSE_RELAIS',         2, '2026-07-20 16:40:00', 'POINT_RELAIS', NULL),

    -- Colis 6 - parcours nominal complet : camion -> relais -> client
    ( 6, 'EN_COURS_LIVRAISON', NULL, '2026-07-08 11:40:00', 'TRANSPORTEUR', NULL),
    ( 6, 'DEPOSE_RELAIS',         4, '2026-07-10 10:15:00', 'POINT_RELAIS', NULL),
    ( 6, 'RETIRE_CLIENT',         4, '2026-07-14 18:30:00', 'CLIENT',       'Code de retrait vérifié, pièce d''identité présentée'),

    -- Colis 7 - parcours nominal complet
    ( 7, 'EN_COURS_LIVRAISON', NULL, '2026-07-15 07:55:00', 'TRANSPORTEUR', NULL),
    ( 7, 'DEPOSE_RELAIS',         1, '2026-07-17 14:00:00', 'POINT_RELAIS', NULL),
    ( 7, 'RETIRE_CLIENT',         1, '2026-07-19 11:00:00', 'CLIENT',       'Retrait par le destinataire'),

    -- Colis 8 - non réclamé, basculé automatiquement par le traitement de nuit
    ( 8, 'EN_COURS_LIVRAISON', NULL, '2026-07-03 13:10:00', 'TRANSPORTEUR', NULL),
    ( 8, 'DEPOSE_RELAIS',         3, '2026-07-05 09:30:00', 'POINT_RELAIS', NULL),
    ( 8, 'NON_RECLAME',           3, '2026-07-20 02:00:00', 'SYSTEME',      'Délai de 14 jours dépassé - passage en non réclamé'),

    -- Colis 9 - non réclamé, puis mis en attente de reprise
    ( 9, 'EN_COURS_LIVRAISON', NULL, '2026-06-26 15:05:00', 'TRANSPORTEUR', NULL),
    ( 9, 'DEPOSE_RELAIS',         4, '2026-06-28 15:45:00', 'POINT_RELAIS', NULL),
    ( 9, 'NON_RECLAME',           4, '2026-07-13 02:00:00', 'SYSTEME',      'Délai de 14 jours dépassé'),
    ( 9, 'EN_ATTENTE_REPRISE',    4, '2026-07-15 09:00:00', 'TRANSPORTEUR', 'Retour planifié, reprise à programmer'),

    -- Colis 10 - parcours de retour complet, jusqu'à la reprise
    (10, 'EN_COURS_LIVRAISON', NULL, '2026-05-30 08:45:00', 'TRANSPORTEUR', NULL),
    (10, 'DEPOSE_RELAIS',         1, '2026-06-01 12:00:00', 'POINT_RELAIS', NULL),
    (10, 'NON_RECLAME',           1, '2026-06-16 02:00:00', 'SYSTEME',      'Délai de 14 jours dépassé'),
    (10, 'EN_ATTENTE_REPRISE',    1, '2026-06-17 08:30:00', 'TRANSPORTEUR', 'Bordereau de retour édité'),
    (10, 'REPRIS_TRANSPORTEUR',   1, '2026-06-22 10:15:00', 'TRANSPORTEUR', 'Colis repris au point relais - processus clos'),

    -- Colis 11 - déposé
    (11, 'EN_COURS_LIVRAISON', NULL, '2026-08-01 06:50:00', 'TRANSPORTEUR', NULL),
    (11, 'DEPOSE_RELAIS',         4, '2026-08-02 16:00:00', 'POINT_RELAIS', NULL),

    -- Colis 12 - déposé chez le MÊME point relais que le colis 3, mais pour un
    -- AUTRE transporteur : un particulier peut cumuler plusieurs missions (RG17).
    (12, 'EN_COURS_LIVRAISON', NULL, '2026-07-29 09:15:00', 'TRANSPORTEUR', NULL),
    (12, 'DEPOSE_RELAIS',         2, '2026-07-31 18:10:00', 'POINT_RELAIS', 'Colis volumineux et fragile - stockage au sol'),

    -- Colis 13 - parcours de retour complet sur une mission depuis terminée
    (13, 'EN_COURS_LIVRAISON', NULL, '2026-04-05 09:20:00', 'TRANSPORTEUR', NULL),
    (13, 'DEPOSE_RELAIS',         7, '2026-04-07 11:30:00', 'POINT_RELAIS', NULL),
    (13, 'NON_RECLAME',           7, '2026-04-22 02:00:00', 'SYSTEME',      'Délai de 14 jours dépassé'),
    (13, 'EN_ATTENTE_REPRISE',    7, '2026-04-23 09:45:00', 'TRANSPORTEUR', NULL),
    (13, 'REPRIS_TRANSPORTEUR',   7, '2026-04-28 15:40:00', 'TRANSPORTEUR', 'Reprise avant clôture de la mission'),

    -- Colis 14 - SAISIE ERRONÉE PUIS CORRIGÉE.
    -- Les deux événements sont conservés : on sait ce qui s'est passé ET quand
    -- ça a été corrigé. Avec une simple colonne « statut », cette information
    -- aurait été perdue.
    (14, 'EN_COURS_LIVRAISON', NULL, '2026-07-27 12:00:00', 'TRANSPORTEUR', NULL),
    (14, 'DEPOSE_RELAIS',         3, '2026-07-29 09:50:00', 'POINT_RELAIS', NULL),
    (14, 'RETIRE_CLIENT',         3, '2026-07-31 16:00:00', 'POINT_RELAIS', 'Saisie erronée : confusion avec un autre colis'),
    (14, 'DEPOSE_RELAIS',         3, '2026-08-01 10:20:00', 'POINT_RELAIS', 'Correction : le colis est toujours au point relais');


COMMIT;   -- on valide l'ensemble


-- =============================================================================
--  CONTRÔLE DE COHÉRENCE
--  Le statut courant de chaque colis doit être identique au dernier statut
--  enregistré dans son historique.
--  ==> Cette requête doit retourner ZÉRO ligne. Si elle renvoie quelque chose,
--      c'est qu'une des deux écritures a été oubliée quelque part.
-- =============================================================================
SELECT  c.col_id,
        c.col_reference,
        c.col_statut  AS statut_courant,
        h.his_statut  AS dernier_statut_historise
FROM        colis c
JOIN        historique_statut h
              ON h.col_id = c.col_id
             AND h.his_date_changement = (SELECT MAX(h2.his_date_changement)
                                          FROM historique_statut h2
                                          WHERE h2.col_id = c.col_id)
WHERE   c.col_statut <> h.his_statut;

-- =============================================================================
--  FIN DU SCRIPT DE REMPLISSAGE
-- =============================================================================
