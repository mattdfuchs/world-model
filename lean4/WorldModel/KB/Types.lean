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

inductive Human : String → Type where
  | mk : (s : String) → Human s

inductive Role where
  | Patient
  | Administrator
  | Clinician
  deriving DecidableEq, Repr
