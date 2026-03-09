/-
  WorldModel.KB.Arrow.Clinical
  Full clinical pipeline using scope-derived constraints.

  Instead of a monolithic `LegalMeasurementMeeting`, constraints emerge from
  nested scopes:
    - Trial scope  → provides ClinicalTrial
    - Clinic scope → provides Clinic, Clinician, SharedLangEvidence
    - Room scope   → provides Room, Equipment, Equipment Qualifications

  Each measurement step declares exactly what it needs (equipment, qualification,
  shared language). Missing constraints = type error.
-/
import WorldModel.KB.Arrow.Arrow
import WorldModel.KB.Arrow.SheetDiagram
import WorldModel.KB.Boxes           -- Patient, HeartRate, BloodPressure, VO2Max, etc.
import WorldModel.KB.Facts           -- speaks facts for SharedLangEvidence

-- ── Evidence types ──────────────────────────────────────────────────────────

/-- Proof that a clinician and patient share a language.
    Included in scope extensions so inner steps can find it via Satisfy/Elem. -/
structure SharedLangEvidence (cn pn : String) : Type where
  lang : String
  cSpeaks : speaks (Human.mk cn) (Language.mk lang)
  pSpeaks : speaks (Human.mk pn) (Language.mk lang)

/-- Concrete evidence that Allen and Jose share Spanish. -/
def allenJoseLangEvidence : SharedLangEvidence "Allen" "Jose" :=
  { lang := "Spanish"
    cSpeaks := allen_speaks_spanish
    pSpeaks := jose_speaks_spanish }

-- ── Consent and disqualification types ─────────────────────────────────────

/-- Consent was obtained — carries the patient and the consent note. -/
inductive ConsentGiven (name : String) : Type where
  | mk : Patient name → String → ConsentGiven name

/-- Reasons a patient can be disqualified at any measurement step. -/
inductive DisqualificationReason : Type where
  | consentRefused : String → DisqualificationReason
  | heartRateTooFast
  | bloodPressureTooHigh
  | vo2MaxTooLow

/-- Patient disqualified — carries the patient and the reason. -/
inductive NonQualifying (name : String) : Type where
  | mk : Patient name → DisqualificationReason → NonQualifying name

-- ── Initial context ─────────────────────────────────────────────────────────

/-- Starting context: just the patient. -/
abbrev joseCtx : Ctx := [Patient "Jose"]

-- ── Scope extensions ────────────────────────────────────────────────────────

/-- Trial scope: just the trial object. -/
abbrev trialExt : Ctx := [ClinicalTrial "OurTrial"]

/-- Clinic scope: clinic + clinician + shared language evidence. -/
abbrev clinicExt : Ctx := [Clinic "ValClinic", Clinician "Allen",
                            SharedLangEvidence "Allen" "Jose"]

/-- Room scope: room marker + equipment + clinician qualifications. -/
abbrev roomExt : Ctx := [Room "Room3", ExamBed, BPMonitor, VO2Equipment,
                          ExamBedQual "Allen", BPMonitorQual "Allen",
                          VO2EquipmentQual "Allen"]

-- ── Full inner context ──────────────────────────────────────────────────────

/-- The full context inside all three nested scopes.
    Index  Type
    0      Room "Room3"
    1      ExamBed
    2      BPMonitor
    3      VO2Equipment
    4      ExamBedQual "Allen"
    5      BPMonitorQual "Allen"
    6      VO2EquipmentQual "Allen"
    7      Clinic "ValClinic"
    8      Clinician "Allen"
    9      SharedLangEvidence "Allen" "Jose"
    10     ClinicalTrial "OurTrial"
    11     Patient "Jose" -/
abbrev insideAllScopes : Ctx :=
  roomExt ++ (clinicExt ++ (trialExt ++ joseCtx))

-- ── Failure selection and disqualification arrow ───────────────────────────

/-- Select the 12 scope items from any extended context `insideAllScopes ++ extra`.
    All failure branches use this to drop produced items before disqualifying. -/
def insideAllScopesSel {extra : Ctx}
    : Selection (insideAllScopes ++ extra) insideAllScopes :=
  Selection.prefix insideAllScopes extra

/-- Shared disqualification arrow: finds Patient at index 11, produces NonQualifying. -/
def nqArrow : Arrow insideAllScopes (insideAllScopes ++ [NonQualifying "Jose"]) :=
  .step
    { inputs := Tel.ofList [Patient "Jose"]
      consumes := []
      produces := [NonQualifying "Jose"] }
    insideAllScopes
    (.bind (Patient.mk "Jose")
           (.there (.there (.there (.there (.there (.there (.there (.there (.there (.there (.there .here)))))))))))
      .nil)

-- ── Stage 0: Consent ────────────────────────────────────────────────────────

def consentArrow : Arrow insideAllScopes (insideAllScopes ++ [ConsentGiven "Jose"]) :=
  .step
    { inputs := Tel.ofList [Patient "Jose", SharedLangEvidence "Allen" "Jose"]
      consumes := []
      produces := [ConsentGiven "Jose"] }
    insideAllScopes
    (.bind (Patient.mk "Jose")
           (.there (.there (.there (.there (.there (.there (.there (.there (.there (.there (.there .here)))))))))))
      (.bind allenJoseLangEvidence
             (.there (.there (.there (.there (.there (.there (.there (.there (.there .here)))))))))
        .nil))

-- ── Stage 1: Heart measurement ──────────────────────────────────────────────

abbrev afterConsent : Ctx := insideAllScopes ++ [ConsentGiven "Jose"]

def heartArrow : Arrow afterConsent (afterConsent ++ [HeartRate "Jose"]) :=
  .step
    { inputs := Tel.ofList [Patient "Jose", Clinician "Allen", ExamBed,
                            ExamBedQual "Allen", SharedLangEvidence "Allen" "Jose"]
      consumes := []
      produces := [HeartRate "Jose"] }
    afterConsent
    (.bind (Patient.mk "Jose")
           (.there (.there (.there (.there (.there (.there (.there (.there (.there (.there (.there .here)))))))))))
      (.bind (Clinician.mk "Allen")
             (.there (.there (.there (.there (.there (.there (.there (.there .here))))))))
        (.bind ExamBed.mk
               (.there .here)
          (.bind (ExamBedQual.mk "Allen")
                 (.there (.there (.there (.there .here))))
            (.bind allenJoseLangEvidence
                   (.there (.there (.there (.there (.there (.there (.there (.there (.there .here)))))))))
              .nil)))))

-- ── Stage 2: Blood pressure measurement ─────────────────────────────────────

abbrev afterHeart : Ctx := afterConsent ++ [HeartRate "Jose"]

def bpArrow : Arrow afterHeart (afterHeart ++ [BloodPressure "Jose"]) :=
  .step
    { inputs := Tel.ofList [Patient "Jose", Clinician "Allen", BPMonitor,
                            BPMonitorQual "Allen", SharedLangEvidence "Allen" "Jose"]
      consumes := []
      produces := [BloodPressure "Jose"] }
    afterHeart
    (.bind (Patient.mk "Jose")
           (.there (.there (.there (.there (.there (.there (.there (.there (.there (.there (.there .here)))))))))))
      (.bind (Clinician.mk "Allen")
             (.there (.there (.there (.there (.there (.there (.there (.there .here))))))))
        (.bind BPMonitor.mk
               (.there (.there .here))
          (.bind (BPMonitorQual.mk "Allen")
                 (.there (.there (.there (.there (.there .here)))))
            (.bind allenJoseLangEvidence
                   (.there (.there (.there (.there (.there (.there (.there (.there (.there .here)))))))))
              .nil)))))

-- ── Stage 3: VO2 max measurement ────────────────────────────────────────────

abbrev afterBP : Ctx := afterHeart ++ [BloodPressure "Jose"]

def vo2Arrow : Arrow afterBP (afterBP ++ [VO2Max "Jose"]) :=
  .step
    { inputs := Tel.ofList [Patient "Jose", Clinician "Allen", VO2Equipment,
                            VO2EquipmentQual "Allen", SharedLangEvidence "Allen" "Jose"]
      consumes := []
      produces := [VO2Max "Jose"] }
    afterBP
    (.bind (Patient.mk "Jose")
           (.there (.there (.there (.there (.there (.there (.there (.there (.there (.there (.there .here)))))))))))
      (.bind (Clinician.mk "Allen")
             (.there (.there (.there (.there (.there (.there (.there (.there .here))))))))
        (.bind VO2Equipment.mk
               (.there (.there (.there .here)))
          (.bind (VO2EquipmentQual.mk "Allen")
                 (.there (.there (.there (.there (.there (.there .here))))))
            (.bind allenJoseLangEvidence
                   (.there (.there (.there (.there (.there (.there (.there (.there (.there .here)))))))))
              .nil)))))

-- ── Stage 4: Products ───────────────────────────────────────────────────────

abbrev afterVO2 : Ctx := afterBP ++ [VO2Max "Jose"]

def productsArrow : Arrow afterVO2 (afterVO2 ++ [ProductsOutput "Jose"]) :=
  .step
    { inputs := Tel.ofList [ConsentGiven "Jose", HeartRate "Jose",
                            BloodPressure "Jose", VO2Max "Jose"]
      consumes := []
      produces := [ProductsOutput "Jose"] }
    afterVO2
    (.bind (ConsentGiven.mk (Patient.mk "Jose") "signed")
           (.there (.there (.there (.there (.there (.there (.there (.there (.there (.there (.there (.there .here))))))))))))
      (.bind (HeartRate.heartRate (Patient.mk "Jose") 72)
             (.there (.there (.there (.there (.there (.there (.there (.there (.there (.there (.there (.there (.there .here)))))))))))))
        (.bind (BloodPressure.bloodPressure (Patient.mk "Jose") 120)
               (.there (.there (.there (.there (.there (.there (.there (.there (.there (.there (.there (.there (.there (.there .here))))))))))))))
          (.bind (VO2Max.vO2Max (Patient.mk "Jose") 45)
                 (.there (.there (.there (.there (.there (.there (.there (.there (.there (.there (.there (.there (.there (.there (.there .here)))))))))))))))
            .nil))))

-- ── Stage 5: Final assessment ───────────────────────────────────────────────

abbrev afterProducts : Ctx := afterVO2 ++ [ProductsOutput "Jose"]

def assessmentArrow : Arrow afterProducts (afterProducts ++ [AssessmentResult "Jose"]) :=
  .step
    { inputs := Tel.ofList [Patient "Jose", ProductsOutput "Jose"]
      consumes := []
      produces := [AssessmentResult "Jose"] }
    afterProducts
    (.bind (Patient.mk "Jose")
           (.there (.there (.there (.there (.there (.there (.there (.there (.there (.there (.there .here)))))))))))
      (.bind (ProductsOutput.products "signed" 72 120 45)
             (.there (.there (.there (.there (.there (.there (.there (.there (.there (.there (.there (.there (.there (.there (.there (.there .here))))))))))))))))
        .nil))

-- ── Scoped clinical pipeline ────────────────────────────────────────────────

/-- The full clinical pipeline with measurement branching.

    Each measurement can disqualify the patient (consent refused, heart rate
    too fast, BP too high, VO2 too low).  Failure branches coalesce via `.join`
    into a single `NonQualifying` outcome.

    Start:  [Patient "Jose"]
    Outcomes:
      1. [Patient "Jose", NonQualifying "Jose"]           — disqualified
      2. [Patient "Jose", ConsentGiven "Jose", ...]       — fully qualified

    Four branch points (consent, heart, BP, VO2), three `.join`s. -/
def scopedClinicalPipeline : SheetDiagram joseCtx
    [[Patient "Jose", NonQualifying "Jose"],
     joseCtx ++ [ConsentGiven "Jose", HeartRate "Jose",
                  BloodPressure "Jose", VO2Max "Jose",
                  ProductsOutput "Jose", AssessmentResult "Jose"]] :=
  .scope trialExt
    (.scope clinicExt
      (.scope roomExt
        (.join (.join (.join
          (.branch (Split.idLeft insideAllScopes)
            insideAllScopesSel (Selection.id insideAllScopes)
            (.arrow nqArrow)
            (.pipe consentArrow
              (.pipe heartArrow
                (.branch (Split.idLeft afterHeart)
                  insideAllScopesSel (Selection.id afterHeart)
                  (.arrow nqArrow)
                  (.pipe bpArrow
                    (.branch (Split.idLeft afterBP)
                      insideAllScopesSel (Selection.id afterBP)
                      (.arrow nqArrow)
                      (.pipe vo2Arrow
                        (.branch (Split.idLeft afterVO2)
                          insideAllScopesSel (Selection.id afterVO2)
                          (.arrow nqArrow)
                          (.pipe productsArrow
                            (.arrow assessmentArrow)))))))))))))))
