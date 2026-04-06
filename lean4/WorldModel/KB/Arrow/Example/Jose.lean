/-
  WorldModel.KB.Arrow.Example.Jose
  Full clinical pipeline with measurement branching and scoped constraints.

  Six stages: consent → heart → BP → VO2 → products → assessment
  Four branch points (consent, heart, BP, VO2), three `.join`s.
  Three nested scopes: trial → clinic → room.
-/
import WorldModel.KB.Arrow.Erase

open KB.Facts

namespace JoseExample

/-- Concrete evidence that Allen and Jose share Spanish. -/
def allenJoseLangEvidence : SharedLangEvidence "Allen" "Jose" :=
  { lang := "Spanish"
    cSpeaks := allen_speaks_spanish
    pSpeaks := jose_speaks_spanish }

/-- Concrete evidence that ValClinic is in Valencia where Jose lives. -/
def valClinicJoseCityEvidence : ClinicCityEvidence "ValClinic" "Jose" :=
  { city := "Valencia"
    cIsIn := valClinic_in_valencia
    pLives := jose_lives_valencia }

-- ── Initial context ─────────────────────────────────────────────────────────

/-- Starting context: just the patient. -/
abbrev joseCtx : Ctx := [Patient "Jose"]

/-- Starting scope state: patient is the initial resource. -/
abbrev initState : ScopeState := [.entry ⟨"Jose", .patient⟩]

-- ── Scope items ───────────────────────────────────────────────────────────

/-- Trial scope: introduces the trial and declares that clinicians must speak
    the patient's language. -/
abbrev trialItems : List ScopeItem :=
  [.entry ⟨"OurTrial", .trial⟩,
   .constraint .clinicianSpeaksPatient]

/-- Clinic scope: introduces clinic + clinician, declares clinic-level constraints. -/
abbrev clinicItems : List ScopeItem :=
  [.entry ⟨"ValClinic", .clinic⟩,
   .entry ⟨"Allen", .clinician⟩,
   .constraint .clinicInPatientCity,
   .constraint .clinicianAssigned,
   .constraint .trialApprovesClinic]

/-- Room scope: introduces room + technician role assignments + equipment constraints. -/
abbrev roomItems : List ScopeItem :=
  [.entry ⟨"Room3", .room⟩,
   .entry ⟨"Allen", .examBedTech⟩,
   .entry ⟨"Allen", .bpTech⟩,
   .entry ⟨"Allen", .vo2Tech⟩,
   .constraint .examBedQual,
   .constraint .bpQual,
   .constraint .vo2Qual]

-- ── Scope extensions (Ctx) ────────────────────────────────────────────────

/-- Trial scope: just the trial object. -/
abbrev trialExt : Ctx := [ClinicalTrial "OurTrial"]

/-- Clinic scope: clinic + clinician + shared language evidence. -/
abbrev clinicExt : Ctx := [Clinic "ValClinic", Clinician "Allen",
                            SharedLangEvidence "Allen" "Jose"]

/-- Room scope: room marker + equipment + clinician qualifications. -/
abbrev roomExt : Ctx := [Room "Room3", ExamBed, BPMonitor, VO2Equipment,
                          holdsExamBedQual allen .mk, holdsBPMonitorQual allen .mk,
                          holdsVO2EquipmentQual allen .mk]

-- ── Full inner context ──────────────────────────────────────────────────────

/-- The full context inside all three nested scopes.
    Index  Type
    0      Room "Room3"
    1      ExamBed
    2      BPMonitor
    3      VO2Equipment
    4      holdsExamBedQual allen .mk
    5      holdsBPMonitorQual allen .mk
    6      holdsVO2EquipmentQual allen .mk
    7      Clinic "ValClinic"
    8      Clinician "Allen"
    9      SharedLangEvidence "Allen" "Jose"
    10     ClinicalTrial "OurTrial"
    11     Patient "Jose" -/
abbrev insideAllScopes : Ctx :=
  roomExt ++ (clinicExt ++ (trialExt ++ joseCtx))

-- ── Full scope state inside all three scopes ────────────────────────────────

abbrev roomState : ScopeState :=
  roomItems ++ (clinicItems ++ (trialItems ++ initState))

-- ── Failure selection and disqualification arrow ───────────────────────────

/-- Select the 12 scope items from any extended context `insideAllScopes ++ extra`.
    All failure branches use this to drop produced items before disqualifying. -/
def insideAllScopesSel {extra : Ctx}
    : Selection (insideAllScopes ++ extra) insideAllScopes :=
  Selection.prefix insideAllScopes extra

/-- Shared disqualification arrow: finds Patient at index 11, produces NonQualifying. -/
def nqArrow : Arrow insideAllScopes (insideAllScopes ++ [NonQualifying "Jose"]) :=
  .step
    { name := "disqualify"
      description := "Records patient disqualification with a reason"
      inputs := Tel.ofList [Patient "Jose"]
      consumes := []
      produces := [NonQualifying "Jose"] }
    insideAllScopes
    (.bind (Patient.mk "Jose") (by elem_tac)
      .nil)

-- ── Stage 0: Consent ────────────────────────────────────────────────────────

def consentArrow : Arrow insideAllScopes (insideAllScopes ++ [ConsentGiven "Jose"]) :=
  .step
    { name := "consent"
      description := "Obtains informed consent from the patient"
      inputs := Tel.ofList [Patient "Jose", SharedLangEvidence "Allen" "Jose"]
      consumes := []
      produces := [ConsentGiven "Jose"] }
    insideAllScopes
    (.bind (Patient.mk "Jose") (by elem_tac)
      (.bind allenJoseLangEvidence (by elem_tac)
        .nil))

-- ── Stage 1: Heart measurement ──────────────────────────────────────────────

abbrev afterConsent : Ctx := insideAllScopes ++ [ConsentGiven "Jose"]

def heartArrow : Arrow afterConsent (afterConsent ++ [HeartRate "Jose"]) :=
  .step
    { name := "heartMeasurement"
      description := "Measures the patient's heart rate using an exam bed"
      inputs := Tel.ofList [Patient "Jose", Clinician "Allen", ExamBed,
                            holdsExamBedQual allen .mk, SharedLangEvidence "Allen" "Jose"]
      consumes := []
      produces := [HeartRate "Jose"] }
    afterConsent
    (.bind (Patient.mk "Jose") (by elem_tac)
      (.bind (Clinician.mk "Allen") (by elem_tac)
        (.bind ExamBed.mk (by elem_tac)
          (.bind holdsExamBedQual.mk (by elem_tac)
            (.bind allenJoseLangEvidence (by elem_tac)
              .nil)))))

-- ── Stage 2: Blood pressure measurement ─────────────────────────────────────

abbrev afterHeart : Ctx := afterConsent ++ [HeartRate "Jose"]

def bpArrow : Arrow afterHeart (afterHeart ++ [BloodPressure "Jose"]) :=
  .step
    { name := "bpMeasurement"
      description := "Measures the patient's blood pressure using a BP monitor"
      inputs := Tel.ofList [Patient "Jose", Clinician "Allen", BPMonitor,
                            holdsBPMonitorQual allen .mk, SharedLangEvidence "Allen" "Jose"]
      consumes := []
      produces := [BloodPressure "Jose"] }
    afterHeart
    (.bind (Patient.mk "Jose") (by elem_tac)
      (.bind (Clinician.mk "Allen") (by elem_tac)
        (.bind BPMonitor.mk (by elem_tac)
          (.bind holdsBPMonitorQual.mk (by elem_tac)
            (.bind allenJoseLangEvidence (by elem_tac)
              .nil)))))

-- ── Stage 3: VO2 max measurement ────────────────────────────────────────────

abbrev afterBP : Ctx := afterHeart ++ [BloodPressure "Jose"]

def vo2Arrow : Arrow afterBP (afterBP ++ [VO2Max "Jose"]) :=
  .step
    { name := "vo2Measurement"
      description := "Measures the patient's VO2 max using VO2 equipment"
      inputs := Tel.ofList [Patient "Jose", Clinician "Allen", VO2Equipment,
                            holdsVO2EquipmentQual allen .mk, SharedLangEvidence "Allen" "Jose"]
      consumes := []
      produces := [VO2Max "Jose"] }
    afterBP
    (.bind (Patient.mk "Jose") (by elem_tac)
      (.bind (Clinician.mk "Allen") (by elem_tac)
        (.bind VO2Equipment.mk (by elem_tac)
          (.bind holdsVO2EquipmentQual.mk (by elem_tac)
            (.bind allenJoseLangEvidence (by elem_tac)
              .nil)))))

-- ── Stage 4: Products ───────────────────────────────────────────────────────

abbrev afterVO2 : Ctx := afterBP ++ [VO2Max "Jose"]

def productsArrow : Arrow afterVO2 (afterVO2 ++ [ProductsOutput "Jose"]) :=
  .step
    { name := "products"
      description := "Aggregates all measurement results into a single output"
      inputs := Tel.ofList [ConsentGiven "Jose", HeartRate "Jose",
                            BloodPressure "Jose", VO2Max "Jose"]
      consumes := []
      produces := [ProductsOutput "Jose"] }
    afterVO2
    (.bind (ConsentGiven.mk (Patient.mk "Jose") "signed") (by elem_tac)
      (.bind (HeartRate.heartRate (Patient.mk "Jose") 72) (by elem_tac)
        (.bind (BloodPressure.bloodPressure (Patient.mk "Jose") 120) (by elem_tac)
          (.bind (VO2Max.vO2Max (Patient.mk "Jose") 45) (by elem_tac)
            .nil))))

-- ── Stage 5: Final assessment ───────────────────────────────────────────────

abbrev afterProducts : Ctx := afterVO2 ++ [ProductsOutput "Jose"]

def assessmentArrow : Arrow afterProducts (afterProducts ++ [AssessmentResult "Jose"]) :=
  .step
    { name := "assessment"
      description := "Evaluates aggregated results to determine if patient qualifies"
      inputs := Tel.ofList [Patient "Jose", ProductsOutput "Jose"]
      consumes := []
      produces := [AssessmentResult "Jose"] }
    afterProducts
    (.bind (Patient.mk "Jose") (by elem_tac)
      (.bind (ProductsOutput.products "signed" 72 120 45) (by elem_tac)
        .nil))

-- ── Explicit obligation types per scope ────────────────────────────────────
-- newObligations can't reduce at type-checking time (filterMap/BEq chains),
-- so we spell out the obligation lists that the kernel must see.

/-- Trial scope: clinicianSpeaksPatient fires but no clinician in scope yet → empty. -/
abbrev trialObligations : List Type := []

/-- Clinic scope: new constraints (clinicInPatientCity, clinicianAssigned, trialApprovesClinic)
    fire against all entries; existing constraint (clinicianSpeaksPatient from trial)
    fires against new entries (Allen as clinician). -/
abbrev clinicObligations : List Type :=
  [ClinicCityEvidence "ValClinic" "Jose",
   assigned (Human.mk "Allen") (Clinic.mk "ValClinic"),
   trialApproves (ClinicalTrial.mk "OurTrial") (Clinic.mk "ValClinic"),
   SharedLangEvidence "Allen" "Jose"]

/-- Room scope: new constraints (examBedQual, bpQual, vo2Qual) fire against
    new entries (Allen as examBedTech/bpTech/vo2Tech). -/
abbrev roomObligations : List Type :=
  [holdsExamBedQual (Human.mk "Allen") .mk,
   holdsBPMonitorQual (Human.mk "Allen") .mk,
   holdsVO2EquipmentQual (Human.mk "Allen") .mk]

/-- The full clinical pipeline with measurement branching and scoped constraints.

    Scope constraints fire at each scope entry:
      - Trial: no obligations (clinicianSpeaksPatient declared but no clinician yet)
      - Clinic: ClinicCityEvidence, SharedLangEvidence, assigned, trialApproves
      - Room: holdsExamBedQual, holdsBPMonitorQual, holdsVO2EquipmentQual

    Four branch points (consent, heart, BP, VO2), three `.join`s. -/
def scopedClinicalPipeline : SheetDiagram initState joseCtx initState
    [[Patient "Jose", NonQualifying "Jose"],
     joseCtx ++ [ConsentGiven "Jose", HeartRate "Jose",
                  BloodPressure "Jose", VO2Max "Jose",
                  ProductsOutput "Jose", AssessmentResult "Jose"]] :=
  .scope "trial" trialItems trialExt trialExt initState
    trialObligations
    PUnit.unit
    (.scope "clinic" clinicItems clinicExt clinicExt (trialItems ++ initState)
      clinicObligations
      (valClinicJoseCityEvidence, allen_assigned_val, trial_approves_val, allenJoseLangEvidence)
      (.scope "room" roomItems roomExt roomExt (clinicItems ++ (trialItems ++ initState))
        roomObligations
        (allen_holds_exambed, allen_holds_bpmonitor, allen_holds_vo2equip)
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

def erasedPipeline : Erased.Pipeline := Erased.erase scopedClinicalPipeline
#eval toString erasedPipeline

end JoseExample
