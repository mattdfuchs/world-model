/-
  WorldModel.KB.Arrow.Obligation
  Promissory notes: linear tokens mediating iteration.

  An `Obligation visitId` is issued into context at iteration start (cup).
  The body must consume it and produce evidence:
    - `Fulfilled visitId`: continue to next iteration
    - `Terminated visitId`: stop (carries the termination reason from the SoA)

  Obligations bridge Type 2 (SoA spec) and Type 1 (SheetDiagram proof):
  visit IDs from the SoA are the keys.

  No new Arrow/SheetDiagram constructors — existing `scope` + `branch` +
  `seq` + `drop` express the full iteration pattern.  Obligations are just
  types in `Ctx`.
-/
import WorldModel.KB.Arrow.Resource
import WorldModel.KB.SoA

-- ══════════════════════════════════════════════════════════════════════════
-- Section 1: Obligation types
-- ══════════════════════════════════════════════════════════════════════════

/-- Unbounded iteration debit: "you owe a proof for visit X".
    Used for ν-streams (repeat until external termination). -/
inductive Obligation : String → Type where
  | mk : (visitId : String) → Obligation visitId

/-- Bounded iteration debit with decreasing counter.
    Used for μ-streams (repeat N times).  Parallels `Vial n`. -/
inductive BoundedObligation : String → Nat → Type where
  | mk : (visitId : String) → (remaining : Nat) → BoundedObligation visitId remaining

/-- Success credit: the iteration body completed, continue.
    Consumed at scope exit when `kept = [Fulfilled vid]`. -/
inductive Fulfilled : String → Type where
  | mk : (visitId : String) → Fulfilled visitId

/-- Termination credit: stop the iteration.
    Carries the `TerminationCondition` from the SoA as runtime data. -/
inductive Terminated : String → Type where
  | mk : (visitId : String) → TerminationCondition → Terminated visitId

-- ══════════════════════════════════════════════════════════════════════════
-- Section 2: Resource classification
-- ══════════════════════════════════════════════════════════════════════════

-- All four are one-shot tokens, never checked back in.
instance : Consumed (Obligation vid) where
instance : Consumed (BoundedObligation vid n) where
instance : Consumed (Fulfilled vid) where
instance : Consumed (Terminated vid) where

-- ══════════════════════════════════════════════════════════════════════════
-- Section 3: SoA extraction
-- ══════════════════════════════════════════════════════════════════════════

/-- Classification of a visit's iteration behavior.
    Extracted from `InteractionNode.repeating`. -/
inductive ObligationSpec where
  | none                                                            -- one-shot visit
  | unbounded (visitId : String) (days : Nat)
              (terminateOn : TerminationCondition)                  -- ν-stream
  | bounded   (visitId : String) (days : Nat) (count : Nat)        -- μ-stream
  deriving Repr

/-- Extract the obligation spec from an interaction node. -/
def InteractionNode.obligationSpec (node : InteractionNode) : ObligationSpec :=
  match node.repeating with
  | none                            => .none
  | some (.every days (.fixed cnt)) => .bounded node.id days cnt
  | some (.every days tc)           => .unbounded node.id days tc
  | some (.cycles cycleDays)        => .unbounded node.id cycleDays .endOfStudy

/-- All non-trivial obligation specs from a SoA. -/
def SoA.obligationSpecs (soa : SoA) : List ObligationSpec :=
  (soa.interactions.map (·.obligationSpec)).filter fun
    | .none => false
    | _     => true

-- Smoke tests: see lean4/test/SoA/ (each file includes obligationSpecs #eval)

-- ══════════════════════════════════════════════════════════════════════════
-- Section 4: Worked example
-- ══════════════════════════════════════════════════════════════════════════

/-  Self-contained example of the obligation / scope ext-kept pattern.
    No KB facts needed — stays computable.

    Pattern:
      scope { ext = [Obligation vid], kept = [Fulfilled vid] }
        body: Obligation → Fulfilled (via mkArrow)
        drop consumed Obligation
        swap to put Fulfilled at front
      end scope

    This mirrors DrugExample (scope ext/kept + drop + seq) but with
    obligation tokens instead of vials. -/
namespace ObligationExample

-- ── Base context and state ──────────────────────────────────────────────

abbrev baseCtx : Ctx := [Clinician "Allen", Patient "Jose"]
abbrev baseState : ScopeState := []

-- No scope items or constraint obligations for this example.
abbrev iterItems : List ScopeItem := []
abbrev iterObligations : List Type := []

-- ── Inner context (inside the iteration scope) ──────────────────────────

abbrev innerCtx : Ctx := [Obligation "treatment"] ++ baseCtx

-- ── Arrow body: consumes Obligation, produces Fulfilled ─────────────────

def infusionBody : Arrow innerCtx (innerCtx ++ [Fulfilled "treatment"]) :=
  mkArrow "infusion"
    [Obligation "treatment", Patient "Jose", Clinician "Allen"]
    [Fulfilled "treatment"]
    (.bind (Obligation.mk "treatment") (by elem_tac)
      (.bind (Patient.mk "Jose") (by elem_tac)
        (.bind (Clinician.mk "Allen") (by elem_tac)
          .nil)))

-- ── Drop consumed obligation ────────────────────────────────────────────

def dropObligation : Split (innerCtx ++ [Fulfilled "treatment"])
                           [Obligation "treatment"]
                           (baseCtx ++ [Fulfilled "treatment"]) :=
  .left (Split.idRight (baseCtx ++ [Fulfilled "treatment"]))

-- ── Reorder: put Fulfilled at the front (required by kept) ──────────────

def reorderFulfilled : Arrow (baseCtx ++ [Fulfilled "treatment"])
                              ([Fulfilled "treatment"] ++ baseCtx) :=
  Arrow.swap (Γ₁ := baseCtx) (Γ₂ := [Fulfilled "treatment"])

-- ── One iteration: scope with ext/kept ──────────────────────────────────

/-- A single iteration:
    - `ext = [Obligation "treatment"]` issues the debit
    - body transforms Obligation → Fulfilled
    - `kept = [Fulfilled "treatment"]` absorbs the credit at scope exit
    - outer result: back to `baseCtx` -/
def oneIteration : SheetDiagram baseState baseCtx baseState [baseCtx] :=
  .scope "iteration" iterItems
    [Obligation "treatment"] [Fulfilled "treatment"] baseState
    iterObligations PUnit.unit
    (.pipe infusionBody
      (.pipe (.drop dropObligation)
        (.arrow reorderFulfilled)))

-- ── Two iterations: seq of two scope blocks ─────────────────────────────

/-- Two manually unrolled iterations.  Each scope issues and absorbs its
    own Obligation/Fulfilled pair; `seq` chains them over `baseCtx`. -/
def twoIterations : SheetDiagram baseState baseCtx baseState [baseCtx] :=
  .seq oneIteration oneIteration

end ObligationExample

-- ══════════════════════════════════════════════════════════════════════════
-- Section 5: Bounded variant note
-- ══════════════════════════════════════════════════════════════════════════

/-
  Bounded obligations parallel the Vial pattern from DrugExample:

    BoundedObligation "treatment" 2 → 1 → 0

  Encoding via scope ext/kept:
    scope { ext = [BoundedObligation vid (n+1)],
            kept = [BoundedObligation vid n] }

  Each iteration decrements the counter.  At n = 0, the body produces
  `Terminated vid` instead of another BoundedObligation, and the scope
  can use `kept = []` + `halt` to terminate.

  The actual loop constructor (step 4) will generate this sequence
  mechanically.  For now, manual unrolling works exactly as in DrugExample
  where `Vial 2 → Vial 1 → Vial 0` is expressed via three nested scopes.
-/
