/-
  WorldModel.KB.Relations
  Ground facts (as inductive predicates) and derived concepts.
-/
import WorldModel.KB.Types

-- Each constructor is one ground edge from the Cypher script.

inductive hasRole : Human → Role → Prop where
  | jose_patient    : hasRole .Jose    .Patient
  | rick_admin      : hasRole .Rick    .Administrator
  | allen_clinician : hasRole .Allen   .Clinician
  | matthew_clinician : hasRole .Matthew .Clinician

inductive speaks : Human → Language → Prop where
  | jose_spanish    : speaks .Jose    .Spanish
  | rick_english    : speaks .Rick    .English
  | allen_english   : speaks .Allen   .English
  | allen_spanish   : speaks .Allen   .Spanish
  | matthew_english : speaks .Matthew .English
  | matthew_french  : speaks .Matthew .French

inductive lives : Human → City → Prop where
  | jose_valencia : lives .Jose .Valencia

inductive assigned : Human → Clinic → Prop where
  | rick_london   : assigned .Rick    .LondonClinic
  | allen_val     : assigned .Allen   .ValClinic
  | matthew_nice  : assigned .Matthew .NiceClinic

inductive isIn : Clinic → City → Prop where
  | valClinic_valencia    : isIn .ValClinic    .Valencia
  | niceClinic_nice       : isIn .NiceClinic   .Nice
  | parisClinic_paris     : isIn .ParisClinic  .Paris
  | londonClinic_london   : isIn .LondonClinic .London

/-- Two humans can communicate if they share at least one language. -/
def canCommunicate (h1 h2 : Human) : Prop :=
  ∃ l : Language, speaks h1 l ∧ speaks h2 l

/-- A clinician can serve a patient if they can communicate. -/
def clinicianCanServe (clinician patient : Human) : Prop :=
  hasRole clinician .Clinician ∧ hasRole patient .Patient ∧ canCommunicate clinician patient

/-- A clinic is in the same city where a patient lives. -/
def clinicInPatientCity (c : Clinic) (p : Human) : Prop :=
  ∃ city : City, isIn c city ∧ lives p city
