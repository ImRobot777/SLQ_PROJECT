-- =============================================================================
--  PLATEFORME « POINT RELAIS À DOMICILE » - SCRIPT DE CRÉATION DE LA BASE
-- =============================================================================
--  Projet   : Gestion de la livraison de colis via points relais à domicile
--  Méthode  : Merise (dictionnaire -> MCD -> MLD -> SQL)
--  SGBD     : MySQL 8.0.16+ / MariaDB 10.6+   (moteur InnoDB, encodage utf8mb4)
--  Fichier  : 05_creation_bdd.sql
--
--  L'ORDRE DE CRÉATION SUIT LE CLASSEMENT PAR NIVEAUX (voir MLD §5.4).
--  Une table qui contient une clé étrangère ne peut pas être créée avant la
--  table qu'elle cite :
--    Niveau 0 : adresse                         (aucune clé étrangère)
--    Niveau 1 : particulier, transporteur, client
--    Niveau 2 : mission
--    Niveau 3 : colis
--    Niveau 4 : historique_statut
--
--  LE STATUT D'UN COLIS EST UN TYPE ÉNUMÉRÉ, PAS UNE TABLE DE RÉFÉRENCE.
--  Les 6 valeurs sont déclarées DANS L'ORDRE DU PARCOURS : MySQL trie un
--  énuméré selon cet ordre de déclaration (et non alphabétiquement), donc un
--  simple « ORDER BY his_statut » restitue le déroulé chronologique.
--
--  Rappel des préfixes de contraintes :
--    pk_ = clé primaire | fk_ = clé étrangère
--    uq_ = unicité      | ck_ = règle de validation | idx_ = index
-- =============================================================================


-- -----------------------------------------------------------------------------
--  0. CRÉATION DE LA BASE
--  Le DROP en tête rend le script rejouable autant de fois qu'on veut.
-- -----------------------------------------------------------------------------
DROP DATABASE IF EXISTS relais_domicile;

CREATE DATABASE relais_domicile
    DEFAULT CHARACTER SET utf8mb4          -- gère les accents et tous les caractères
    DEFAULT COLLATE utf8mb4_unicode_ci;    -- comparaisons insensibles à la casse

USE relais_domicile;


-- =============================================================================
--  NIVEAU 0 - TABLE SANS AUCUNE CLÉ ÉTRANGÈRE
-- =============================================================================

-- -----------------------------------------------------------------------------
--  adresse
--  Une seule table d'adresses, partagée par les particuliers, les transporteurs
--  et les clients : on évite de recopier trois fois les mêmes colonnes.
-- -----------------------------------------------------------------------------
CREATE TABLE adresse (
    adr_id          INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    adr_numero      VARCHAR(10)         NULL COMMENT 'Texte et non nombre, pour gérer « 12 bis »',
    adr_voie        VARCHAR(150)    NOT NULL,
    adr_complement  VARCHAR(150)        NULL,
    adr_code_postal CHAR(5)         NOT NULL COMMENT 'Longueur fixe : CHAR et non VARCHAR',
    adr_ville       VARCHAR(100)    NOT NULL,
    adr_pays        VARCHAR(60)     NOT NULL DEFAULT 'France',
    adr_latitude    DECIMAL(9,6)        NULL,
    adr_longitude   DECIMAL(9,6)        NULL,
    CONSTRAINT pk_adresse PRIMARY KEY (adr_id),
    CONSTRAINT ck_adresse_code_postal CHECK (adr_code_postal REGEXP '^[0-9]{5}$')
) ENGINE = InnoDB COMMENT = 'Adresses postales, mutualisées entre tous les acteurs';

CREATE INDEX idx_adresse_code_postal ON adresse (adr_code_postal);


-- =============================================================================
--  NIVEAU 1 - TABLES QUI CITENT LE NIVEAU 0
-- =============================================================================

-- -----------------------------------------------------------------------------
--  particulier - le point relais
--
--  Cette table regroupe TROIS choses :
--    1. l'identité et le compte du particulier
--    2. la description de son logement   (ex-tables LOGEMENT et TYPE_LOGEMENT)
--    3. ses disponibilités               (ex-table DISPONIBILITE)
--  Voir la justification de ces fusions au §2.5 du document 01.
-- -----------------------------------------------------------------------------
CREATE TABLE particulier (
    par_id                  INT UNSIGNED NOT NULL AUTO_INCREMENT,
    adr_id                  INT UNSIGNED NOT NULL,

    -- --- Identité et compte ---------------------------------------------------
    par_civilite            ENUM('M','MME','AUTRE') NOT NULL DEFAULT 'AUTRE',
    par_nom                 VARCHAR(80)  NOT NULL,
    par_prenom              VARCHAR(80)  NOT NULL,
    par_date_naissance      DATE         NOT NULL,
    par_email               VARCHAR(150) NOT NULL COMMENT 'Sert d''identifiant de connexion (RG01)',
    par_telephone           VARCHAR(20)  NOT NULL,
    par_mot_de_passe_hash   CHAR(60)     NOT NULL COMMENT 'Hachage bcrypt - jamais le mot de passe en clair (RG16)',
    par_date_inscription    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- --- Description du logement (ex-LOGEMENT + ex-TYPE_LOGEMENT) -------------
    par_type_logement       ENUM('MAISON','APPARTEMENT','LOCAL_PRO','ATELIER') NOT NULL,
    par_etage               TINYINT          NULL COMMENT '0 = rez-de-chaussée',
    par_a_ascenseur         BOOLEAN      NOT NULL DEFAULT FALSE,
    par_surface_stockage_m2 DECIMAL(5,2)     NULL COMMENT 'Surface dédiée au stockage, en m2',
    par_capacite_max_colis  SMALLINT UNSIGNED NOT NULL DEFAULT 5 COMMENT 'Nb max de colis simultanés (RG13)',
    par_est_securise        BOOLEAN      NOT NULL DEFAULT FALSE COMMENT 'Local fermé à clé - critère d''éligibilité',
    par_commentaire_acces   VARCHAR(255)     NULL COMMENT 'Précisions d''accès : interphone, portail...',

    -- --- Disponibilités (ex-DISPONIBILITE) ------------------------------------
    par_disponibilites      VARCHAR(255)     NULL
        COMMENT 'Texte libre : « Lun-Ven 18h-20h30, Sam 9h-12h ». Non interrogeable - compromis assumé (RG03)',

    -- --- Statut du compte -----------------------------------------------------
    par_est_eligible        BOOLEAN      NOT NULL DEFAULT FALSE COMMENT 'Logement conforme aux besoins des transporteurs',
    par_est_actif           BOOLEAN      NOT NULL DEFAULT FALSE COMMENT 'Tous les inscrits ne sont pas points relais',
    par_date_desactivation  DATETIME         NULL,

    CONSTRAINT pk_particulier PRIMARY KEY (par_id),
    CONSTRAINT uq_particulier_email UNIQUE (par_email),
    CONSTRAINT fk_particulier_adresse FOREIGN KEY (adr_id)
        REFERENCES adresse (adr_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_particulier_email    CHECK (par_email LIKE '%_@_%._%'),
    CONSTRAINT ck_particulier_capacite CHECK (par_capacite_max_colis > 0),
    CONSTRAINT ck_particulier_surface
        CHECK (par_surface_stockage_m2 IS NULL OR par_surface_stockage_m2 > 0),
    -- Un compte encore actif ne peut pas porter de date de désactivation.
    CONSTRAINT ck_particulier_desactivation
        CHECK (par_date_desactivation IS NULL OR par_est_actif = FALSE)
) ENGINE = InnoDB COMMENT = 'Particuliers proposant leur domicile comme point relais';

CREATE INDEX idx_particulier_actif ON particulier (par_est_actif, par_est_eligible);


-- -----------------------------------------------------------------------------
--  transporteur - société partenaire
-- -----------------------------------------------------------------------------
CREATE TABLE transporteur (
    tra_id                     SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT
        COMMENT 'SMALLINT : quelques dizaines de partenaires attendus, inutile de voir plus grand',
    adr_id                     INT UNSIGNED      NOT NULL,
    tra_raison_sociale         VARCHAR(120)      NOT NULL,
    tra_siret                  CHAR(14)          NOT NULL,
    tra_email                  VARCHAR(150)      NOT NULL,
    tra_telephone              VARCHAR(20)       NOT NULL,
    tra_contact_nom            VARCHAR(120)          NULL,
    tra_date_debut_partenariat DATE              NOT NULL,
    tra_date_fin_partenariat   DATE                  NULL COMMENT 'Vide = partenariat en cours',
    tra_est_actif              BOOLEAN           NOT NULL DEFAULT TRUE,
    CONSTRAINT pk_transporteur PRIMARY KEY (tra_id),
    CONSTRAINT uq_transporteur_siret UNIQUE (tra_siret),
    CONSTRAINT fk_transporteur_adresse FOREIGN KEY (adr_id)
        REFERENCES adresse (adr_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_transporteur_siret CHECK (tra_siret REGEXP '^[0-9]{14}$'),
    CONSTRAINT ck_transporteur_partenariat
        CHECK (tra_date_fin_partenariat IS NULL
               OR tra_date_fin_partenariat >= tra_date_debut_partenariat)
) ENGINE = InnoDB COMMENT = 'Transporteurs partenaires de la plateforme';


-- -----------------------------------------------------------------------------
--  client - destinataire final du colis
-- -----------------------------------------------------------------------------
CREATE TABLE client (
    cli_id        INT UNSIGNED NOT NULL AUTO_INCREMENT,
    adr_id        INT UNSIGNED NOT NULL,
    cli_civilite  ENUM('M','MME','AUTRE')     NULL,
    cli_nom       VARCHAR(80)  NOT NULL,
    cli_prenom    VARCHAR(80)  NOT NULL,
    cli_email     VARCHAR(150)     NULL,
    cli_telephone VARCHAR(20)      NULL,
    CONSTRAINT pk_client PRIMARY KEY (cli_id),
    CONSTRAINT fk_client_adresse FOREIGN KEY (adr_id)
        REFERENCES adresse (adr_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    -- E-mail et téléphone sont facultatifs individuellement, mais il en faut AU MOINS UN :
    -- sans moyen de contact, impossible de prévenir le client (UC16).
    CONSTRAINT ck_client_contact
        CHECK (cli_email IS NOT NULL OR cli_telephone IS NOT NULL)
) ENGINE = InnoDB COMMENT = 'Clients finaux destinataires des colis';


-- =============================================================================
--  NIVEAU 2 - TABLE QUI CITE LE NIVEAU 1
-- =============================================================================

-- -----------------------------------------------------------------------------
--  mission - le contrat entre un particulier et un transporteur
--
--  C'est la « table d'association » du lien plusieurs-à-plusieurs
--  « un particulier travaille pour plusieurs transporteurs et réciproquement ».
--  Elle a une clé primaire technique (mis_id) plutôt que le couple
--  (par_id, tra_id), car un même couple peut avoir plusieurs missions
--  successives dans le temps.
-- -----------------------------------------------------------------------------
CREATE TABLE mission (
    mis_id                 INT UNSIGNED      NOT NULL AUTO_INCREMENT,
    par_id                 INT UNSIGNED      NOT NULL,
    tra_id                 SMALLINT UNSIGNED NOT NULL,
    mis_date_candidature   DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP,
    mis_date_validation    DATETIME              NULL COMMENT 'Vide tant que le transporteur n''a pas répondu',
    mis_date_debut         DATE              NOT NULL,
    mis_date_fin           DATE                  NULL COMMENT 'Vide = durée indéterminée',
    mis_statut             ENUM('EN_ATTENTE','ACTIVE','SUSPENDUE','TERMINEE','REFUSEE')
                                             NOT NULL DEFAULT 'EN_ATTENTE',
    mis_capacite_max_colis SMALLINT UNSIGNED     NULL COMMENT 'Quota alloué à ce transporteur',
    mis_commentaire        VARCHAR(255)          NULL COMMENT 'Motif de refus, remarque...',
    CONSTRAINT pk_mission PRIMARY KEY (mis_id),
    CONSTRAINT uq_mission_periode UNIQUE (par_id, tra_id, mis_date_debut),
    CONSTRAINT fk_mission_particulier FOREIGN KEY (par_id)
        REFERENCES particulier (par_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_mission_transporteur FOREIGN KEY (tra_id)
        REFERENCES transporteur (tra_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_mission_periode
        CHECK (mis_date_fin IS NULL OR mis_date_fin >= mis_date_debut),
    -- Une mission acceptée porte forcément une date de validation.
    CONSTRAINT ck_mission_validation
        CHECK (mis_statut IN ('EN_ATTENTE','REFUSEE') OR mis_date_validation IS NOT NULL)
) ENGINE = InnoDB COMMENT = 'Missions de point relais : particulier x transporteur x période';

CREATE INDEX idx_mission_periode ON mission (mis_statut, mis_date_debut, mis_date_fin);


-- =============================================================================
--  NIVEAU 3 - TABLE QUI CITE LE NIVEAU 2
-- =============================================================================

-- -----------------------------------------------------------------------------
--  colis - l'objet central du système
-- -----------------------------------------------------------------------------
CREATE TABLE colis (
    col_id                   BIGINT UNSIGNED   NOT NULL AUTO_INCREMENT
        COMMENT 'BIGINT : le cahier des charges annonce un volume important',
    col_reference            VARCHAR(30)       NOT NULL COMMENT 'Numéro de suivi vu par le client (RG14)',
    tra_id                   SMALLINT UNSIGNED NOT NULL,
    cli_id                   INT UNSIGNED      NOT NULL,
    mis_id                   INT UNSIGNED          NULL
        COMMENT 'VIDE tant que le colis n''est pas déposé - cardinalité 0,1 (RG09)',

    -- LE STATUT COURANT : type énuméré, valeurs déclarées dans l'ordre du parcours.
    -- Redondant avec l'historique : dénormalisation assumée (RG12, §2.4 du doc 01).
    col_statut               ENUM('EN_COURS_LIVRAISON',
                                  'DEPOSE_RELAIS',
                                  'RETIRE_CLIENT',
                                  'NON_RECLAME',
                                  'EN_ATTENTE_REPRISE',
                                  'REPRIS_TRANSPORTEUR')
                                             NOT NULL DEFAULT 'EN_COURS_LIVRAISON'
                                             COMMENT 'Statut courant du colis',

    col_poids_kg             DECIMAL(5,2)      NOT NULL COMMENT 'DECIMAL et jamais FLOAT',
    col_longueur_cm          SMALLINT UNSIGNED     NULL,
    col_largeur_cm           SMALLINT UNSIGNED     NULL,
    col_hauteur_cm           SMALLINT UNSIGNED     NULL,
    col_valeur_declaree_eur  DECIMAL(8,2)          NULL,
    col_est_fragile          BOOLEAN           NOT NULL DEFAULT FALSE,
    col_code_retrait         CHAR(6)               NULL COMMENT 'Généré au dépôt, à présenter pour retirer (RG15)',
    col_date_prise_en_charge DATETIME          NOT NULL COMMENT 'Entrée du colis dans le système',
    col_date_depot_relais    DATETIME              NULL COMMENT 'Vide tant que le colis est en tournée',

    -- RG10 - LA DATE LIMITE EST CALCULÉE PAR LA BASE, JAMAIS SAISIE.
    -- Une « colonne générée » se recalcule toute seule et refuse toute écriture
    -- directe : le délai de 14 jours ne peut donc pas être falsifié.
    col_date_limite_retrait  DATE
        GENERATED ALWAYS AS (DATE(col_date_depot_relais) + INTERVAL 14 DAY) STORED
        COMMENT 'RG10 : date de dépôt + 14 jours',

    col_date_cloture         DATETIME              NULL COMMENT 'Renseignée quand le colis atteint un statut final',

    CONSTRAINT pk_colis PRIMARY KEY (col_id),
    CONSTRAINT uq_colis_reference UNIQUE (col_reference),
    CONSTRAINT fk_colis_transporteur FOREIGN KEY (tra_id)
        REFERENCES transporteur (tra_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_colis_client FOREIGN KEY (cli_id)
        REFERENCES client (cli_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_colis_mission FOREIGN KEY (mis_id)
        REFERENCES mission (mis_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_colis_poids  CHECK (col_poids_kg > 0),
    CONSTRAINT ck_colis_valeur CHECK (col_valeur_declaree_eur IS NULL OR col_valeur_declaree_eur >= 0),
    CONSTRAINT ck_colis_depot
        CHECK (col_date_depot_relais IS NULL
               OR col_date_depot_relais >= col_date_prise_en_charge),
    -- Cohérence : un colis déposé est forcément rattaché à une mission,
    -- et un colis rattaché à une mission a forcément une date de dépôt.
    CONSTRAINT ck_colis_depot_mission
        CHECK ((col_date_depot_relais IS NULL     AND mis_id IS NULL)
            OR (col_date_depot_relais IS NOT NULL AND mis_id IS NOT NULL)),
    -- NOUVEAU, rendu possible par le passage à l'énuméré : le statut étant
    -- désormais DANS la table, on peut poser une règle qui le combine avec une
    -- autre colonne. Un colis arrivé à un statut terminal a forcément une date
    -- de clôture. Avec une clé étrangère vers une table de référence, cette
    -- règle aurait exigé une jointure - donc impossible en CHECK.
    CONSTRAINT ck_colis_cloture
        CHECK (col_statut NOT IN ('RETIRE_CLIENT','REPRIS_TRANSPORTEUR')
               OR col_date_cloture IS NOT NULL),
    -- De même : sauf en cours de livraison, un colis a forcément été déposé.
    CONSTRAINT ck_colis_statut_depot
        CHECK (col_statut = 'EN_COURS_LIVRAISON' OR col_date_depot_relais IS NOT NULL)
) ENGINE = InnoDB COMMENT = 'Colis pris en charge par la plateforme';

CREATE INDEX idx_colis_statut_limite ON colis (col_statut, col_date_limite_retrait);
CREATE INDEX idx_colis_mission       ON colis (mis_id, col_statut);
CREATE INDEX idx_colis_client        ON colis (cli_id);


-- =============================================================================
--  NIVEAU 4 - TABLE QUI CITE LE NIVEAU 3
-- =============================================================================

-- -----------------------------------------------------------------------------
--  historique_statut - la mémoire du système (RG11)
--
--  Une ligne par changement d'état. C'est ce qui répond à l'exigence du cahier
--  des charges : « conserver l'historique des changements d'état des colis, en
--  incluant les dates, le point relais concerné et le transporteur responsable ».
--  La clé étrangère vers la mission donne d'un seul coup le point relais ET le
--  transporteur : inutile de les recopier ici.
-- -----------------------------------------------------------------------------
CREATE TABLE historique_statut (
    his_id              BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
    col_id              BIGINT UNSIGNED  NOT NULL,
    mis_id              INT UNSIGNED         NULL COMMENT 'Vide pour les événements antérieurs au dépôt',

    -- Mêmes 6 valeurs que colis.col_statut, dans le même ordre.
    his_statut          ENUM('EN_COURS_LIVRAISON',
                             'DEPOSE_RELAIS',
                             'RETIRE_CLIENT',
                             'NON_RECLAME',
                             'EN_ATTENTE_REPRISE',
                             'REPRIS_TRANSPORTEUR')
                                         NOT NULL COMMENT 'Statut atteint à cette date',

    his_date_changement DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    his_origine         ENUM('TRANSPORTEUR','POINT_RELAIS','CLIENT','SYSTEME')
                                         NOT NULL DEFAULT 'SYSTEME'
                                         COMMENT 'Qui a déclenché le changement',
    his_commentaire     VARCHAR(255)         NULL,
    CONSTRAINT pk_historique_statut PRIMARY KEY (his_id),
    CONSTRAINT uq_historique_evenement UNIQUE (col_id, his_statut, his_date_changement),
    CONSTRAINT fk_historique_colis FOREIGN KEY (col_id)
        REFERENCES colis (col_id) ON DELETE CASCADE ON UPDATE RESTRICT,
    CONSTRAINT fk_historique_mission FOREIGN KEY (mis_id)
        REFERENCES mission (mis_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    -- Tout événement autre que la prise en charge initiale est rattaché à une mission.
    CONSTRAINT ck_historique_mission
        CHECK (his_statut = 'EN_COURS_LIVRAISON' OR mis_id IS NOT NULL)
) ENGINE = InnoDB COMMENT = 'Historique des changements d''état des colis';

CREATE INDEX idx_historique_colis_date ON historique_statut (col_id, his_date_changement);
CREATE INDEX idx_historique_mission    ON historique_statut (mis_id, his_date_changement);


-- =============================================================================
--  VUES DE CONSULTATION
--
--  Une VUE est une requête à laquelle on donne un nom. Elle ne stocke rien :
--  elle recalcule à chaque appel, donc elle est toujours à jour.
--  Elle permet d'écrire « SELECT * FROM v_colis_a_retourner » au lieu de
--  réécrire une jointure de plusieurs tables à chaque fois.
--
--  Le libellé lisible du statut (« Déposé au point relais ») était autrefois
--  stocké dans la table de référence. Il est maintenant produit par une
--  expression CASE, ici, au plus près de l'affichage.
-- =============================================================================

-- -----------------------------------------------------------------------------
--  UC20 / RG04 - les points relais réellement opérationnels aujourd'hui
--  (compte actif ET au moins une mission en cours à la date du jour)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_point_relais_actif AS
SELECT  p.par_id,
        CONCAT(p.par_prenom, ' ', p.par_nom)      AS par_identite,
        p.par_email,
        p.par_telephone,
        CONCAT_WS(' ', a.adr_numero, a.adr_voie)  AS adr_rue,
        a.adr_code_postal,
        a.adr_ville,
        p.par_type_logement,
        p.par_capacite_max_colis,
        p.par_est_securise,
        p.par_disponibilites,
        COUNT(DISTINCT m.mis_id)                  AS nb_missions_actives,
        GROUP_CONCAT(DISTINCT t.tra_raison_sociale ORDER BY t.tra_raison_sociale SEPARATOR ', ')
                                                  AS transporteurs
FROM        particulier  p
JOIN        adresse      a ON a.adr_id = p.adr_id
JOIN        mission      m ON m.par_id = p.par_id
                           AND m.mis_statut     = 'ACTIVE'
                           AND m.mis_date_debut <= CURDATE()
                           AND (m.mis_date_fin IS NULL OR m.mis_date_fin >= CURDATE())
JOIN        transporteur t ON t.tra_id = m.tra_id
WHERE   p.par_est_actif = TRUE
GROUP BY p.par_id, p.par_prenom, p.par_nom, p.par_email, p.par_telephone,
         a.adr_numero, a.adr_voie, a.adr_code_postal, a.adr_ville,
         p.par_type_logement, p.par_capacite_max_colis, p.par_est_securise,
         p.par_disponibilites;


-- -----------------------------------------------------------------------------
--  UC21 - colis en attente de retrait, les plus urgents en premier
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_colis_en_attente_retrait AS
SELECT  c.col_id,
        c.col_reference,
        t.tra_raison_sociale,
        CONCAT(p.par_prenom, ' ', p.par_nom)                                    AS point_relais,
        CONCAT_WS(' ', a.adr_numero, a.adr_voie, a.adr_code_postal, a.adr_ville) AS relais_adresse,
        p.par_disponibilites                                                    AS relais_horaires,
        CONCAT(cl.cli_prenom, ' ', cl.cli_nom)                                  AS destinataire,
        cl.cli_email,
        cl.cli_telephone,
        c.col_date_depot_relais,
        c.col_date_limite_retrait,
        DATEDIFF(c.col_date_limite_retrait, CURDATE())                          AS jours_restants
FROM        colis        c
JOIN        mission      m  ON m.mis_id  = c.mis_id
JOIN        particulier  p  ON p.par_id  = m.par_id
JOIN        adresse      a  ON a.adr_id  = p.adr_id
JOIN        transporteur t  ON t.tra_id  = c.tra_id
JOIN        client       cl ON cl.cli_id = c.cli_id
WHERE   c.col_statut = 'DEPOSE_RELAIS'
ORDER BY jours_restants ASC;


-- -----------------------------------------------------------------------------
--  UC24 - colis que le traitement automatique doit basculer en NON_RECLAME
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_colis_a_basculer_non_reclame AS
SELECT  c.col_id,
        c.col_reference,
        c.mis_id,
        c.col_date_depot_relais,
        c.col_date_limite_retrait,
        DATEDIFF(CURDATE(), c.col_date_limite_retrait) AS jours_de_retard
FROM    colis c
WHERE   c.col_statut = 'DEPOSE_RELAIS'
  AND   c.col_date_limite_retrait < CURDATE();


-- -----------------------------------------------------------------------------
--  UC13 / UC22 - colis à retourner : encore chez le particulier, attendent le camion
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_colis_a_retourner AS
SELECT  c.col_id,
        c.col_reference,
        c.col_statut,
        CASE c.col_statut
             WHEN 'NON_RECLAME'        THEN 'Non réclamé - délai de 14 jours dépassé'
             WHEN 'EN_ATTENTE_REPRISE' THEN 'En attente de reprise par le transporteur'
        END                                                                     AS statut_libelle,
        t.tra_id,
        t.tra_raison_sociale,
        CONCAT(p.par_prenom, ' ', p.par_nom)                                    AS point_relais,
        p.par_telephone                                                         AS relais_telephone,
        CONCAT_WS(' ', a.adr_numero, a.adr_voie, a.adr_code_postal, a.adr_ville) AS relais_adresse,
        c.col_date_limite_retrait,
        DATEDIFF(CURDATE(), c.col_date_limite_retrait)                          AS jours_depuis_expiration
FROM        colis        c
JOIN        mission      m ON m.mis_id = c.mis_id
JOIN        particulier  p ON p.par_id = m.par_id
JOIN        adresse      a ON a.adr_id = p.adr_id
JOIN        transporteur t ON t.tra_id = c.tra_id
WHERE   c.col_statut IN ('NON_RECLAME','EN_ATTENTE_REPRISE')
ORDER BY jours_depuis_expiration DESC;


-- -----------------------------------------------------------------------------
--  UC18 / UC19 - la « timeline » complète d'un colis
--  Chaque ligne : la date, le statut atteint, l'origine, le point relais
--  et le transporteur responsable - exactement ce qu'exige le cahier des charges.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_historique_colis AS
SELECT  c.col_reference,
        h.his_date_changement,
        h.his_statut,
        CASE h.his_statut
             WHEN 'EN_COURS_LIVRAISON'  THEN 'En cours de livraison par le transporteur'
             WHEN 'DEPOSE_RELAIS'       THEN 'Déposé au point relais'
             WHEN 'RETIRE_CLIENT'       THEN 'Retiré par le client final'
             WHEN 'NON_RECLAME'         THEN 'Non réclamé - délai de 14 jours dépassé'
             WHEN 'EN_ATTENTE_REPRISE'  THEN 'En attente de reprise par le transporteur'
             WHEN 'REPRIS_TRANSPORTEUR' THEN 'Repris par le transporteur'
        END                                                 AS statut_libelle,
        h.his_origine,
        t.tra_raison_sociale                                AS transporteur_responsable,
        CASE WHEN m.mis_id IS NULL THEN NULL
             ELSE CONCAT(p.par_prenom, ' ', p.par_nom) END  AS point_relais,
        h.his_commentaire
FROM        historique_statut h
JOIN        colis        c ON c.col_id = h.col_id
JOIN        transporteur t ON t.tra_id = c.tra_id
LEFT JOIN   mission      m ON m.mis_id = h.mis_id
LEFT JOIN   particulier  p ON p.par_id = m.par_id
ORDER BY c.col_reference, h.his_date_changement;


-- -----------------------------------------------------------------------------
--  RG13 - charge actuelle de chaque point relais
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_charge_point_relais AS
SELECT  p.par_id,
        CONCAT(p.par_prenom, ' ', p.par_nom)          AS point_relais,
        p.par_capacite_max_colis,
        COUNT(c.col_id)                               AS nb_colis_en_garde,
        p.par_capacite_max_colis - COUNT(c.col_id)    AS places_disponibles
FROM        particulier p
LEFT JOIN   mission     m ON m.par_id = p.par_id
LEFT JOIN   colis       c ON c.mis_id = m.mis_id
                          AND c.col_statut IN ('DEPOSE_RELAIS','NON_RECLAME','EN_ATTENTE_REPRISE')
GROUP BY p.par_id, p.par_prenom, p.par_nom, p.par_capacite_max_colis;


-- =============================================================================
--  FIN DU SCRIPT DE CRÉATION
-- =============================================================================
