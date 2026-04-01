/-
  WorldModel.KB.Arrow.Iterate
  Cup/cap worked examples and iteration combinators.

  Three cases demonstrating spatial resource management:
    Case 1 — Equipment checkout/return (conserved, cross-scope)
    Case 2 — Dose fission (arrow produces obligation, cap cancels)
    Case 3 — Permanent transfer (one-way, cap acknowledges immediately)

  Two iteration combinators using scope ext/kept (temporal lifecycle):
    `unboundedStep` — single ν-iteration (Obligation → Fulfilled)
    `boundedIterate` — n μ-iterations (BoundedObligation countdown)
-/
import WorldModel.KB.Arrow.SheetDiagram
import WorldModel.KB.Arrow.Clinical
import WorldModel.KB.Arrow.Resource
import WorldModel.KB.Arrow.Obligation
import WorldModel.KB.Arrow.Erase

-- ══════════════════════════════════════════════════════════════════════════
-- Case 1: Equipment checkout/return (conserved, cross-scope)
-- ══════════════════════════════════════════════════════════════════════════

/-  Pattern:
      cup "checkout-bed" ExamBed ExamBedReceipt → [ExamBed, ExamBedReceipt] ++ Γ
      scope "patient-room" { body uses ExamBed, ExamBed passes through }
      cap "return-bed" ExamBed ExamBedReceipt   → Γ
-/

namespace EquipmentExample

abbrev baseCtx : Ctx := [Patient "Jose", Clinician "Allen"]
abbrev baseState : ScopeState := []

-- After cup: [ExamBed, ExamBedReceipt] ++ baseCtx
abbrev withEquip : Ctx := [ExamBed, ExamBedReceipt] ++ baseCtx

-- A simple procedure arrow using the exam bed inside a room scope
def examProcedure : Arrow ([Room "Room3"] ++ withEquip)
    (([Room "Room3"] ++ withEquip) ++ [HeartRate "Jose"]) :=
  mkArrow "examProcedure" [Patient "Jose", ExamBed] [HeartRate "Jose"]
    (.bind (Patient.mk "Jose") (by elem_tac)
      (.bind ExamBed.mk (by elem_tac) .nil))

-- Drop HeartRate (consumed by later processing, not relevant here)
def dropHR : Split (([Room "Room3"] ++ withEquip) ++ [HeartRate "Jose"])
                    [HeartRate "Jose"] ([Room "Room3"] ++ withEquip) :=
  Split.append ([Room "Room3"] ++ withEquip) [HeartRate "Jose"] |>.comm

-- Room scope: ext=[Room], kept=[Room], body uses equipment from Γ
def roomScope : SheetDiagram baseState withEquip baseState [withEquip] :=
  .scope "patient-room" [.entry ⟨"Room3", .room⟩] [Room "Room3"] [Room "Room3"]
    baseState [] PUnit.unit
    (.pipe examProcedure (.arrow (.drop dropHR)))

-- Cap split: [ExamBed, ExamBedReceipt] at front of withEquip
def capSplitBed : Split withEquip [ExamBed, ExamBedReceipt] baseCtx :=
  .left (.left (Split.idRight baseCtx))

/-- Equipment checkout/return: cup creates ExamBed + receipt, scope uses bed,
    cap cancels the pair on return. -/
def equipmentCheckout : SheetDiagram baseState baseCtx baseState [baseCtx] :=
  .seq (.cup "checkout-bed" ExamBed ExamBedReceipt)
    (.seq roomScope
      (.cap "return-bed" ExamBed ExamBedReceipt capSplitBed))

-- Pretty-print
def equipmentPipeline : Erased.Pipeline := Erased.erase equipmentCheckout
#eval toString equipmentPipeline

end EquipmentExample

-- ══════════════════════════════════════════════════════════════════════════
-- Case 2: Dose fission (arrow produces obligation, cap cancels)
-- ══════════════════════════════════════════════════════════════════════════

/-  The draw arrow fissions a vial:
      Vial n → [DrugDose p, DoseObligation p, Vial (n-1)]
    No cup — the obligation is born at the point of fission.
    Cap cancels (DoseObligation p, AdminRecord p) after administration.

    See DrugExample in Clinical.lean for the full worked pipeline.
    This section just demonstrates a minimal single-dose fission cycle.
-/

namespace DoseFissionExample

abbrev baseCtx : Ctx := [Patient "Jose", Clinician "Allen"]
abbrev baseState : ScopeState := []

-- Draw arrow: Vial 1 → DrugDose + DoseObligation + Vial 0
def drawDose : Arrow ([Vial 1] ++ baseCtx)
    (([Vial 1] ++ baseCtx) ++ [DrugDose "Jose", DoseObligation "Jose", Vial 0]) :=
  mkArrow "drawDose" [Vial 1] [DrugDose "Jose", DoseObligation "Jose", Vial 0]
    (.bind (Vial.mk 1) (by elem_tac) .nil)

-- Drop stale Vial 1
def dropVial1 : Split (([Vial 1] ++ baseCtx) ++ [DrugDose "Jose", DoseObligation "Jose", Vial 0])
                       [Vial 1] (baseCtx ++ [DrugDose "Jose", DoseObligation "Jose", Vial 0]) :=
  .left (Split.idRight (baseCtx ++ [DrugDose "Jose", DoseObligation "Jose", Vial 0]))

-- Reorder: put Vial 0 at front for scope kept
def reorder : Arrow ([DrugDose "Jose", DoseObligation "Jose", Vial 0] ++ baseCtx)
    ([Vial 0, DrugDose "Jose", DoseObligation "Jose"] ++ baseCtx) :=
  Arrow.par
    (Arrow.swap (Γ₁ := [DrugDose "Jose", DoseObligation "Jose"]) (Γ₂ := [Vial 0]))
    (Arrow.id (Γ := baseCtx))

-- Supply room scope: ext=[Vial 1], kept=[Vial 0]
abbrev supplyItems : List ScopeItem := []

def supplyVisit : SheetDiagram baseState baseCtx baseState
    [[DrugDose "Jose", DoseObligation "Jose"] ++ baseCtx] :=
  .scope "supply-room" supplyItems [Vial 1] [Vial 0] baseState [] PUnit.unit
    (.pipe drawDose
      (.pipe (.drop dropVial1)
        (.pipe (Arrow.swap (Γ₁ := baseCtx) (Γ₂ := [DrugDose "Jose", DoseObligation "Jose", Vial 0]))
          (.arrow reorder))))

-- Administer dose
abbrev afterSupply : Ctx := [DrugDose "Jose", DoseObligation "Jose"] ++ baseCtx

def administer : Arrow afterSupply (afterSupply ++ [AdminRecord "Jose"]) :=
  mkArrow "administer" [DrugDose "Jose", Patient "Jose"] [AdminRecord "Jose"]
    (.bind (DrugDose.mk "Jose") (by elem_tac)
      (.bind (Patient.mk "Jose") (by elem_tac) .nil))

-- Drop used DrugDose
def dropUsedDose : Split (afterSupply ++ [AdminRecord "Jose"])
                          [DrugDose "Jose"]
                          ([DoseObligation "Jose"] ++ baseCtx ++ [AdminRecord "Jose"]) :=
  .left (Split.idRight ([DoseObligation "Jose"] ++ baseCtx ++ [AdminRecord "Jose"]))

-- Cap: cancel DoseObligation with AdminRecord
-- Context: [DoseObligation "Jose", Patient "Jose", Clinician "Allen", AdminRecord "Jose"]
def capSplit : Split ([DoseObligation "Jose"] ++ baseCtx ++ [AdminRecord "Jose"])
                      [DoseObligation "Jose", AdminRecord "Jose"] baseCtx :=
  .left (.right (.right (.left .nil)))

/-- Single-dose fission cycle: draw → administer → drop → cap → clean. -/
def doseFissionCycle : SheetDiagram baseState baseCtx baseState [baseCtx] :=
  .seq supplyVisit
    (.seq (.arrow (administer ⟫ .drop dropUsedDose))
      (.cap "dose-delivered" (DoseObligation "Jose") (AdminRecord "Jose") capSplit))

def doseFissionPipeline : Erased.Pipeline := Erased.erase doseFissionCycle
#eval toString doseFissionPipeline

end DoseFissionExample

-- ══════════════════════════════════════════════════════════════════════════
-- Case 3: Permanent transfer (one-way, no return)
-- ══════════════════════════════════════════════════════════════════════════

/-  Pattern:
      cup "transfer-bed" ExamBed ExamBedReceipt → [ExamBed, ExamBedReceipt] ++ Γ
      scope "room-A": uses ExamBed for a procedure
      scope "room-B": uses ExamBed for another procedure (permanent move)
      cap "transfer-complete" ExamBed ExamBedReceipt → Γ
    The bed moves from room A to room B and stays. Cap acknowledges the transfer.
-/

namespace TransferExample

abbrev baseCtx : Ctx := [Patient "Jose", Clinician "Allen"]
abbrev baseState : ScopeState := []

abbrev withEquip : Ctx := [ExamBed, ExamBedReceipt] ++ baseCtx

-- Room A scope: exam bed used, passes through
def procA : Arrow ([Room "RoomA"] ++ withEquip)
    (([Room "RoomA"] ++ withEquip) ++ [HeartRate "Jose"]) :=
  mkArrow "procA" [Patient "Jose", ExamBed] [HeartRate "Jose"]
    (.bind (Patient.mk "Jose") (by elem_tac)
      (.bind ExamBed.mk (by elem_tac) .nil))

def dropHR_A : Split (([Room "RoomA"] ++ withEquip) ++ [HeartRate "Jose"])
                      [HeartRate "Jose"] ([Room "RoomA"] ++ withEquip) :=
  Split.append ([Room "RoomA"] ++ withEquip) [HeartRate "Jose"] |>.comm

def roomAScope : SheetDiagram baseState withEquip baseState [withEquip] :=
  .scope "room-A" [.entry ⟨"RoomA", .room⟩] [Room "RoomA"] [Room "RoomA"]
    baseState [] PUnit.unit
    (.pipe procA (.arrow (.drop dropHR_A)))

-- Room B scope: exam bed used again (it transferred here)
def procB : Arrow ([Room "RoomB"] ++ withEquip)
    (([Room "RoomB"] ++ withEquip) ++ [BloodPressure "Jose"]) :=
  mkArrow "procB" [Patient "Jose", ExamBed] [BloodPressure "Jose"]
    (.bind (Patient.mk "Jose") (by elem_tac)
      (.bind ExamBed.mk (by elem_tac) .nil))

def dropBP_B : Split (([Room "RoomB"] ++ withEquip) ++ [BloodPressure "Jose"])
                      [BloodPressure "Jose"] ([Room "RoomB"] ++ withEquip) :=
  Split.append ([Room "RoomB"] ++ withEquip) [BloodPressure "Jose"] |>.comm

def roomBScope : SheetDiagram baseState withEquip baseState [withEquip] :=
  .scope "room-B" [.entry ⟨"RoomB", .room⟩] [Room "RoomB"] [Room "RoomB"]
    baseState [] PUnit.unit
    (.pipe procB (.arrow (.drop dropBP_B)))

-- Cap: remove ExamBed + ExamBedReceipt
def capSplitTransfer : Split withEquip [ExamBed, ExamBedReceipt] baseCtx :=
  .left (.left (Split.idRight baseCtx))

/-- Permanent transfer: cup creates pair, bed moves through two rooms,
    cap acknowledges the transfer is complete. -/
def permanentTransfer : SheetDiagram baseState baseCtx baseState [baseCtx] :=
  .seq (.cup "transfer-bed" ExamBed ExamBedReceipt)
    (.seq roomAScope
      (.seq roomBScope
        (.cap "transfer-complete" ExamBed ExamBedReceipt capSplitTransfer)))

def transferPipeline : Erased.Pipeline := Erased.erase permanentTransfer
#eval toString transferPipeline

end TransferExample

-- ══════════════════════════════════════════════════════════════════════════
-- Iteration combinators
-- ══════════════════════════════════════════════════════════════════════════

/-- A single unbounded iteration step using scope ext/kept.
    Issues `Obligation vid` into context; body must produce `Fulfilled vid`.
    Scope reclaims the Fulfilled token at exit. -/
def unboundedStep (vid label : String) {Γ : Ctx} {st : ScopeState}
    (body : SheetDiagram st ([Obligation vid] ++ Γ) st [[Fulfilled vid] ++ Γ])
    : SheetDiagram st Γ st [Γ] :=
  .scope label [] [Obligation vid] [Fulfilled vid] st [] PUnit.unit body

/-- Bounded iteration: unroll `n` scope blocks, each decrementing a counter.
    `mkBody k` produces the body for iteration `k` (counting down from `n`).
    At `n = 0`, identity (no iterations remain). -/
def boundedIterate (vid label : String) {Γ : Ctx} {st : ScopeState}
    (mkBody : (k : Nat) → SheetDiagram st ([BoundedObligation vid (k+1)] ++ Γ)
                                         st [[BoundedObligation vid k] ++ Γ])
    : (n : Nat) → SheetDiagram st Γ st [Γ]
  | 0     => .arrow Arrow.id
  | n + 1 => .seq
      (.scope label [] [BoundedObligation vid (n+1)] [BoundedObligation vid n]
              st [] PUnit.unit (mkBody n))
      (boundedIterate vid label mkBody n)

/-- Compose a list of uniform-type SheetDiagram blocks sequentially.
    All blocks share the same `Γ` and `st`.
    `[]` is identity, `[s]` is `s`, `[s₁, s₂, ...]` is `seq s₁ (seq s₂ ...)`. -/
def compileSequential : List (SheetDiagram st Γ st [Γ]) → SheetDiagram st Γ st [Γ]
  | []      => .arrow Arrow.id
  | [s]     => s
  | s :: ss => .seq s (compileSequential ss)

-- ── Smoke tests for combinators ────────────────────────────────────────────

namespace CombinatorExample

abbrev baseCtx : Ctx := [Clinician "Allen", Patient "Jose"]
abbrev baseState : ScopeState := []

-- Body for unbounded: consume Obligation, produce Fulfilled
def checkupBody : Arrow ([Obligation "weeklyCheckup"] ++ baseCtx)
    (([Obligation "weeklyCheckup"] ++ baseCtx) ++ [Fulfilled "weeklyCheckup"]) :=
  mkArrow "checkup"
    [Obligation "weeklyCheckup", Patient "Jose", Clinician "Allen"]
    [Fulfilled "weeklyCheckup"]
    (.bind (Obligation.mk "weeklyCheckup") (by elem_tac)
      (.bind (Patient.mk "Jose") (by elem_tac)
        (.bind (Clinician.mk "Allen") (by elem_tac)
          .nil)))

def dropObl : Split (([Obligation "weeklyCheckup"] ++ baseCtx)
                      ++ [Fulfilled "weeklyCheckup"])
                     [Obligation "weeklyCheckup"]
                     (baseCtx ++ [Fulfilled "weeklyCheckup"]) :=
  .left (Split.idRight (baseCtx ++ [Fulfilled "weeklyCheckup"]))

def reorderFulfilled : Arrow (baseCtx ++ [Fulfilled "weeklyCheckup"])
                              ([Fulfilled "weeklyCheckup"] ++ baseCtx) :=
  Arrow.swap (Γ₁ := baseCtx) (Γ₂ := [Fulfilled "weeklyCheckup"])

def checkupBodyDiagram : SheetDiagram baseState
    ([Obligation "weeklyCheckup"] ++ baseCtx) baseState
    [[Fulfilled "weeklyCheckup"] ++ baseCtx] :=
  .pipe checkupBody (.pipe (.drop dropObl) (.arrow reorderFulfilled))

/-- One unbounded step — uses the combinator. -/
def oneCheckup : SheetDiagram baseState baseCtx baseState [baseCtx] :=
  unboundedStep "weeklyCheckup" "checkup" checkupBodyDiagram

-- Body for bounded: consume BoundedObligation (k+1), produce BoundedObligation k
def treatmentBody (k : Nat) :
    Arrow ([BoundedObligation "drugDose" (k+1)] ++ baseCtx)
          (([BoundedObligation "drugDose" (k+1)] ++ baseCtx)
            ++ [BoundedObligation "drugDose" k]) :=
  mkArrow "treatment"
    [BoundedObligation "drugDose" (k+1), Patient "Jose"]
    [BoundedObligation "drugDose" k]
    (.bind (BoundedObligation.mk "drugDose" (k+1)) (by elem_tac)
      (.bind (Patient.mk "Jose") (by elem_tac) .nil))

def dropBoundedObl (k : Nat) :
    Split (([BoundedObligation "drugDose" (k+1)] ++ baseCtx)
            ++ [BoundedObligation "drugDose" k])
          [BoundedObligation "drugDose" (k+1)]
          (baseCtx ++ [BoundedObligation "drugDose" k]) :=
  .left (Split.idRight (baseCtx ++ [BoundedObligation "drugDose" k]))

def reorderBounded (k : Nat) :
    Arrow (baseCtx ++ [BoundedObligation "drugDose" k])
          ([BoundedObligation "drugDose" k] ++ baseCtx) :=
  Arrow.swap (Γ₁ := baseCtx) (Γ₂ := [BoundedObligation "drugDose" k])

def treatmentBodyDiagram (k : Nat) : SheetDiagram baseState
    ([BoundedObligation "drugDose" (k+1)] ++ baseCtx) baseState
    [[BoundedObligation "drugDose" k] ++ baseCtx] :=
  .pipe (treatmentBody k)
    (.pipe (.drop (dropBoundedObl k))
      (.arrow (reorderBounded k)))

/-- Three bounded iterations — uses the combinator. -/
def threeTreatments : SheetDiagram baseState baseCtx baseState [baseCtx] :=
  boundedIterate "drugDose" "treatment" treatmentBodyDiagram 3

-- Pretty-print
def checkupPipeline : Erased.Pipeline := Erased.erase oneCheckup
def treatmentPipeline : Erased.Pipeline := Erased.erase threeTreatments
#eval toString checkupPipeline
#eval toString treatmentPipeline

end CombinatorExample
