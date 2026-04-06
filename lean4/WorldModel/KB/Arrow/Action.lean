/-
  WorldModel.KB.Arrow.Action
  Typed action constructors that enforce catalog requirements at the type level.

  Each constructor wraps `mkArrow` with a fixed input list matching the
  ActionCatalog (Neo4j REQUIRES edges). The Prover calls e.g.
  `Action.heartMeasurement "Jose" "Allen" sat` and the type system demands
  ExamBed + holdsExamBedQual in context — no way to skip required inputs.

  Tag enforcement: `holdsExamBedQual (Human.mk cn) .mk` is parameterized by
  `cn` (clinician name). This type only enters context if `cn` was tagged as
  `.examBedTech` in a room scope and the `.examBedQual` constraint fired.

  `mkArrow` stays public as a fallback for iteration body arrows that need
  `BoundedObligation`/`Obligation` tokens (framework-level, not catalog-level).
-/
import WorldModel.KB.Arrow.Arrow
import WorldModel.KB.Arrow.Clinical

namespace Action

-- ── Measurement actions (Patient + Clinician + Equipment + Qualification) ────

def heartMeasurement (pn cn : String) {Γ : Ctx}
    (sat : Satisfy (Tel.ofList [Patient pn, Clinician cn, ExamBed,
                                 holdsExamBedQual (Human.mk cn) .mk]) Γ Γ)
    : Arrow Γ (Γ ++ [HeartRate pn]) :=
  mkArrow "heartMeasurement"
    [Patient pn, Clinician cn, ExamBed, holdsExamBedQual (Human.mk cn) .mk]
    [HeartRate pn] sat

def bpMeasurement (pn cn : String) {Γ : Ctx}
    (sat : Satisfy (Tel.ofList [Patient pn, Clinician cn, BPMonitor,
                                 holdsBPMonitorQual (Human.mk cn) .mk]) Γ Γ)
    : Arrow Γ (Γ ++ [BloodPressure pn]) :=
  mkArrow "bpMeasurement"
    [Patient pn, Clinician cn, BPMonitor, holdsBPMonitorQual (Human.mk cn) .mk]
    [BloodPressure pn] sat

def vo2Measurement (pn cn : String) {Γ : Ctx}
    (sat : Satisfy (Tel.ofList [Patient pn, Clinician cn, VO2Equipment,
                                 holdsVO2EquipmentQual (Human.mk cn) .mk]) Γ Γ)
    : Arrow Γ (Γ ++ [VO2Max pn]) :=
  mkArrow "vo2Measurement"
    [Patient pn, Clinician cn, VO2Equipment, holdsVO2EquipmentQual (Human.mk cn) .mk]
    [VO2Max pn] sat

-- ── Consent ─────────────────────────────────────────────────────────────────

def consent (pn cn : String) {Γ : Ctx}
    (sat : Satisfy (Tel.ofList [Patient pn, SharedLangEvidence cn pn]) Γ Γ)
    : Arrow Γ (Γ ++ [ConsentGiven pn]) :=
  mkArrow "consent"
    [Patient pn, SharedLangEvidence cn pn]
    [ConsentGiven pn] sat

-- ── Disqualification ────────────────────────────────────────────────────────

def disqualify (pn : String) {Γ : Ctx}
    (sat : Satisfy (Tel.ofList [Patient pn]) Γ Γ)
    : Arrow Γ (Γ ++ [NonQualifying pn]) :=
  mkArrow "disqualify"
    [Patient pn]
    [NonQualifying pn] sat

-- ── Confirmation call ───────────────────────────────────────────────────────

def confirmationCall (pn : String) {Γ : Ctx}
    (sat : Satisfy (Tel.ofList [Patient pn]) Γ Γ)
    : Arrow Γ (Γ ++ [CallConfirmed pn]) :=
  mkArrow "confirmationCall"
    [Patient pn]
    [CallConfirmed pn] sat

-- ── Products (aggregate measurements) ───────────────────────────────────────

def products (pn : String) {Γ : Ctx}
    (sat : Satisfy (Tel.ofList [ConsentGiven pn, HeartRate pn,
                                 BloodPressure pn, VO2Max pn]) Γ Γ)
    : Arrow Γ (Γ ++ [ProductsOutput pn]) :=
  mkArrow "products"
    [ConsentGiven pn, HeartRate pn, BloodPressure pn, VO2Max pn]
    [ProductsOutput pn] sat

-- ── Assessment ──────────────────────────────────────────────────────────────

def assessment (pn : String) {Γ : Ctx}
    (sat : Satisfy (Tel.ofList [Patient pn, ProductsOutput pn]) Γ Γ)
    : Arrow Γ (Γ ++ [AssessmentResult pn]) :=
  mkArrow "assessment"
    [Patient pn, ProductsOutput pn]
    [AssessmentResult pn] sat

-- ── Drug administration ─────────────────────────────────────────────────────

def drugAdmin (pn cn : String) {Γ : Ctx}
    (sat : Satisfy (Tel.ofList [Patient pn, Clinician cn]) Γ Γ)
    : Arrow Γ (Γ ++ [AdminRecord pn]) :=
  mkArrow "drugAdmin"
    [Patient pn, Clinician cn]
    [AdminRecord pn] sat

-- ── Adverse event collection ────────────────────────────────────────────────

def aeCollection (pn cn : String) {Γ : Ctx}
    (sat : Satisfy (Tel.ofList [Patient pn, Clinician cn]) Γ Γ)
    : Arrow Γ (Γ ++ [AEReport pn]) :=
  mkArrow "aeCollection"
    [Patient pn, Clinician cn]
    [AEReport pn] sat

-- ── Survival check ──────────────────────────────────────────────────────────

def survivalCheck (pn cn : String) {Γ : Ctx}
    (sat : Satisfy (Tel.ofList [Patient pn, Clinician cn]) Γ Γ)
    : Arrow Γ (Γ ++ [SurvivalStatus pn]) :=
  mkArrow "survivalCheck"
    [Patient pn, Clinician cn]
    [SurvivalStatus pn] sat

end Action
