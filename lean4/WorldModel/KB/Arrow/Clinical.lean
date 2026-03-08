/-
  WorldModel.KB.Arrow.Clinical
  Full happy-path clinical pipeline using the indexed arrow system.

  Key difference from the Boxes/Clinical system:
    `LegalMeasurementMeeting "Jose"` is an OBJECT in the context,
    not a type parameter.  The frame rule ensures it persists across
    steps without being consumed.

  The pipeline models the happy path (consent obtained):
    0. Consent         → produces ConsentingOutput
    1. HeartMeasurement  → produces HeartRate
    2. BPMeasurement     → produces BloodPressure
    3. VO2MaxMeasurement → produces VO2Max
    4. Products          → produces ProductsOutput
    5. FinalAssessment   → produces AssessmentResult

  ConsentRefusal (the refuse branch) requires branching composition
  and is deferred to the nesting work.
-/
import WorldModel.KB.Arrow.Arrow
import WorldModel.KB.Arrow.SheetDiagram
import WorldModel.KB.Boxes           -- Patient, HeartRate, BloodPressure, VO2Max, etc.
import WorldModel.KB.Relations       -- LegalMeasurementMeeting
import WorldModel.KB.Facts           -- joseMeetingAllen

-- ── Initial context ─────────────────────────────────────────────────────────────

/-- The starting context for Jose's clinical encounter:
    a patient and proof that the meeting is legally valid. -/
abbrev joseCtx : Ctx :=
  [Patient "Jose", LegalMeasurementMeeting "Jose"]

-- ── Stage 0: Consent arrow ────────────────────────────────────────────────────

abbrev consentInputs : Ctx := [Patient "Jose"]
abbrev consentProduces : Ctx := [ConsentingOutput "Jose"]

def consentArrow : Arrow joseCtx (joseCtx ++ consentProduces) :=
  .step
    { inputs := Tel.ofList consentInputs, consumes := [], produces := consentProduces }
    joseCtx
    (.bind (Patient.mk "Jose") .here .nil)

-- ── Stage 1: Heart measurement arrow ─────────────────────────────────────────

abbrev afterConsent : Ctx := joseCtx ++ [ConsentingOutput "Jose"]

def heartMeasurementSpec : Spec where
  inputs   := Tel.ofList [Patient "Jose", LegalMeasurementMeeting "Jose"]
  consumes := []
  produces := [HeartRate "Jose"]

/-- Prove the heart measurement's inputs exist in `afterConsent`. -/
def heartSatisfy : Satisfy heartMeasurementSpec.inputs afterConsent afterConsent :=
  .bind (Patient.mk "Jose") .here
    (.bind joseMeetingAllen (.there .here)
      .nil)

/-- Heart measurement: consumes nothing, produces a `HeartRate`. -/
def heartArrow : Arrow afterConsent (afterConsent ++ [HeartRate "Jose"]) :=
  .step heartMeasurementSpec afterConsent heartSatisfy

-- ── Stage 2: Blood pressure measurement arrow ───────────────────────────────

abbrev afterHeart : Ctx := afterConsent ++ [HeartRate "Jose"]

def bpMeasurementSpec : Spec where
  inputs   := Tel.ofList [Patient "Jose", LegalMeasurementMeeting "Jose"]
  consumes := []
  produces := [BloodPressure "Jose"]

/-- Patient and meeting are still in context after the heart measurement
    (frame rule — they were not consumed). -/
def bpSatisfy : Satisfy bpMeasurementSpec.inputs afterHeart afterHeart :=
  .bind (Patient.mk "Jose") .here
    (.bind joseMeetingAllen (.there .here)
      .nil)

def bpArrow : Arrow afterHeart (afterHeart ++ [BloodPressure "Jose"]) :=
  .step bpMeasurementSpec afterHeart bpSatisfy

-- ── Stage 3: VO2 max measurement arrow ───────────────────────────────────────

abbrev afterBP : Ctx := afterHeart ++ [BloodPressure "Jose"]

def vo2MeasurementSpec : Spec where
  inputs   := Tel.ofList [Patient "Jose", LegalMeasurementMeeting "Jose"]
  consumes := []
  produces := [VO2Max "Jose"]

def vo2Satisfy : Satisfy vo2MeasurementSpec.inputs afterBP afterBP :=
  .bind (Patient.mk "Jose") .here
    (.bind joseMeetingAllen (.there .here)
      .nil)

def vo2Arrow : Arrow afterBP (afterBP ++ [VO2Max "Jose"]) :=
  .step vo2MeasurementSpec afterBP vo2Satisfy

-- ── Stage 4: Products arrow ──────────────────────────────────────────────────

abbrev afterVO2 : Ctx := afterBP ++ [VO2Max "Jose"]
-- afterVO2 = [Patient "Jose", LegalMeasurementMeeting "Jose",
--             ConsentingOutput "Jose", HeartRate "Jose",
--             BloodPressure "Jose", VO2Max "Jose"]

def productsMeasurementSpec : Spec where
  inputs   := Tel.ofList [ConsentingOutput "Jose", HeartRate "Jose",
                           BloodPressure "Jose", VO2Max "Jose"]
  consumes := []
  produces := [ProductsOutput "Jose"]

/-- Products needs 4 types from the context.  Each `Elem` proof uses
    `.there` chains to find the right position in `afterVO2`. -/
def productsSatisfy : Satisfy productsMeasurementSpec.inputs afterVO2 afterVO2 :=
  .bind (ConsentingOutput.consent (Patient.mk "Jose") "signed")
        (.there (.there .here))                           -- index 2: ConsentingOutput
    (.bind (HeartRate.heartRate (Patient.mk "Jose") 72)
           (.there (.there (.there .here)))               -- index 3: HeartRate
      (.bind (BloodPressure.bloodPressure (Patient.mk "Jose") 120)
             (.there (.there (.there (.there .here))))    -- index 4: BloodPressure
        (.bind (VO2Max.vO2Max (Patient.mk "Jose") 45)
               (.there (.there (.there (.there (.there .here)))))  -- index 5: VO2Max
          .nil)))

def productsArrow : Arrow afterVO2 (afterVO2 ++ [ProductsOutput "Jose"]) :=
  .step productsMeasurementSpec afterVO2 productsSatisfy

-- ── Stage 5: Final assessment arrow ──────────────────────────────────────────

abbrev afterProducts : Ctx := afterVO2 ++ [ProductsOutput "Jose"]
-- afterProducts = [Patient "Jose", LegalMeasurementMeeting "Jose",
--                  ConsentingOutput "Jose", HeartRate "Jose",
--                  BloodPressure "Jose", VO2Max "Jose",
--                  ProductsOutput "Jose"]

def assessmentSpec : Spec where
  inputs   := Tel.ofList [Patient "Jose", ProductsOutput "Jose"]
  consumes := []
  produces := [AssessmentResult "Jose"]

def assessmentSatisfy : Satisfy assessmentSpec.inputs afterProducts afterProducts :=
  .bind (Patient.mk "Jose") .here                         -- index 0: Patient
    (.bind (ProductsOutput.products "signed" 72 120 45)
           (.there (.there (.there (.there (.there (.there .here))))))  -- index 6: ProductsOutput
      .nil)

def assessmentArrow : Arrow afterProducts (afterProducts ++ [AssessmentResult "Jose"]) :=
  .step assessmentSpec afterProducts assessmentSatisfy

-- ── Composed clinical pipeline ──────────────────────────────────────────────

/-- The full happy-path clinical pipeline: consent + three measurements +
    products aggregation + final assessment.

    Input:  [Patient "Jose", LegalMeasurementMeeting "Jose"]
    Output: [Patient "Jose", LegalMeasurementMeeting "Jose",
             ConsentingOutput "Jose", HeartRate "Jose",
             BloodPressure "Jose", VO2Max "Jose",
             ProductsOutput "Jose", AssessmentResult "Jose"]

    Note: ConsentRefusal (the refuse branch from the original pipeline)
    requires branching composition and is deferred to the nesting work. -/
def clinicalPipeline : Arrow joseCtx
    (joseCtx ++ [ConsentingOutput "Jose", HeartRate "Jose",
                  BloodPressure "Jose", VO2Max "Jose",
                  ProductsOutput "Jose", AssessmentResult "Jose"]) :=
  consentArrow ⟫ heartArrow ⟫ bpArrow ⟫ vo2Arrow ⟫ productsArrow ⟫ assessmentArrow

-- ── mkArrow helper demonstration ────────────────────────────────────────────

/-- Same heart arrow built with the `mkArrow` helper (using afterConsent context). -/
def heartArrow' : Arrow afterConsent (afterConsent ++ [HeartRate "Jose"]) :=
  mkArrow
    [Patient "Jose", LegalMeasurementMeeting "Jose"]
    [HeartRate "Jose"]
    (.bind (Patient.mk "Jose") .here
      (.bind joseMeetingAllen (.there .here)
        .nil))

-- ══════════════════════════════════════════════════════════════════════════════
-- Consent branching via SheetDiagram
-- ══════════════════════════════════════════════════════════════════════════════

-- ── Branch-specific consent types ──────────────────────────────────────────

/-- Consent was obtained — carries the patient and the consent note. -/
inductive ConsentGiven (name : String) : Type where
  | mk : Patient name → String → ConsentGiven name

/-- Consent was refused — carries the patient and the refusal reason. -/
inductive ConsentRefused (name : String) : Type where
  | mk : Patient name → String → ConsentRefused name

-- ── Consent branch arrows ──────────────────────────────────────────────────

/-- Arrow for the consent-given branch: Patient + Meeting → ConsentGiven. -/
def consentGivenArrow : Arrow joseCtx (joseCtx ++ [ConsentGiven "Jose"]) :=
  .step
    { inputs := Tel.ofList [Patient "Jose"]
      consumes := []
      produces := [ConsentGiven "Jose"] }
    joseCtx
    (.bind (Patient.mk "Jose") .here .nil)

/-- Arrow for the consent-refused branch: Patient → ConsentRefused.
    Input context is just [Patient "Jose"] (no meeting needed for refusal). -/
def refusalArrow : Arrow [Patient "Jose"] ([Patient "Jose"] ++ [ConsentRefused "Jose"]) :=
  .step
    { inputs := Tel.ofList [Patient "Jose"]
      consumes := []
      produces := [ConsentRefused "Jose"] }
    [Patient "Jose"]
    (.bind (Patient.mk "Jose") .here .nil)

-- ── Happy-path arrows (re-indexed for post-ConsentGiven context) ───────────

abbrev afterConsentGiven : Ctx := joseCtx ++ [ConsentGiven "Jose"]

def heartArrowCG : Arrow afterConsentGiven (afterConsentGiven ++ [HeartRate "Jose"]) :=
  .step
    { inputs := Tel.ofList [Patient "Jose", LegalMeasurementMeeting "Jose"]
      consumes := []
      produces := [HeartRate "Jose"] }
    afterConsentGiven
    (.bind (Patient.mk "Jose") .here
      (.bind joseMeetingAllen (.there .here) .nil))

abbrev afterHeartCG : Ctx := afterConsentGiven ++ [HeartRate "Jose"]

def bpArrowCG : Arrow afterHeartCG (afterHeartCG ++ [BloodPressure "Jose"]) :=
  .step
    { inputs := Tel.ofList [Patient "Jose", LegalMeasurementMeeting "Jose"]
      consumes := []
      produces := [BloodPressure "Jose"] }
    afterHeartCG
    (.bind (Patient.mk "Jose") .here
      (.bind joseMeetingAllen (.there .here) .nil))

abbrev afterBPCG : Ctx := afterHeartCG ++ [BloodPressure "Jose"]

def vo2ArrowCG : Arrow afterBPCG (afterBPCG ++ [VO2Max "Jose"]) :=
  .step
    { inputs := Tel.ofList [Patient "Jose", LegalMeasurementMeeting "Jose"]
      consumes := []
      produces := [VO2Max "Jose"] }
    afterBPCG
    (.bind (Patient.mk "Jose") .here
      (.bind joseMeetingAllen (.there .here) .nil))

abbrev afterVO2CG : Ctx := afterBPCG ++ [VO2Max "Jose"]

def productsArrowCG : Arrow afterVO2CG (afterVO2CG ++ [ProductsOutput "Jose"]) :=
  .step
    { inputs := Tel.ofList [ConsentGiven "Jose", HeartRate "Jose",
                             BloodPressure "Jose", VO2Max "Jose"]
      consumes := []
      produces := [ProductsOutput "Jose"] }
    afterVO2CG
    (.bind (ConsentGiven.mk (Patient.mk "Jose") "signed")
           (.there (.there .here))
      (.bind (HeartRate.heartRate (Patient.mk "Jose") 72)
             (.there (.there (.there .here)))
        (.bind (BloodPressure.bloodPressure (Patient.mk "Jose") 120)
               (.there (.there (.there (.there .here))))
          (.bind (VO2Max.vO2Max (Patient.mk "Jose") 45)
                 (.there (.there (.there (.there (.there .here)))))
            .nil))))

abbrev afterProductsCG : Ctx := afterVO2CG ++ [ProductsOutput "Jose"]

def assessmentArrowCG : Arrow afterProductsCG (afterProductsCG ++ [AssessmentResult "Jose"]) :=
  .step
    { inputs := Tel.ofList [Patient "Jose", ProductsOutput "Jose"]
      consumes := []
      produces := [AssessmentResult "Jose"] }
    afterProductsCG
    (.bind (Patient.mk "Jose") .here
      (.bind (ProductsOutput.products "signed" 72 120 45)
             (.there (.there (.there (.there (.there (.there .here))))))
        .nil))

-- ── The full happy-path sub-pipeline as a SheetDiagram ─────────────────────

def happyPathSheet : SheetDiagram joseCtx [afterProductsCG ++ [AssessmentResult "Jose"]] :=
  .pipe consentGivenArrow
    (.pipe heartArrowCG
      (.pipe bpArrowCG
        (.pipe vo2ArrowCG
          (.pipe productsArrowCG
            (.arrow assessmentArrowCG)))))

-- ── The refusal sub-pipeline as a SheetDiagram ─────────────────────────────

/-- Refusal branch: run the refusal arrow then halt.
    The arrow records the refusal; `halt` terminates the sheet so it
    contributes no outcomes to the coproduct (like `Bottom` in Boxes). -/
def refusalSheet : SheetDiagram [Patient "Jose"] [] :=
  .pipe refusalArrow .halt

-- ── Consent branching: the full SheetDiagram with two outcomes ─────────────

/-- The consent-branching clinical pipeline.

    Input:  [Patient "Jose", LegalMeasurementMeeting "Jose"]
    Output: [ ...full measurement pipeline..., AssessmentResult "Jose" ]

    The refusal branch is processed (the refusal arrow runs) but halted —
    it contributes no outcomes to the output coproduct.  This mirrors the
    `Bottom`-terminated `ConsentRefusal` from the Boxes system.

    The `Split.idLeft` sends everything to `Γ_branch` with `Γ_par = []`.
    Each `Selection` picks the elements needed for that branch. -/
def consentBranching : SheetDiagram joseCtx
    [afterProductsCG ++ [AssessmentResult "Jose"]] :=
  .branch
    (Split.idLeft joseCtx)                          -- everything to Γ_branch, Γ_par = []
    (Selection.id joseCtx)                           -- consent branch: Patient + Meeting
    (.cons .here .nil)                               -- refusal branch: Patient only
    happyPathSheet                                   -- left: full measurement pipeline
    refusalSheet                                     -- right: consent refused → halt
