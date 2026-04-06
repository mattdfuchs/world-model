/-
  WorldModel.KB.Arrow.Clinical
  Full clinical pipeline using scope-derived constraints.

  Instead of a monolithic `LegalMeasurementMeeting`, constraints emerge from
  nested scopes:
    - Trial scope  → provides ClinicalTrial, declares clinicianSpeaksPatient
    - Clinic scope → provides Clinic, Clinician, proves city/assignment/approval/language
    - Room scope   → provides Room, Equipment, proves technician qualifications

  Each measurement step declares exactly what it needs (equipment, qualification,
  shared language). Missing constraints = type error.
-/
import WorldModel.KB.Arrow.Arrow
import WorldModel.KB.Arrow.SheetDiagram
import WorldModel.KB.Arrow.Scope
import WorldModel.KB.Facts           -- speaks facts for SharedLangEvidence

open KB.Facts

-- ── Domain types ──────────────────────────────────────────────────────────

inductive Patient : String → Type where
  | mk : (name : String) → Patient name

inductive Clinician : String → Type where
  | mk : (name : String) → Clinician name

inductive HeartRate : String → Type where
  | heartRate : {name : String} → Patient name → Int → HeartRate name

inductive BloodPressure : String → Type where
  | bloodPressure : {name : String} → Patient name → Rat → BloodPressure name

inductive VO2Max : String → Type where
  | vO2Max : {name : String} → Patient name → Int → VO2Max name

inductive ProductsOutput (name : String) where
  | products : String → Int → Rat → Int → ProductsOutput name

inductive AssessmentResult (name : String) where
  | success : Patient name → String → Int → Rat → Int → AssessmentResult name
  | failure : Patient name → String → AssessmentResult name

-- ── Rig-indexed and dependent domain types ────────────────────────────────

/-- A vial with `n` doses remaining.  Rig-indexed: `Vial 2 ≠ Vial 1` at the type level. -/
inductive Vial : Nat → Type where
  | mk : (n : Nat) → Vial n

/-- A drug dose drawn for a specific patient.  `DrugDose "Jose" ≠ DrugDose "Maria"`. -/
inductive DrugDose : String → Type where
  | mk : (patient : String) → DrugDose patient

/-- Record that a dose was administered to a specific patient. -/
inductive AdminRecord : String → Type where
  | mk : (patient : String) → AdminRecord patient

/-- Record of adverse events collected during a visit. -/
inductive AEReport : String → Type where
  | mk : (patientName : String) → AEReport patientName

/-- Survival status check result. -/
inductive SurvivalStatus : String → Type where
  | mk : (patientName : String) → SurvivalStatus patientName

-- ── Dual types (co-endpoints for conserved resources) ──────────────────────

/-- Proof of patient presence at a location. Dual of `Patient`. -/
inductive PatientPresence : String → Type where
  | mk : (name : String) → PatientPresence name

/-- Proof of clinician presence on-site. Dual of `Clinician`. -/
inductive ClinicianPresence : String → Type where
  | mk : (name : String) → ClinicianPresence name

/-- Receipt for checked-out exam bed. Dual of `ExamBed`. -/
inductive ExamBedReceipt : Type where | mk : ExamBedReceipt

/-- Receipt for checked-out BP monitor. Dual of `BPMonitor`. -/
inductive BPMonitorReceipt : Type where | mk : BPMonitorReceipt

/-- Receipt for checked-out VO2 equipment. Dual of `VO2Equipment`. -/
inductive VO2EquipmentReceipt : Type where | mk : VO2EquipmentReceipt

/-- Reservation for a room. Dual of `Room`. -/
inductive RoomReservation : String → Type where
  | mk : (name : String) → RoomReservation name

/-- Reservation for a clinic. Dual of `Clinic`. -/
inductive ClinicReservation : String → Type where
  | mk : (name : String) → ClinicReservation name

/-- Enrollment in a trial. Dual of `ClinicalTrial`. -/
inductive TrialEnrollment : String → Type where
  | mk : (name : String) → TrialEnrollment name

-- ── Obligation types (produced by arrow fission) ──────────────────────────

/-- Obligation that a dose was delivered to a specific patient.
    Produced when a dose is drawn from a vial (fission);
    cancelled by `cap` with `AdminRecord`. -/
inductive DoseObligation : String → Type where
  | mk : (patient : String) → DoseObligation patient

/-- Evidence that a confirmation call was made to a patient before a visit. -/
inductive CallConfirmed : String → Type where
  | mk : (patientName : String) → CallConfirmed patientName

-- ── Evidence types ──────────────────────────────────────────────────────────

/-- Proof that a clinician and patient share a language.
    Included in scope extensions so inner steps can find it via Satisfy/Elem. -/
structure SharedLangEvidence (cn pn : String) : Type where
  lang : String
  cSpeaks : speaks (Human.mk cn) (Language.mk lang)
  pSpeaks : speaks (Human.mk pn) (Language.mk lang)

/-- Proof that a clinic is in the same city where a patient lives. -/
structure ClinicCityEvidence (clinicName patientName : String) : Type where
  city   : String
  cIsIn  : isIn (Clinic.mk clinicName) (City.mk city)
  pLives : lives (Human.mk patientName) (City.mk city)

-- ── Consent and disqualification types ─────────────────────────────────────

/-- Consent was obtained — carries the patient and the consent note. -/
inductive ConsentGiven (name : String) : Type where
  | mk : Patient name → String → ConsentGiven name

/-- Reasons a patient can be disqualified at any measurement step. -/
inductive DisqualificationReason : Type where
  | consentRefused : String → DisqualificationReason
  | heartRateTooFast
  | bloodPressureTooHigh
  | vo2MaxTooLow

/-- Patient disqualified — carries the patient and the reason. -/
inductive NonQualifying (name : String) : Type where
  | mk : Patient name → DisqualificationReason → NonQualifying name

-- ── Constraint interpretation ──────────────────────────────────────────────

/-- Map a `ConstraintId` to the list of proof obligations it generates,
    given the current set of scope entries.  Each constraint is role-indexed:
    it only fires for entries with the matching tag. -/
def interpretConstraint (cid : ConstraintId) (entries : List ScopeEntry) : List Type :=
  match cid with
  | .clinicInPatientCity =>
      let clinics  := entries.filterMap fun e => if e.tag == .clinic  then some e.name else none
      let patients := entries.filterMap fun e => if e.tag == .patient then some e.name else none
      clinics.flatMap fun cn => patients.map fun pn => ClinicCityEvidence cn pn
  | .clinicianSpeaksPatient =>
      let clinicians := entries.filterMap fun e => if e.tag == .clinician then some e.name else none
      let patients   := entries.filterMap fun e => if e.tag == .patient   then some e.name else none
      clinicians.flatMap fun cn => patients.map fun pn => SharedLangEvidence cn pn
  | .clinicianAssigned =>
      let clinicians := entries.filterMap fun e => if e.tag == .clinician then some e.name else none
      let clinics    := entries.filterMap fun e => if e.tag == .clinic    then some e.name else none
      clinicians.flatMap fun cn => clinics.map fun cl => assigned (Human.mk cn) (Clinic.mk cl)
  | .trialApprovesClinic =>
      let trials  := entries.filterMap fun e => if e.tag == .trial  then some e.name else none
      let clinics := entries.filterMap fun e => if e.tag == .clinic then some e.name else none
      trials.flatMap fun tn => clinics.map fun cn => trialApproves (ClinicalTrial.mk tn) (Clinic.mk cn)
  | .examBedQual =>
      (entries.filterMap fun e => if e.tag == .examBedTech then some e.name else none).map fun n =>
        holdsExamBedQual (Human.mk n) .mk
  | .bpQual =>
      (entries.filterMap fun e => if e.tag == .bpTech then some e.name else none).map fun n =>
        holdsBPMonitorQual (Human.mk n) .mk
  | .vo2Qual =>
      (entries.filterMap fun e => if e.tag == .vo2Tech then some e.name else none).map fun n =>
        holdsVO2EquipmentQual (Human.mk n) .mk
  | .callConfirmed =>
      (entries.filterMap fun e => if e.tag == .patient then some e.name else none).map fun pn =>
        CallConfirmed pn

/-- Compute proof obligations that fire when `newItems` enter an existing `ScopeState`.
    - New constraints fire against ALL entries (existing + new)
    - Existing constraints fire against NEW entries only
    This avoids re-proving obligations from earlier scope levels. -/
def newObligations (newItems : List ScopeItem) (existingState : ScopeState) : List Type :=
  let fullState := newItems ++ existingState
  let allEntries := fullState.filterMap fun | .entry e => some e | _ => none
  let newConstraints := newItems.filterMap fun | .constraint c => some c | _ => none
  let existingConstraints := existingState.filterMap fun | .constraint c => some c | _ => none
  let newEntries := newItems.filterMap fun | .entry e => some e | _ => none
  -- New constraints fire against ALL entries
  (newConstraints.flatMap fun cid => interpretConstraint cid allEntries)
  -- Existing constraints fire against NEW entries only
  ++ (existingConstraints.flatMap fun cid => interpretConstraint cid newEntries)

