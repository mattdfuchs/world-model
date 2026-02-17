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
