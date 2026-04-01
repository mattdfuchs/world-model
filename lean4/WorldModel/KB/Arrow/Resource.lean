/-
  WorldModel.KB.Arrow.Resource
  Resource classification typeclasses for the Arrow system.

  Three exclusive marker classes partition pipeline resources:
    - `Consumed`: one-shot (measurements, evidence, drug doses)
    - `HasDual`:  conserved with named dual type (people, equipment, facilities)
    - `Specification`: conserved + carries Type 2 proof obligation (trials)

  `Dual` is a convenience marker derived from `HasDual`.
-/
import WorldModel.KB.Arrow.Clinical

-- ── Marker typeclasses ──────────────────────────────────────────────────────

/-- One-shot resource: produced, flows forward, never checked back in.
    Examples: measurements, evidence, drug doses, records. -/
class Consumed (α : Type) : Prop where

/-- Conserved resource with a named dual type.
    `HasDual.dual` is the co-endpoint (receipt, reservation, presence proof).
    Cup creates `(α, dual α)`, cap cancels the pair. -/
class HasDual (α : Type) where
  dual : Type

/-- Convenience marker: any type with `HasDual` is conserved. -/
class Dual (α : Type) : Prop where

instance [HasDual α] : Dual α where

/-- Conserved resource that additionally carries a Type 2 proof obligation.
    Cap on a `Specification` resource requires evidence of obligation discharge. -/
class Specification (α : Type) extends HasDual α where

-- ── HasDual instances (conserved resources) ────────────────────────────────

-- People
instance : HasDual (Patient name) where dual := PatientPresence name
instance : HasDual (Clinician name) where dual := ClinicianPresence name

-- Facilities / organizational
instance : HasDual (Clinic name) where dual := ClinicReservation name
instance : HasDual (Room name) where dual := RoomReservation name

-- Equipment
instance : HasDual ExamBed where dual := ExamBedReceipt
instance : HasDual BPMonitor where dual := BPMonitorReceipt
instance : HasDual VO2Equipment where dual := VO2EquipmentReceipt

-- ── Specification instances (conserved + proof obligation) ─────────────────

instance : Specification (ClinicalTrial name) where dual := TrialEnrollment name

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
instance : Consumed (DoseObligation name) where

-- Consent / disqualification
instance : Consumed (ConsentGiven name) where
instance : Consumed (NonQualifying name) where

-- Evidence
instance : Consumed (CallConfirmed name) where
instance : Consumed (SharedLangEvidence cn pn) where
instance : Consumed (ClinicCityEvidence cn pn) where

-- Qualification evidence
instance : Consumed (holdsExamBedQual person q) where
instance : Consumed (holdsBPMonitorQual person q) where
instance : Consumed (holdsVO2EquipmentQual person q) where

-- Dual types (one-shot receipts / presences)
instance : Consumed (PatientPresence name) where
instance : Consumed (ClinicianPresence name) where
instance : Consumed ExamBedReceipt where
instance : Consumed BPMonitorReceipt where
instance : Consumed VO2EquipmentReceipt where
instance : Consumed (RoomReservation name) where
instance : Consumed (ClinicReservation name) where
instance : Consumed (TrialEnrollment name) where

-- ── Smoke tests ──────────────────────────────────────────────────────────────

#check (inferInstance : HasDual (Patient "Jose"))
#check (inferInstance : Dual (Patient "Jose"))
#check (inferInstance : HasDual ExamBed)
#check (inferInstance : Specification (ClinicalTrial "OurTrial"))
#check (inferInstance : Consumed (HeartRate "Jose"))
#check (inferInstance : Consumed (Vial 2))
#check (inferInstance : Consumed (DoseObligation "Jose"))
#check (inferInstance : Consumed ExamBedReceipt)
