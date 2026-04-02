/-
  WorldModel.KB.Arrow.Compile
  End-to-end compilation of the JoseTrial SoA into a SheetDiagram.

  Demonstrates the Type 2 → Type 1 compilation step:
    SoA (what happens) + KB facts (who, where, with what) → SheetDiagram (proof term)

  Three visit phases:
    1. Screening (one-shot): consent + assessment with NQ branching (2 branch points)
    2. Drug administration (bounded × 3): `boundedIterate` with callConfirmed
    3. Weekly checkups (unbounded): `unboundedStep` with callConfirmed

  Cross-visit constraints (like "call the patient the day before") are
  backward-looking scope constraints — same mechanism as clinicInPatientCity.
  The SoA says WHAT happens; constraints say WHAT MUST BE TRUE when it happens.
-/
import WorldModel.KB.Arrow.Iterate

open KB.Facts

namespace Compile

-- ══════════════════════════════════════════════════════════════════════════
-- Shared scope infrastructure (reused across all visit phases)
-- ══════════════════════════════════════════════════════════════════════════

-- ── Initial context and state ────────────────────────────────────────────

abbrev joseCtx : Ctx := [Patient "Jose"]
abbrev initState : ScopeState := [.entry ⟨"Jose", .patient⟩]

-- ── Evidence values ──────────────────────────────────────────────────────

def allenJoseLangEvidence : SharedLangEvidence "Allen" "Jose" :=
  { lang := "Spanish"
    cSpeaks := allen_speaks_spanish
    pSpeaks := jose_speaks_spanish }

def valClinicJoseCityEvidence : ClinicCityEvidence "ValClinic" "Jose" :=
  { city := "Valencia"
    cIsIn := valClinic_in_valencia
    pLives := jose_lives_valencia }

-- ── Scope items (same as JoseExample) ────────────────────────────────────

abbrev trialItems : List ScopeItem :=
  [.entry ⟨"OurTrial", .trial⟩,
   .constraint .clinicianSpeaksPatient]

abbrev clinicItems : List ScopeItem :=
  [.entry ⟨"ValClinic", .clinic⟩,
   .entry ⟨"Allen", .clinician⟩,
   .constraint .clinicInPatientCity,
   .constraint .clinicianAssigned,
   .constraint .trialApprovesClinic]

abbrev roomItems : List ScopeItem :=
  [.entry ⟨"Room3", .room⟩,
   .entry ⟨"Allen", .examBedTech⟩,
   .entry ⟨"Allen", .bpTech⟩,
   .entry ⟨"Allen", .vo2Tech⟩,
   .constraint .examBedQual,
   .constraint .bpQual,
   .constraint .vo2Qual]

-- ── Scope extensions (Ctx) ───────────────────────────────────────────────

abbrev trialExt : Ctx := [ClinicalTrial "OurTrial"]
abbrev clinicExt : Ctx := [Clinic "ValClinic", Clinician "Allen",
                            SharedLangEvidence "Allen" "Jose"]
abbrev roomExt : Ctx := [Room "Room3", ExamBed, BPMonitor, VO2Equipment,
                          holdsExamBedQual allen .mk, holdsBPMonitorQual allen .mk,
                          holdsVO2EquipmentQual allen .mk]

-- ── Obligation types per scope ───────────────────────────────────────────

abbrev trialObligations : List Type := []

abbrev clinicObligations : List Type :=
  [ClinicCityEvidence "ValClinic" "Jose",
   assigned (Human.mk "Allen") (Clinic.mk "ValClinic"),
   trialApproves (ClinicalTrial.mk "OurTrial") (Clinic.mk "ValClinic"),
   SharedLangEvidence "Allen" "Jose"]

abbrev roomObligations : List Type :=
  [holdsExamBedQual (Human.mk "Allen") .mk,
   holdsBPMonitorQual (Human.mk "Allen") .mk,
   holdsVO2EquipmentQual (Human.mk "Allen") .mk]

-- ── Full inner context (inside trial + clinic + room scopes) ─────────────

abbrev insideAllScopes : Ctx :=
  roomExt ++ (clinicExt ++ (trialExt ++ joseCtx))

abbrev roomState : ScopeState :=
  roomItems ++ (clinicItems ++ (trialItems ++ initState))

-- ══════════════════════════════════════════════════════════════════════════
-- Visit scope: callConfirmed constraint fires per visit
-- ══════════════════════════════════════════════════════════════════════════

/-- Visit-level scope items: just a callConfirmed constraint.
    This fires against the patient entry already in scope. -/
abbrev visitItems : List ScopeItem :=
  [.constraint .callConfirmed]

/-- The obligations generated when visitItems enter roomState:
    callConfirmed fires against Jose (patient in scope). -/
abbrev visitObligations : List Type :=
  [CallConfirmed "Jose"]

/-- Evidence that a confirmation call was made to Jose.
    At runtime, this would come from an actual phone call event in the KB. -/
def call_confirmed_jose : CallConfirmed "Jose" := .mk "Jose"

/-- Scope state inside a visit scope (visitItems pushed onto roomState). -/
abbrev visitState : ScopeState := visitItems ++ roomState

-- ══════════════════════════════════════════════════════════════════════════
-- Phase 1: Screening visit (one-shot)
-- ══════════════════════════════════════════════════════════════════════════

/-  Screening: branch (consent refusal) → consent → assessment → branch (NQ).
    No visit-level callConfirmed scope — branching happens at room level.
    Drug and checkup phases keep their own callConfirmed scopes. -/

/-- Consent arrow: obtains informed consent. -/
def screeningConsent : Arrow insideAllScopes (insideAllScopes ++ [ConsentGiven "Jose"]) :=
  mkArrow "consent"
    [Patient "Jose", SharedLangEvidence "Allen" "Jose"]
    [ConsentGiven "Jose"]
    (.bind (Patient.mk "Jose") (by elem_tac)
      (.bind allenJoseLangEvidence (by elem_tac)
        .nil))

/-- Assessment arrow: evaluates the patient (after consent). -/
def screeningAssessment : Arrow (insideAllScopes ++ [ConsentGiven "Jose"])
    ((insideAllScopes ++ [ConsentGiven "Jose"]) ++ [AssessmentResult "Jose"]) :=
  mkArrow "assessment"
    [Patient "Jose", ConsentGiven "Jose"]
    [AssessmentResult "Jose"]
    (.bind (Patient.mk "Jose") (by elem_tac)
      (.bind (ConsentGiven.mk (Patient.mk "Jose") "signed") (by elem_tac)
        .nil))

/-- Drop screening results (ConsentGiven + AssessmentResult) to return to insideAllScopes. -/
def dropScreeningResults :
    Split ((insideAllScopes ++ [ConsentGiven "Jose"]) ++ [AssessmentResult "Jose"])
          [ConsentGiven "Jose", AssessmentResult "Jose"] insideAllScopes :=
  Split.append insideAllScopes [ConsentGiven "Jose", AssessmentResult "Jose"]
    |>.comm

-- ── Branching helpers (same pattern as Clinical.lean JoseExample) ────────────

/-- Select the `insideAllScopes` prefix from any extended context `insideAllScopes ++ extra`.
    All failure branches use this to drop produced items before disqualifying. -/
def insideAllScopesSel {extra : Ctx}
    : Selection (insideAllScopes ++ extra) insideAllScopes :=
  Selection.prefix insideAllScopes extra

/-- Shared disqualification arrow: produces NonQualifying from Patient. -/
def nqArrow : Arrow insideAllScopes (insideAllScopes ++ [NonQualifying "Jose"]) :=
  mkArrow "disqualify"
    [Patient "Jose"]
    [NonQualifying "Jose"]
    (.bind (Patient.mk "Jose") (by elem_tac)
      .nil)

/-- Context after consent + assessment (branch point for post-assessment NQ check). -/
abbrev afterAssessment : Ctx :=
  (insideAllScopes ++ [ConsentGiven "Jose"]) ++ [AssessmentResult "Jose"]

-- ══════════════════════════════════════════════════════════════════════════
-- Phase 2: Drug administration (bounded × 3)
-- ══════════════════════════════════════════════════════════════════════════

/-  Each drug dose iteration:
    1. Enters a visit scope with callConfirmed
    2. Performs drug administration (simplified: one arrow)
    3. Consumes BoundedObligation (k+1), produces BoundedObligation k

    The visit scope nests inside boundedIterate's scope:
      boundedIterate scope (BoundedObligation management)
        → visit scope (callConfirmed constraint)
          → drug admin body -/

/-- Drug admin arrow: with BoundedObligation at front of context.
    Produces decremented counter. -/
def drugAdminArrow (k : Nat) :
    Arrow ([BoundedObligation "drugDose" (k+1)] ++ insideAllScopes)
          (([BoundedObligation "drugDose" (k+1)] ++ insideAllScopes)
            ++ [BoundedObligation "drugDose" k]) :=
  mkArrow "drugAdmin"
    [BoundedObligation "drugDose" (k+1), Patient "Jose", Clinician "Allen"]
    [BoundedObligation "drugDose" k]
    (.bind (BoundedObligation.mk "drugDose" (k+1)) (by elem_tac)
      (.bind (Patient.mk "Jose") (by elem_tac)
        (.bind (Clinician.mk "Allen") (by elem_tac)
          .nil)))

/-- Drop consumed BoundedObligation (k+1) after producing (k). -/
def dropBoundedObl (k : Nat) :
    Split (([BoundedObligation "drugDose" (k+1)] ++ insideAllScopes)
            ++ [BoundedObligation "drugDose" k])
          [BoundedObligation "drugDose" (k+1)]
          (insideAllScopes ++ [BoundedObligation "drugDose" k]) :=
  .left (Split.idRight (insideAllScopes ++ [BoundedObligation "drugDose" k]))

/-- Reorder: put BoundedObligation k at front (required by kept). -/
def reorderBounded (k : Nat) :
    Arrow (insideAllScopes ++ [BoundedObligation "drugDose" k])
          ([BoundedObligation "drugDose" k] ++ insideAllScopes) :=
  Arrow.swap (Γ₁ := insideAllScopes) (Γ₂ := [BoundedObligation "drugDose" k])

/-- Drug admin body for iteration k, running inside a visit scope.
    State is visitState (visitItems pushed onto roomState by the visit scope). -/
def drugAdminInner (k : Nat) : SheetDiagram visitState
    ([BoundedObligation "drugDose" (k+1)] ++ insideAllScopes) visitState
    [[BoundedObligation "drugDose" k] ++ insideAllScopes] :=
  .pipe (drugAdminArrow k)
    (.pipe (.drop (dropBoundedObl k))
      (.arrow (reorderBounded k)))

/-- Drug visit body for iteration k: visit scope wrapping the admin body.
    The visit scope provides callConfirmed; boundedIterate provides BoundedObligation. -/
def drugVisitBody (k : Nat) : SheetDiagram roomState
    ([BoundedObligation "drugDose" (k+1)] ++ insideAllScopes) roomState
    [[BoundedObligation "drugDose" k] ++ insideAllScopes] :=
  .scope "dose-visit" visitItems ([] : Ctx) ([] : Ctx) roomState
    visitObligations
    call_confirmed_jose
    (drugAdminInner k)

/-- Three drug dose iterations using boundedIterate with per-visit callConfirmed. -/
def drugPhase : SheetDiagram roomState insideAllScopes roomState [insideAllScopes] :=
  boundedIterate "drugDose" "drug-dose" drugVisitBody 3

-- ══════════════════════════════════════════════════════════════════════════
-- Phase 3: Weekly checkups (unbounded)
-- ══════════════════════════════════════════════════════════════════════════

/-  Each checkup iteration:
    1. Enters a visit scope with callConfirmed
    2. Performs vitals + assessment + AE collection (simplified: one arrow)
    3. Consumes Obligation, produces Fulfilled

    The visit scope nests inside unboundedStep's scope:
      unboundedStep scope (Obligation/Fulfilled management)
        → visit scope (callConfirmed constraint)
          → checkup body -/

/-- Checkup arrow: Obligation at front, produces Fulfilled. -/
def checkupArrow :
    Arrow ([Obligation "weeklyCheckup"] ++ insideAllScopes)
          (([Obligation "weeklyCheckup"] ++ insideAllScopes)
            ++ [Fulfilled "weeklyCheckup"]) :=
  mkArrow "checkup"
    [Obligation "weeklyCheckup", Patient "Jose", Clinician "Allen"]
    [Fulfilled "weeklyCheckup"]
    (.bind (Obligation.mk "weeklyCheckup") (by elem_tac)
      (.bind (Patient.mk "Jose") (by elem_tac)
        (.bind (Clinician.mk "Allen") (by elem_tac)
          .nil)))

/-- Drop consumed Obligation after producing Fulfilled. -/
def dropCheckupObl :
    Split (([Obligation "weeklyCheckup"] ++ insideAllScopes)
            ++ [Fulfilled "weeklyCheckup"])
          [Obligation "weeklyCheckup"]
          (insideAllScopes ++ [Fulfilled "weeklyCheckup"]) :=
  .left (Split.idRight (insideAllScopes ++ [Fulfilled "weeklyCheckup"]))

/-- Reorder: put Fulfilled at front (required by kept). -/
def reorderFulfilled :
    Arrow (insideAllScopes ++ [Fulfilled "weeklyCheckup"])
          ([Fulfilled "weeklyCheckup"] ++ insideAllScopes) :=
  Arrow.swap (Γ₁ := insideAllScopes) (Γ₂ := [Fulfilled "weeklyCheckup"])

/-- Checkup body running inside a visit scope.
    State is visitState (visitItems pushed onto roomState). -/
def checkupInner : SheetDiagram visitState
    ([Obligation "weeklyCheckup"] ++ insideAllScopes) visitState
    [[Fulfilled "weeklyCheckup"] ++ insideAllScopes] :=
  .pipe checkupArrow
    (.pipe (.drop dropCheckupObl)
      (.arrow reorderFulfilled))

/-- Checkup visit body: visit scope wrapping the checkup body.
    The visit scope provides callConfirmed; unboundedStep provides Obligation. -/
def checkupVisitBody : SheetDiagram roomState
    ([Obligation "weeklyCheckup"] ++ insideAllScopes) roomState
    [[Fulfilled "weeklyCheckup"] ++ insideAllScopes] :=
  .scope "checkup-visit" visitItems ([] : Ctx) ([] : Ctx) roomState
    visitObligations
    call_confirmed_jose
    checkupInner

/-- One unbounded checkup step with per-visit callConfirmed. -/
def checkupPhase : SheetDiagram roomState insideAllScopes roomState [insideAllScopes] :=
  unboundedStep "weeklyCheckup" "weekly-checkup" checkupVisitBody

-- ══════════════════════════════════════════════════════════════════════════
-- Full compiled pipeline
-- ══════════════════════════════════════════════════════════════════════════

/-- The inner pipeline: screening with NQ branching → drug doses → weekly checkups.
    Two branch points (consent refusal, post-assessment disqualification), one join.
    On success, drug and checkup phases continue on the qualifying path. -/
def innerPipeline : SheetDiagram roomState insideAllScopes roomState
    [insideAllScopes ++ [NonQualifying "Jose"], insideAllScopes] :=
  .join
    (.branch (Split.idLeft insideAllScopes)
      insideAllScopesSel (Selection.id insideAllScopes)
      (.arrow nqArrow)
      (.pipe screeningConsent
        (.pipe screeningAssessment
          (.branch (Split.idLeft afterAssessment)
            insideAllScopesSel (Selection.id afterAssessment)
            (.arrow nqArrow)
            (.pipe (.drop dropScreeningResults)
              (.seq drugPhase checkupPhase))))))

/-- The complete JoseTrial pipeline with all scope nesting:
    trial scope (OurTrial, declares clinicianSpeaksPatient)
      clinic scope (ValClinic, Allen, proves city/assignment/approval/language)
        room scope (Room3, equipment, proves qualifications)
          screening → drug doses (×3) → weekly checkups (unbounded)

    This is the Type 2 → Type 1 compilation result:
      SoA (joseTrialSoA) + KB facts → proof term (SheetDiagram). -/
def joseTrialCompiled : SheetDiagram initState joseCtx initState
    [joseCtx ++ [NonQualifying "Jose"], joseCtx] :=
  .scope "trial" trialItems trialExt trialExt initState
    trialObligations
    PUnit.unit
    (.scope "clinic" clinicItems clinicExt clinicExt (trialItems ++ initState)
      clinicObligations
      (valClinicJoseCityEvidence, allen_assigned_val, trial_approves_val, allenJoseLangEvidence)
      (.scope "room" roomItems roomExt roomExt (clinicItems ++ (trialItems ++ initState))
        roomObligations
        (allen_holds_exambed, allen_holds_bpmonitor, allen_holds_vo2equip)
        innerPipeline))

-- ── Pretty-print the compiled pipeline ───────────────────────────────────

def compiledPipeline : Erased.Pipeline := Erased.erase joseTrialCompiled
#eval toString compiledPipeline

end Compile
