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
