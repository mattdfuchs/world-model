/-
  WorldModel.KB.Arrow.Resource
  Resource classification typeclasses for the Arrow system.

  Two exclusive marker classes partition pipeline resources:
    - `Consumed`: one-shot (measurements, evidence, drug doses)
    - `Dual`:     conserved with complementary endpoints (people, equipment, facilities)
-/
import WorldModel.KB.Arrow.Clinical

-- ── Marker typeclasses ──────────────────────────────────────────────────────

/-- One-shot resource: produced, flows forward, never checked back in.
    Examples: measurements, evidence, drug doses, records. -/
class Consumed (α : Type) : Prop where

/-- Conserved resource with complementary endpoints: checked in/out of scopes.
    Examples: people, equipment, facilities, organizational entities. -/
class Dual (α : Type) : Prop where

-- ── Dual instances (conserved resources) ────────────────────────────────────

-- People
instance : Dual (Patient name) where
instance : Dual (Clinician name) where

-- Facilities / organizational
instance : Dual (Clinic name) where
instance : Dual (ClinicalTrial name) where
instance : Dual (Room name) where

-- Equipment
instance : Dual ExamBed where
instance : Dual BPMonitor where
instance : Dual VO2Equipment where

-- ── Consumed instances (one-shot resources) ──────────────────────────────────

-- Measurements
instance : Consumed (HeartRate name) where
instance : Consumed (BloodPressure name) where
instance : Consumed (VO2Max name) where

-- Results
instance : Consumed (ProductsOutput name) where
instance : Consumed (AssessmentResult name) where

-- Drug lifecycle
instance : Consumed (Vial n) where
instance : Consumed (DrugDose name) where
instance : Consumed (AdminRecord name) where

-- Consent / disqualification
instance : Consumed (ConsentGiven name) where
instance : Consumed (NonQualifying name) where

-- Evidence
instance : Consumed (SharedLangEvidence cn pn) where
instance : Consumed (ClinicCityEvidence cn pn) where

-- Qualification evidence
instance : Consumed (holdsExamBedQual person q) where
instance : Consumed (holdsBPMonitorQual person q) where
instance : Consumed (holdsVO2EquipmentQual person q) where

-- ── Smoke tests ──────────────────────────────────────────────────────────────

#check (inferInstance : Dual (Patient "Jose"))
#check (inferInstance : Dual (Clinician "Allen"))
#check (inferInstance : Dual ExamBed)
#check (inferInstance : Consumed (HeartRate "Jose"))
#check (inferInstance : Consumed (Vial 2))
#check (inferInstance : Consumed (SharedLangEvidence "Allen" "Jose"))
