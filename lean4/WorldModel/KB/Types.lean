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

inductive ClinicalTrial : String → Type where
  | mk : (s : String) → ClinicalTrial s

-- ── Equipment and room types for nested scopes ──────────────────────────────

inductive ExamBed : Type where | mk
inductive BPMonitor : Type where | mk
inductive VO2Equipment : Type where | mk

-- ── Equipment qualification types (concepts — who holds them is a relation) ──

inductive ExamBedQual : Type where | mk
inductive BPMonitorQual : Type where | mk
inductive VO2EquipmentQual : Type where | mk

inductive Room : String → Type where
  | mk : (s : String) → Room s

inductive Human : String → Type where
  | mk : (s : String) → Human s

inductive Role where
  | Patient
  | Administrator
  | Clinician
  deriving DecidableEq, Repr

-- ── Edge relations for structure data (replaces ClinicInfo, ClinicalTrialInfo, RoomInfo) ──

inductive trialApproves {t c : String} (trial : ClinicalTrial t) (clinic : Clinic c) : Type where | mk
inductive clinicHasRoom {c r : String} (clinic : Clinic c) (room : Room r) : Type where | mk
inductive roomHasExamBed {r : String} (room : Room r) (equip : ExamBed) : Type where | mk
inductive roomHasBPMonitor {r : String} (room : Room r) (equip : BPMonitor) : Type where | mk
inductive roomHasVO2Equip {r : String} (room : Room r) (equip : VO2Equipment) : Type where | mk

-- ── Qualification-holding relations (clinician holds a qualification) ────────

inductive holdsExamBedQual {h : String} (person : Human h) (q : ExamBedQual) : Type where | mk
inductive holdsBPMonitorQual {h : String} (person : Human h) (q : BPMonitorQual) : Type where | mk
inductive holdsVO2EquipmentQual {h : String} (person : Human h) (q : VO2EquipmentQual) : Type where | mk
