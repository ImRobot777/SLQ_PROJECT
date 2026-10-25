# Peer-to-Peer Parcel Delivery Relay Platform (SQL & Database Architecture)

Comprehensive relational database design and SQL implementation for a crowd-shipping and last-mile residential parcel delivery relay network (*"Point Relais à Domicile"*).

Designed using the **Merise methodology** (Conceptual & Logical Data Models) and implemented for **MySQL 8.0+ / MariaDB 10.6+** with strict 3NF normalization, automated constraint checks, business-driven triggers, and audit traceability.

---

## Architecture & Project Highlights

- **Domain Model**: Enables private residents to register as authorized micro-relays for partner logistics carriers, managing parcel reception, secure holding, and final customer pickup or carrier return.
- **Strict 3NF Relational Schema**: 7 core tables, 81 attributes, 10 foreign keys with referential integrity constraints.
- **Automated Business Rules**: 17 explicit `CHECK` constraints and generated columns directly enforcing domain invariants at the storage engine level.
- **Auditing & Event Sourcing**: Dedicated immutable state-change tracking (`historique_statut`) providing non-repudiation and chronological delivery timeline logging.
- **Optimized Storage**: InnoDB engine, UTF-8 (`utf8mb4`), custom B-Tree indexes on search paths, and 6 operational/reporting SQL views.

---

## Parcel Delivery Lifecycle

Parcels transition through a strict, deterministic finite state machine:

```text
[1] EN_COURS_LIVRAISON (Out for Delivery)
         │
         ▼
[2] DEPOSE_RELAIS (Deposited at Relay) ──[Customer Pickup]──► [3] RETIRE_CLIENT (Delivered)
         │
    14 Days Timeout
         │
         ▼
[4] NON_RECLAME (Unclaimed)
         │
         ▼
[5] EN_ATTENTE_REPRISE (Pending Carrier Return)
         │
         ▼
[6] REPRIS_TRANSPORTEUR (Returned to Carrier)
```

The 6 states are declared as an ordered `ENUM` type (`col_statut`, `his_statut`), enabling chronological ordering directly with `ORDER BY col_statut`.

---

## Core Database Schema

The database architecture is structured in 4 dependency tiers to eliminate cyclic dependencies:

```text
Level 1 (Independent):
  ├── particulier    (Registered individuals / relay candidates)
  ├── transporteur   (Logistics companies / carriers)
  └── client         (End-customer recipients)

Level 2 (Relational Core):
  └── mission        (Reified contractual mission between carrier & relay)

Level 3 (Entity of Interest):
  └── colis          (Physical parcel attributes, state, deadlines)

Level 4 (Audit & Traceability):
  └── historique_statut (Immutable audit log of all parcel transitions)
```

### Key Architectural Decisions

1. **State as an Enumerated Type rather than a Reference Table**
   - The 6 parcel states represent an immutable physical workflow.
   - Using `ENUM` allows composing native multi-column `CHECK` constraints (e.g., verifying that a delivered or returned parcel has an associated closing timestamp) without requiring triggers or cross-table joins.

2. **Reification of the `mission` Entity**
   - The association between an individual (`particulier`) and a carrier (`transporteur`) holds business attributes (validity timeframe, max capacity, active status) and must be referenced by parcels and audit logs.
   - Promoting this relation into a first-class entity allows referencing both the relay host and the responsible carrier with a single foreign key.

3. **Immutable Status History (`historique_statut`)**
   - The system preserves complete historical fidelity of every state transition with timestamp, active relay, and carrier reference.
   - The current status column in `colis.col_statut` provides performant point queries (deliberate, documented denormalization kept in sync with transactional guarantees).

4. **Engine-Enforced 14-Day Pickup Expiration**
   - `col_date_limite_retrait` is implemented as an automated generated column (`DATE_ADD(col_date_depot, INTERVAL 14 DAY)`), making calculation discrepancies impossible.

---

## Repository Structure

```text
├── 00_guide_pas_a_pas.md         # Comprehensive methodology guide and architectural defense
├── 01_analyse_et_conventions.md   # Functional analysis, 24 business scenarios & naming conventions
├── 02_dictionnaire_donnees.md     # Full data dictionary (types, lengths, nullability, domains)
├── 03_mcd.md                      # Conceptual Data Model (MCD) rules and entity definitions
├── 04_mld.md                      # Logical Data Model (MLD) transformation and normalization rules
├── 05_creation_bdd.sql            # Complete DDL script (tables, constraints, views, indexes)
├── 06_insertion_donnees.sql       # Representative test dataset with realistic edge cases
├── 07_tests_use_cases.sql         # Test suite with 24 verified nominal, limit, and error cases
├── 08_verification.md             # Model validation checklist and compliance matrix
├── mcd.mermaid / mcd.svg          # Visual Conceptual Data Model diagram
└── mld.mermaid / mld.svg          # Visual Logical Relational Schema diagram
```

---

## SQL Views & Reporting

The schema exposes 6 operational views for dashboard and administration queries:

- `vue_colis_en_relais`: Active parcels awaiting pickup at each relay point.
- `vue_colis_a_retourner`: Unclaimed parcels that exceeded the 14-day limit and require return handling.
- `vue_missions_actives`: Currently active carrier-relay assignments with capacity monitoring.
- `vue_disponibilites_relais`: Available relay storage slots based on volume and pending parcels.
- `vue_historique_colis`: Consolidated chronologically sorted audit trail per parcel.
- `vue_kpi_transporteurs`: Carrier performance analytics (delivery completion rates, average holding durations).

---

## Installation & Testing

### Prerequisites

- MySQL 8.0+ or MariaDB 10.6+
- Command line client (`mysql`) or GUI (DBeaver, MySQL Workbench, phpMyAdmin)

### Database Setup

```bash
# Clone the repository
git clone https://github.com/ImRobot777/SLQ_PROJECT.git
cd SLQ_PROJECT

# 1. Create schema, tables, views, and constraints
mysql -u root -p < 05_creation_bdd.sql

# 2. Populate test data
mysql -u root -p < 06_insertion_donnees.sql

# 3. Execute test cases and negative validation tests
mysql -u root -p < 07_tests_use_cases.sql
```

---

## Author

- **Guillaume Guitarian**
  - Application Developer & AI Engineer
  - LinkedIn: [linkedin.com/in/guillaume-guitarian](https://www.linkedin.com/in/guillaume-guitarian)
  - GitHub: [@ImRobot777](https://github.com/ImRobot777)
