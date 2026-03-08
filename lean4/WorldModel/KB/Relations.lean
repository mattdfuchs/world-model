/-
  WorldModel.KB.Relations
  Relation type definitions and derived concepts.
-/
import WorldModel.KB.Types

inductive hasRole {h : String} (a : Human h) (r : Role) : Type where
  | mk : hasRole a r

inductive speaks {h l : String} (a : Human h) (b : Language l) : Type where
  | mk : speaks a b

inductive lives {h c : String} (a : Human h) (b : City c) : Type where
  | mk : lives a b

inductive assigned {h c : String} (a : Human h) (b : Clinic c) : Type where
  | mk : assigned a b

inductive isIn {c t : String} (a : Clinic c) (b : City t) : Type where
  | mk : isIn a b

/-- Two humans can communicate if they share at least one language. -/
def canCommunicate {h1 h2 : String} (p1 : Human h1) (p2 : Human h2) : Prop :=
  ∃ (l : String) (lang : Language l), Nonempty (speaks p1 lang) ∧ Nonempty (speaks p2 lang)

/-- A clinician can serve a patient if they can communicate. -/
def clinicianCanServe {h1 h2 : String} (clinician : Human h1) (patient : Human h2) : Prop :=
  Nonempty (hasRole clinician .Clinician) ∧ Nonempty (hasRole patient .Patient) ∧
  canCommunicate clinician patient

/-- A clinic is in the same city where a patient lives. -/
def clinicInPatientCity {c p : String} (clinic : Clinic c) (patient : Human p) : Prop :=
  ∃ (t : String) (city : City t), Nonempty (isIn clinic city) ∧ Nonempty (lives patient city)

def legalMeeting {c p cl : String} (clinic : Clinic c) (patient : Human p) (clinician : Human cl) : Prop :=
  clinicInPatientCity clinic patient ∧ clinicianCanServe clinician patient ∧
  Nonempty (assigned clinician clinic)

/-- A LegalMeeting bundles a clinic, patient, and clinician together with
    proofs that all the conditions for a legal meeting hold. -/
structure LegalMeeting where
  {c p cl : String}
  clinic    : Clinic c
  patient   : Human p
  clinician : Human cl
  inCity    : clinicInPatientCity clinic patient
  canServe  : clinicianCanServe clinician patient
  isAssigned : assigned clinician clinic

/-- A LegalMeasurementMeeting specialises LegalMeeting for the context of
    taking a clinical measurement.  The patient name is an explicit type
    parameter so that the meeting can only be used for the right patient —
    `LegalMeasurementMeeting "Jose"` is a different type from
    `LegalMeasurementMeeting "Alice"`.

    The role attestations (`patientRole`, `clinicianRole`) and the shared-language
    condition (`sharedLang`) are surfaced as first-class fields rather than bundled
    inside `canServe`, so that audit logs and downstream steps can inspect each
    condition individually without re-decomposing the conjunction. -/
structure LegalMeasurementMeeting (patientName : String) where
  {c cl : String}
  clinic        : Clinic c
  patient       : Human patientName
  clinician     : Human cl
  patientRole   : hasRole patient   .Patient
  clinicianRole : hasRole clinician .Clinician
  inCity        : clinicInPatientCity clinic patient
  sharedLang    : canCommunicate clinician patient
  isAssigned    : assigned clinician clinic

/-- Every `LegalMeasurementMeeting` satisfies the weaker `LegalMeeting`
    conditions, so it can be used wherever a `LegalMeeting` is required. -/
def LegalMeasurementMeeting.toLegalMeeting {p : String} (m : LegalMeasurementMeeting p) : LegalMeeting :=
  { clinic     := m.clinic
    patient    := m.patient
    clinician  := m.clinician
    inCity     := m.inCity
    canServe   := ⟨⟨m.clinicianRole⟩, ⟨m.patientRole⟩, m.sharedLang⟩
    isAssigned := m.isAssigned }
