/-
  WorldModel.KB.Arrow.Spec
  Box footprint specifications with telescopes.

  A box's input is a telescope — a dependent product where each entry
  can refer to earlier bindings.  This captures the dependency between
  objects and their constraints (e.g. an authorization depends on which
  clinician and patient are selected).
-/
import WorldModel.KB.Arrow.Context

/-- A telescope: dependent list where each type can depend on previous values.
    The flat (non-dependent) case is `Tel.ofList`. -/
inductive Tel : Type 1 where
  | nil  : Tel
  | cons : (A : Type) → (A → Tel) → Tel

/-- Values inhabiting a telescope. -/
inductive TelVal : Tel → Type 1 where
  | nil  : TelVal .nil
  | cons : (a : A) → TelVal (t a) → TelVal (.cons A t)

/-- Build a non-dependent telescope from a flat context.
    Each entry ignores the bound value, so the telescope is a simple product. -/
def Tel.ofList : Ctx → Tel
  | []        => .nil
  | A :: rest => .cons A (fun _ => Tel.ofList rest)

/-- Box footprint specification.
    - `inputs`:   telescope of needed objects and constraints
    - `consumes`: flat list of types consumed (removed from context on exit)
    - `produces`: flat list of new types created -/
structure Spec where
  name        : String
  description : String := ""
  inputs      : Tel
  consumes    : Ctx
  produces    : Ctx
