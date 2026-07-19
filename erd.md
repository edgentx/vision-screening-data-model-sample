# Entity-Relationship Diagram — Statewide Vision Screening Data Collection (Sample)

```mermaid
erDiagram
    DISTRICT ||--o{ CAMPUS : contains
    CAMPUS ||--o{ ENROLLMENT : hosts
    STUDENT ||--o{ ENROLLMENT : "enrolls (TSDS Unique ID)"
    STUDENT ||--o{ CONSENT : "has (SB 12 opt-in/out)"
    ENROLLMENT ||--o{ SCREENING : "screened during"
    SCREENER ||--o{ SCREENING : conducts
    SCREENING ||--|| SCREENING_RESULT : yields
    SCREENING ||--o{ SCREENING_EXCEPTION : "may record"
    SCREENING ||--o{ REFERRAL : "may create"
    REFERRAL ||--o{ FOLLOW_UP : tracked_by
    REFERRAL ||--o{ TREATMENT : "recommended/received"
    CAMPUS ||--o{ CERTIFICATION : "certifies to LEA"
    SCREENING ||--o{ AUDIT_EVENT : logs
    CONSENT ||--o{ AUDIT_EVENT : logs

    STUDENT {
        uuid id PK
        string tsds_unique_id UK "TSDS Unique ID integration"
        string first_name
        string last_name
        date date_of_birth
    }
    DISTRICT {
        uuid id PK
        string district_number UK "TEA district number"
        string name
    }
    CAMPUS {
        uuid id PK
        uuid district_id FK
        string campus_number UK "TEA campus number"
        string name
    }
    ENROLLMENT {
        uuid id PK
        uuid student_id FK
        uuid campus_id FK
        date entry_date
        date exit_date "null while active; TREx-triggered transfer"
        string grade_level
    }
    CONSENT {
        uuid id PK
        uuid student_id FK
        string status "opt_in | opt_out"
        date effective_date
        string recorded_by
    }
    SCREENER {
        uuid id PK
        string name_printed
        string credential
        string teal_identity "TEAL-mapped identity"
    }
    SCREENING {
        uuid id PK
        uuid enrollment_id FK
        uuid screener_id FK
        date screening_date
        int age_on_screening_date
        string screening_type
        string method "traditional_chart | electronic_chart"
        bool prescreen_checklist_complete "gate: required before initiation"
        string status "complete | unable_to_screen | referred_not_screened"
        string unable_reason_code "standardized reason codes"
        bool offline_captured "offline capture, synced"
    }
    SCREENING_RESULT {
        uuid id PK
        uuid screening_id FK
        string acuity_od "right eye, approved format"
        string acuity_os "left eye, approved format"
        bool corrective_lenses_used
        bool signs_symptoms_observed
        string outcome "pass | fail | refer"
        string outcome_threshold_version "version-controlled thresholds"
    }
    SCREENING_EXCEPTION {
        uuid id PK
        uuid screening_id FK
        string exception_code
        string documentation
    }
    REFERRAL {
        uuid id PK
        uuid screening_id FK
        string reason
        date referred_date
        string status "open | notified | outcome_received | closed"
    }
    FOLLOW_UP {
        uuid id PK
        uuid referral_id FK
        date contact_date
        string channel
        string outcome "communication attempts and outcomes"
    }
    TREATMENT {
        uuid id PK
        uuid referral_id FK
        string kind "recommended | received"
        string description
        date recorded_date
    }
    CERTIFICATION {
        uuid id PK
        uuid campus_id FK
        string school_year
        string status "draft | certified | reopened"
        string certified_by
        datetime certified_at
    }
    AUDIT_EVENT {
        uuid id PK
        string entity_type
        uuid entity_id
        string action
        string actor "user identity"
        datetime at
        jsonb prior_values "full before-image for corrections"
    }
```

## Design notes

- **Student record continuity.** `STUDENT` is identified by the TSDS Unique ID; `ENROLLMENT` carries campus/district
  attachment over time, so screening history follows the student across LEAs (TREx-standard portability) without
  manual re-entry.
- **Workflow enforcement.** `SCREENING.prescreen_checklist_complete` and required-field constraints (see `schema.sql`)
  block completion until DSHS-required elements or a documented exception are present.
- **Consent-aware reporting.** Reporting denominators derive from `CONSENT` state as of the screening date; consent
  changes are audit-logged.
- **Version-controlled thresholds.** `SCREENING_RESULT.outcome_threshold_version` pins each outcome to the threshold
  set in force, supporting controlled changes over time.
- **Auditability.** `AUDIT_EVENT` captures actor, timestamp, and prior values for every modification, supporting
  certification, controlled corrections, and audit sampling.
