import WorldModel.KB.Boxes.Derive
import WorldModel.KB.Boxes.Compose
import WorldModel.KB.Boxes.Pipeline

inductive Patient : String → Type where
  | mk : (name : String) → Patient name

inductive Clinician : String → Type where
  | mk : (name : String) → Clinician name

inductive Decision (name : String) where
  | consent : Patient name → String → Decision name
  | refuse : Patient name → String → Decision name

inductive ExpandedDecision (pn : String) (cn : String) where
  | consent : (String × Patient pn × Clinician cn) → ExpandedDecision pn cn
  | refuse : (String × Patient pn × Clinician cn) → ExpandedDecision pn cn

-- Output inductives: separate explicit params so that compose! can select
-- Patient name at index 0 and the measurement value at index 1 independently.
inductive HeartRate : String → Type where
  | heartRate : {name : String} → Patient name → Int → HeartRate name

inductive BloodPressure : String → Type where
  | bloodPressure : {name : String} → Patient name → Rat → BloodPressure name

inductive VO2Max : String → Type where
  | vO2Max : {name : String} → Patient name → Int → VO2Max name

inductive Consenting (name : String) where
  | mk : Patient name → Decision name → Consenting name
  deriving ToBox

inductive ExplainedConsent (pn : String) (cn : String) where
  | mk : (Patient pn × Clinician cn) → ExpandedDecision pn cn → ExplainedConsent pn cn
  deriving ToBox

inductive HeartMeasurement (name : String) where
  | heartMeasurement : Patient name → HeartRate name → HeartMeasurement name
  deriving ToBox

inductive BloodPressureMeasurement (name : String) where
  | bloodPressureMeasurement : Patient name → BloodPressure name → BloodPressureMeasurement name
  deriving ToBox

inductive VO2MaxMeasurement (name : String) where
  | vO2MaxMeasurement : Patient name → VO2Max name → VO2MaxMeasurement name
  deriving ToBox

-- Decidability checks: same-shaped type substitutes itself; different shapes do not.
example : mightSubstitute (Consenting "foo") (Consenting "foo") := by decide
example : mightSubstitute (ExplainedConsent "foo" "bar") (Consenting "foo") := by decide
example : ¬mightSubstitute (Consenting "foo") (HeartMeasurement "foo") := by decide

-- Concrete values for patient "foo"
def pFoo   : Patient "foo" := Patient.mk "foo"
def cFoo   : Consenting "foo" :=
  Consenting.mk pFoo (Decision.consent pFoo "signed")
def hmFoo  : HeartMeasurement "foo" :=
  HeartMeasurement.heartMeasurement pFoo (HeartRate.heartRate pFoo 72)
def bpFoo  : BloodPressureMeasurement "foo" :=
  BloodPressureMeasurement.bloodPressureMeasurement pFoo (BloodPressure.bloodPressure pFoo 120)
def vo2Foo : VO2MaxMeasurement "foo" :=
  VO2MaxMeasurement.vO2MaxMeasurement pFoo (VO2Max.vO2Max pFoo 45)

-- compose! chain: Patient "foo" is threaded from stage to stage.
-- Each step selects index 0 of the output branch, which is Patient "foo".
def compose_c_hm : Compose :=
  compose! [(cFoo,  "consent",       [0])] => hmFoo
def compose_hm_bp : Compose :=
  compose! [(hmFoo, "heartRate",     [0])] => bpFoo
def compose_bp_v2 : Compose :=
  compose! [(bpFoo, "bloodPressure", [0])] => vo2Foo

/-! ### Pipeline: type-level wiring of the full clinical assessment workflow -/

-- Collects all measurement values from each branch of the clinical pathway.
-- inputs: String (consent note), Int (heart rate), Rat (blood pressure), Int (VO2 max)
inductive ProductsOutput (name : String) where
  | products : String → Int → Rat → Int → ProductsOutput name

inductive Products (name : String) where
  | mk : (String × Int × Rat × Int) → ProductsOutput name → Products name
  deriving ToBox

-- Terminates the consent-refuse path; absorbs (Patient, String) with no further outputs.
inductive ConsentRefusal (name : String) where
  | terminate : (Patient name × String) → Bottom → ConsentRefusal name
  deriving ToBox

-- Output inductive for the final assessment stage.
inductive AssessmentResult (name : String) where
  | success : Patient name → String → Int → Rat → Int → AssessmentResult name
  | failure : Patient name → String → AssessmentResult name

-- Aggregates all clinical data and produces a success or failure assessment.
inductive FinalAssessment (name : String) where
  | mk : (Patient name × String × Int × Rat × Int) → AssessmentResult name → FinalAssessment name
  deriving ToBox

-- Seven-stage pipeline (indices 0–6):
--   0: Consenting "foo"              inputs: [Patient(foo)]
--   1: HeartMeasurement "foo"        inputs: [Patient(foo)]
--   2: BloodPressureMeasurement "foo" inputs: [Patient(foo)]
--   3: VO2MaxMeasurement "foo"       inputs: [Patient(foo)]
--   4: Products "foo"                inputs: [String, Int, Rat, Int]
--   5: ConsentRefusal "foo"          inputs: [Patient(foo), String]
--   6: FinalAssessment "foo"         inputs: [Patient(foo), String, Int, Rat, Int]
--
-- Wiring summary:
--   consent branch:    Patient(foo) → (1,0)   String → (4,0)
--   refuse  branch:    Patient(foo) → (5,0)   String → (5,1)
--   heartRate branch:  Patient(foo) → (2,0)   Int    → (4,1)
--   bloodPressure:     Patient(foo) → (3,0)   Rat    → (4,2)
--   vO2Max:            Patient(foo) → (6,0)   Int    → (4,3)
--   products:          String → (6,1)  Int → (6,2)  Rat → (6,3)  Int → (6,4)
--   bottom:            (terminated — no params)
def alicePipeline :=
  mkPipeline
    [ ToBox.toBox (α := Consenting "foo"),
      ToBox.toBox (α := HeartMeasurement "foo"),
      ToBox.toBox (α := BloodPressureMeasurement "foo"),
      ToBox.toBox (α := VO2MaxMeasurement "foo"),
      ToBox.toBox (α := Products "foo"),
      ToBox.toBox (α := ConsentRefusal "foo"),
      ToBox.toBox (α := FinalAssessment "foo") ]
    [ [⟨"consent",       [(1, 0), (4, 0)]⟩, ⟨"refuse",  [(5, 0), (5, 1)]⟩],
      [⟨"heartRate",     [(2, 0), (4, 1)]⟩],
      [⟨"bloodPressure", [(3, 0), (4, 2)]⟩],
      [⟨"vO2Max",        [(6, 0), (4, 3)]⟩],
      [⟨"products",      [(6, 1), (6, 2), (6, 3), (6, 4)]⟩],
      [⟨"bottom",        []⟩] ]
    (by native_decide)
