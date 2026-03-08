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

-- Output inductive for Consenting: consent decomposes into (Patient, String);
-- refuse carries the whole Decision so it can be routed as a single value.
inductive ConsentingOutput (name : String) where
  | consent : Patient name → String → ConsentingOutput name
  | refuse  : Decision name → ConsentingOutput name

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
  | mk : Patient name → ConsentingOutput name → Consenting name
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
example : mightSubstitute (Consenting "Jose") (Consenting "Jose") := by decide
example : ¬mightSubstitute (Consenting "Jose") (HeartMeasurement "Jose") := by decide

-- Concrete values for patient "Jose"
def pJose   : Patient "Jose" := Patient.mk "Jose"
def cJose   : Consenting "Jose" :=
  Consenting.mk pJose (ConsentingOutput.consent pJose "signed")
def hmJose  : HeartMeasurement "Jose" :=
  HeartMeasurement.heartMeasurement pJose (HeartRate.heartRate pJose 72)
def bpJose  : BloodPressureMeasurement "Jose" :=
  BloodPressureMeasurement.bloodPressureMeasurement pJose (BloodPressure.bloodPressure pJose 120)
def vo2Jose : VO2MaxMeasurement "Jose" :=
  VO2MaxMeasurement.vO2MaxMeasurement pJose (VO2Max.vO2Max pJose 45)

-- compose! chain: Patient "Jose" is threaded from stage to stage.
-- Each step selects index 0 of the output branch, which is Patient "Jose".
def compose_c_hm : Compose :=
  compose! [(cJose,  "consent",       [0])] => hmJose
def compose_hm_bp : Compose :=
  compose! [(hmJose, "heartRate",     [0])] => bpJose
def compose_bp_v2 : Compose :=
  compose! [(bpJose, "bloodPressure", [0])] => vo2Jose

/-! ### Pipeline: type-level wiring of the full clinical assessment workflow -/

-- Collects all measurement values from each branch of the clinical pathway.
-- inputs: String (consent note), Int (heart rate), Rat (blood pressure), Int (VO2 max)
inductive ProductsOutput (name : String) where
  | products : String → Int → Rat → Int → ProductsOutput name

inductive Products (name : String) where
  | mk : (String × Int × Rat × Int) → ProductsOutput name → Products name
  deriving ToBox

-- Terminates the consent-refuse path; absorbs the whole Decision with no further outputs.
inductive ConsentRefusal (name : String) where
  | terminate : Decision name → Bottom → ConsentRefusal name
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
--   0: Consenting "Jose"              inputs: [Patient(Jose)]
--   1: HeartMeasurement "Jose"        inputs: [Patient(Jose)]
--   2: BloodPressureMeasurement "Jose" inputs: [Patient(Jose)]
--   3: VO2MaxMeasurement "Jose"       inputs: [Patient(Jose)]
--   4: Products "Jose"                inputs: [String, Int, Rat, Int]
--   5: ConsentRefusal "Jose"          inputs: [Decision(Jose)]
--   6: FinalAssessment "Jose"         inputs: [Patient(Jose), String, Int, Rat, Int]
--
-- Wiring summary:
--   consent branch:    Patient(Jose) → (1,0)   String → (4,0)
--   refuse  branch:    Decision(Jose) → (5,0)
--   heartRate branch:  Patient(Jose) → (2,0)   Int    → (4,1)
--   bloodPressure:     Patient(Jose) → (3,0)   Rat    → (4,2)
--   vO2Max:            Patient(Jose) → (6,0)   Int    → (4,3)
--   products:          String → (6,1)  Int → (6,2)  Rat → (6,3)  Int → (6,4)
--   bottom:            (terminated — no params)

-- Named abbrevs expose the Pipeline type so downstream modules can form
-- `mightSubstitute` proofs without spelling out the full inlined list literals.
abbrev aliceBoxes : List Box :=
  [ ToBox.toBox (α := Consenting "Jose"),
    ToBox.toBox (α := HeartMeasurement "Jose"),
    ToBox.toBox (α := BloodPressureMeasurement "Jose"),
    ToBox.toBox (α := VO2MaxMeasurement "Jose"),
    ToBox.toBox (α := Products "Jose"),
    ToBox.toBox (α := ConsentRefusal "Jose"),
    ToBox.toBox (α := FinalAssessment "Jose") ]

abbrev aliceWirings : List TypeWiring :=
  [ [⟨"consent",       [(1, 0), (4, 0)]⟩, ⟨"refuse",  (5, 0)⟩],
    [⟨"heartRate",     [(2, 0), (4, 1)]⟩],
    [⟨"bloodPressure", [(3, 0), (4, 2)]⟩],
    [⟨"vO2Max",        [(6, 0), (4, 3)]⟩],
    [⟨"products",      [(6, 1), (6, 2), (6, 3), (6, 4)]⟩],
    [⟨"bottom",        []⟩] ]

def alicePipeline : Pipeline aliceBoxes aliceWirings :=
  mkPipeline aliceBoxes aliceWirings (by native_decide)

-- The composed pipeline is itself a ToBox instance.
-- Its Box exposes the first stage's inputs and the last stage's outputs,
-- making it usable as a single stage in a larger pipeline.
#eval alicePipeline.box.inputs
-- ["Patient(Jose)"]
#eval alicePipeline.box.outputs
-- [("success", ["Patient(Jose)", "String", "Int", "Rat", "Int"]),
--  ("failure", ["Patient(Jose)", "String"])]
