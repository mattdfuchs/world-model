/-
  WorldModel.KB.Types
  Entity types from the clinical-trial knowledge base (mcp/neo4j/script.txt).
-/

inductive Language where
  | English
  | Spanish
  | French
  deriving DecidableEq, Repr

inductive City where
  | Valencia
  | London
  | Nice
  | Paris   -- implied by ParisClinic IS_IN Paris
  deriving DecidableEq, Repr

inductive Clinic where
  | ValClinic
  | NiceClinic
  | ParisClinic
  | LondonClinic
  deriving DecidableEq, Repr

inductive ClinicalTrial where
  | OurTrial
  deriving DecidableEq, Repr

inductive Human where
  | Jose
  | Rick
  | Allen
  | Matthew
  deriving DecidableEq, Repr

inductive Role where
  | Patient
  | Administrator
  | Clinician
  deriving DecidableEq, Repr
