/-
  WorldModel.KB.Types
  Entity types from the clinical-trial knowledge base (mcp/neo4j/script.txt).
  Each type wraps a String label. Any string can inhabit the type;
  the relations constrain which labels carry meaning.
-/

inductive Language : String → Type where
  | mk : (s : String) → Language s

inductive City : String → Type where
  | mk : (s : String) → City s

inductive Clinic : String → Type where
  | mk : (s : String) → Clinic s

structure ClinicInfo (name : String) where
  clinicians : List String
  rooms : List String

inductive ClinicalTrial : String → Type where
  | mk : (s : String) → ClinicalTrial s

structure ClinicalTrialInfo (name : String) where
  approvedClinics : List String

-- ── Equipment and room types for nested scopes ──────────────────────────────

inductive ExamBed : Type where | mk
inductive BPMonitor : Type where | mk
inductive VO2Equipment : Type where | mk

-- ── Equipment qualification types (clinician certified to use equipment) ────

inductive ExamBedQual : String → Type where | mk : (s : String) → ExamBedQual s
inductive BPMonitorQual : String → Type where | mk : (s : String) → BPMonitorQual s
inductive VO2EquipmentQual : String → Type where | mk : (s : String) → VO2EquipmentQual s

/-- Room marker for use in contexts. Equipment is tracked separately in RoomInfo. -/
inductive Room : String → Type where
  | mk : (s : String) → Room s

/-- Room metadata: maps a room name to its available equipment. -/
structure RoomInfo (name : String) where
  equipment : List Type

inductive Human : String → Type where
  | mk : (s : String) → Human s

inductive Role where
  | Patient
  | Administrator
  | Clinician
  deriving DecidableEq, Repr
