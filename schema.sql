-- Illustrative PostgreSQL DDL for the vision screening sample data model (Edgent LLC).
-- Demonstrates enforced capture: completion is blocked unless required fields or a
-- documented exception are present. Not a production schema.

CREATE TABLE district (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  district_number text NOT NULL UNIQUE,
  name            text NOT NULL
);

CREATE TABLE campus (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  district_id   uuid NOT NULL,
  campus_number text NOT NULL UNIQUE,
  name          text NOT NULL,
  CONSTRAINT fk_campus_district_id FOREIGN KEY (district_id) REFERENCES district(id) ON DELETE RESTRICT
);

CREATE TABLE student (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tsds_unique_id text NOT NULL UNIQUE,      -- TSDS Unique ID
  first_name     text NOT NULL,
  last_name      text NOT NULL,
  date_of_birth  date NOT NULL
);

CREATE TABLE enrollment (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id  uuid NOT NULL,
  campus_id   uuid NOT NULL,
  entry_date  date NOT NULL,
  exit_date   date,                          -- null while active; TREx-triggered on transfer
  grade_level text NOT NULL,
  CONSTRAINT fk_enrollment_student_id FOREIGN KEY (student_id) REFERENCES student(id) ON DELETE RESTRICT,
  CONSTRAINT fk_enrollment_campus_id FOREIGN KEY (campus_id) REFERENCES campus(id) ON DELETE RESTRICT
);

CREATE TABLE consent (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id     uuid NOT NULL,
  status         text NOT NULL CHECK (status IN ('opt_in','opt_out')),   -- SB 12 (89R)
  effective_date date NOT NULL,
  recorded_by    text NOT NULL,
  CONSTRAINT fk_consent_student_id FOREIGN KEY (student_id) REFERENCES student(id) ON DELETE RESTRICT
);

CREATE TABLE screener (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name_printed  text NOT NULL,
  credential    text,
  teal_identity text                          -- TEAL-mapped identity
);

CREATE TABLE screening (
  id                           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  enrollment_id                uuid NOT NULL,
  screener_id                  uuid NOT NULL,
  screening_date               date NOT NULL,
  age_on_screening_date        int  NOT NULL,
  screening_type               text NOT NULL,
  method                       text NOT NULL CHECK (method IN ('traditional_chart','electronic_chart')),
  prescreen_checklist_complete boolean NOT NULL DEFAULT false,
  status                       text NOT NULL CHECK (status IN ('in_progress','complete','unable_to_screen','referred_not_screened')),
  unable_reason_code           text,
  offline_captured             boolean NOT NULL DEFAULT false,
  -- workflow gate: cannot be complete without the pre-screen checklist;
  -- cannot be 'unable_to_screen' without a standardized reason code
  CONSTRAINT screening_complete_requires_checklist
    CHECK (status <> 'complete' OR prescreen_checklist_complete),
  CONSTRAINT unable_requires_reason
    CHECK (status <> 'unable_to_screen' OR unable_reason_code IS NOT NULL),
  CONSTRAINT fk_screening_enrollment_id FOREIGN KEY (enrollment_id) REFERENCES enrollment(id) ON DELETE RESTRICT,
  CONSTRAINT fk_screening_screener_id FOREIGN KEY (screener_id) REFERENCES screener(id) ON DELETE RESTRICT
);

CREATE TABLE screening_result (
  id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  screening_id              uuid NOT NULL UNIQUE,
  acuity_od                 text NOT NULL,    -- right eye, approved format
  acuity_os                 text NOT NULL,    -- left eye, approved format
  corrective_lenses_used    boolean NOT NULL,
  signs_symptoms_observed   boolean NOT NULL,
  outcome                   text NOT NULL CHECK (outcome IN ('pass','fail','refer')),
  outcome_threshold_version text NOT NULL,  -- version-controlled outcome thresholds
  CONSTRAINT fk_screening_result_screening_id FOREIGN KEY (screening_id) REFERENCES screening(id) ON DELETE RESTRICT
);

CREATE TABLE screening_exception (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  screening_id  uuid NOT NULL,
  exception_code text NOT NULL,
  documentation  text NOT NULL,
  CONSTRAINT fk_screening_exception_screening_id FOREIGN KEY (screening_id) REFERENCES screening(id) ON DELETE RESTRICT
);

CREATE TABLE referral (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  screening_id  uuid NOT NULL,
  reason        text NOT NULL,
  referred_date date NOT NULL,
  status        text NOT NULL CHECK (status IN ('open','notified','outcome_received','closed')),
  CONSTRAINT fk_referral_screening_id FOREIGN KEY (screening_id) REFERENCES screening(id) ON DELETE RESTRICT
);

CREATE TABLE follow_up (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  referral_id  uuid NOT NULL,
  contact_date date NOT NULL,
  channel      text NOT NULL,
  outcome      text NOT NULL,
  CONSTRAINT fk_follow_up_referral_id FOREIGN KEY (referral_id) REFERENCES referral(id) ON DELETE RESTRICT
);

CREATE TABLE treatment (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  referral_id   uuid NOT NULL,
  kind          text NOT NULL CHECK (kind IN ('recommended','received')),
  description   text NOT NULL,
  recorded_date date NOT NULL,
  CONSTRAINT fk_treatment_referral_id FOREIGN KEY (referral_id) REFERENCES referral(id) ON DELETE RESTRICT
);

CREATE TABLE certification (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campus_id    uuid NOT NULL,
  school_year  text NOT NULL,
  status       text NOT NULL CHECK (status IN ('draft','certified','reopened')),
  certified_by text,
  certified_at timestamptz,
  CONSTRAINT fk_certification_campus_id FOREIGN KEY (campus_id) REFERENCES campus(id) ON DELETE RESTRICT
);

CREATE TABLE audit_event (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type  text NOT NULL,
  entity_id    uuid NOT NULL,          -- deliberately no FK: polymorphic across entity_type;
                                        -- integrity is enforced by the writing service, and audit
                                        -- rows must survive the deletion of what they describe
  action       text NOT NULL,
  actor        text NOT NULL,
  at           timestamptz NOT NULL DEFAULT now(),
  prior_values jsonb                          -- full before-image for controlled corrections
);
CREATE INDEX audit_event_entity_idx ON audit_event(entity_type, entity_id, at);
