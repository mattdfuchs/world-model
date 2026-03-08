/-
  WorldModel.KB.Boxes.Clinical
  Proof-bearing step types for clinical measurements.

  Each clinical step type takes a `LegalMeasurementMeeting patientName` as a
  TYPE PARAMETER (not a value field).  This means:

    • The meeting is verified ONCE when the pipeline type is formed, not
      repeated on every step construction.
    • `LegalMeasurementMeeting "Jose"` is a different type from
      `LegalMeasurementMeeting "Alice"` — the patient is enforced at the
      type level.
    • A step value only needs to supply the measurement data (`value`);
      the authorisation is already baked into the type.

  The `ToBox` instance for each clinical type delegates to its plain
  counterpart, so the Box shape is identical and `mightSubstitute` holds.

  Module dependencies:
    WorldModel.KB.Boxes.Ontology  — MeasurementStep class + plain step types
    WorldModel.KB.Relations       — LegalMeasurementMeeting
    WorldModel.KB.Facts           — joseMeetingAllen ground proof
-/
import WorldModel.KB.Boxes.Ontology
import WorldModel.KB.Relations
import WorldModel.KB.Facts

-- ── ClinicalHeartMeasurement ──────────────────────────────────────────────────

/-- A `HeartMeasurement` whose authorising meeting is baked into the type.
    `ClinicalHeartMeasurement "Jose" joseMeetingAllen` can only be formed
    if `joseMeetingAllen : LegalMeasurementMeeting "Jose"` is already in scope. -/
structure ClinicalHeartMeasurement (name : String) (meeting : LegalMeasurementMeeting name) where
  value : HeartMeasurement name

instance {name : String} {meeting : LegalMeasurementMeeting name} :
    ToBox (ClinicalHeartMeasurement name meeting) where
  toBox := ToBox.toBox (α := HeartMeasurement name)

instance {name : String} {meeting : LegalMeasurementMeeting name} :
    MeasurementStep (ClinicalHeartMeasurement name meeting) := ⟨⟩

-- ── ClinicalBloodPressureMeasurement ─────────────────────────────────────────

/-- A `BloodPressureMeasurement` whose authorising meeting is baked into the type. -/
structure ClinicalBloodPressureMeasurement (name : String) (meeting : LegalMeasurementMeeting name) where
  value : BloodPressureMeasurement name

instance {name : String} {meeting : LegalMeasurementMeeting name} :
    ToBox (ClinicalBloodPressureMeasurement name meeting) where
  toBox := ToBox.toBox (α := BloodPressureMeasurement name)

instance {name : String} {meeting : LegalMeasurementMeeting name} :
    MeasurementStep (ClinicalBloodPressureMeasurement name meeting) := ⟨⟩

-- ── ClinicalVO2MaxMeasurement ─────────────────────────────────────────────────

/-- A `VO2MaxMeasurement` whose authorising meeting is baked into the type. -/
structure ClinicalVO2MaxMeasurement (name : String) (meeting : LegalMeasurementMeeting name) where
  value : VO2MaxMeasurement name

instance {name : String} {meeting : LegalMeasurementMeeting name} :
    ToBox (ClinicalVO2MaxMeasurement name meeting) where
  toBox := ToBox.toBox (α := VO2MaxMeasurement name)

instance {name : String} {meeting : LegalMeasurementMeeting name} :
    MeasurementStep (ClinicalVO2MaxMeasurement name meeting) := ⟨⟩

-- ── Substitutability checks (step level) ─────────────────────────────────────

example : mightSubstitute (ClinicalHeartMeasurement "Jose" joseMeetingAllen)
                          (HeartMeasurement "Jose")          := by native_decide
example : mightSubstitute (ClinicalBloodPressureMeasurement "Jose" joseMeetingAllen)
                          (BloodPressureMeasurement "Jose")  := by native_decide
example : mightSubstitute (ClinicalVO2MaxMeasurement "Jose" joseMeetingAllen)
                          (VO2MaxMeasurement "Jose")         := by native_decide

-- ── joseAlicePipeline ─────────────────────────────────────────────────────────
-- The pipeline type encodes `joseMeetingAllen` directly.  The meeting is
-- verified once here — no step constructor will ask for it again.
--
-- Stage map:
--   0: Consenting                                    "Jose"
--   1: ClinicalHeartMeasurement         "Jose" joseMeetingAllen
--   2: ClinicalBloodPressureMeasurement "Jose" joseMeetingAllen
--   3: ClinicalVO2MaxMeasurement        "Jose" joseMeetingAllen
--   4: Products                                      "Jose"
--   5: ConsentRefusal                                "Jose"
--   6: FinalAssessment                               "Jose"

abbrev joseAliceBoxes : List Box :=
  [ ToBox.toBox (α := Consenting "Jose"),
    ToBox.toBox (α := ClinicalHeartMeasurement         "Jose" joseMeetingAllen),
    ToBox.toBox (α := ClinicalBloodPressureMeasurement "Jose" joseMeetingAllen),
    ToBox.toBox (α := ClinicalVO2MaxMeasurement        "Jose" joseMeetingAllen),
    ToBox.toBox (α := Products "Jose"),
    ToBox.toBox (α := ConsentRefusal "Jose"),
    ToBox.toBox (α := FinalAssessment "Jose") ]

abbrev joseAliceWirings : List TypeWiring :=
  [ [⟨"consent",       [(1, 0), (4, 0)]⟩, ⟨"refuse",  (5, 0)⟩],
    [⟨"heartRate",     [(2, 0), (4, 1)]⟩],
    [⟨"bloodPressure", [(3, 0), (4, 2)]⟩],
    [⟨"vO2Max",        [(6, 0), (4, 3)]⟩],
    [⟨"products",      [(6, 1), (6, 2), (6, 3), (6, 4)]⟩],
    [⟨"bottom",        []⟩] ]

/-- The pipeline for Jose / Allen / ValClinic.
    Its type carries `joseMeetingAllen` — the complete proof that Allen is a
    licensed clinician who speaks Spanish, is assigned to ValClinic, and
    ValClinic is in Valencia where Jose lives. -/
def joseAlicePipeline : Pipeline joseAliceBoxes joseAliceWirings :=
  mkPipeline joseAliceBoxes joseAliceWirings (by native_decide)

instance : ClinicalEncounter (Pipeline joseAliceBoxes joseAliceWirings) := ⟨⟩

#eval joseAlicePipeline.box.inputs
-- ["Patient(Jose)"]
#eval joseAlicePipeline.box.outputs
-- [("success", ["Patient(Jose)", "String", "Int", "Rat", "Int"]),
--  ("failure", ["Patient(Jose)", "String"])]

-- ── Substitutability check (pipeline level) ───────────────────────────────────
-- The clinical pipeline (with meeting) substitutes for the plain pipeline.

example : mightSubstitute
    (Pipeline joseAliceBoxes  joseAliceWirings)
    (Pipeline aliceBoxes      aliceWirings)     := by native_decide

-- ── Concrete step values ──────────────────────────────────────────────────────
-- The meeting is already in the type.  Constructors only supply the measurement
-- data — there is no `meeting` field to fill in.

def joseHeartStep : ClinicalHeartMeasurement "Jose" joseMeetingAllen :=
  { value := HeartMeasurement.heartMeasurement
               (Patient.mk "Jose")
               (HeartRate.heartRate (Patient.mk "Jose") 72) }

def joseBloodPressureStep : ClinicalBloodPressureMeasurement "Jose" joseMeetingAllen :=
  { value := BloodPressureMeasurement.bloodPressureMeasurement
               (Patient.mk "Jose")
               (BloodPressure.bloodPressure (Patient.mk "Jose") 120) }

def joseVO2MaxStep : ClinicalVO2MaxMeasurement "Jose" joseMeetingAllen :=
  { value := VO2MaxMeasurement.vO2MaxMeasurement
               (Patient.mk "Jose")
               (VO2Max.vO2Max (Patient.mk "Jose") 45) }
