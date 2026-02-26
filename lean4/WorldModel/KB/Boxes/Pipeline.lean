/-
  WorldModel.KB.Boxes.Pipeline
  Type-level pipeline composition with compile-time wiring validation.

  A pipeline connects n ToBox types in a partially-ordered sequence described by:
    • types   : List Box        — n boxes, one per stage
    • wirings : List TypeWiring — n-1 descriptors, one per non-final stage

  For each non-final stage i, its TypeWiring lists how every output branch
  parameter is routed: `(j, k)` means the parameter flows to input position k
  of stage j (j > i).  Parameters that have no downstream use are explicitly
  wired to a terminator type whose output is Bottom (no params, so its own
  wiring entry is trivially empty).

  Validation (checked at compile time via `decide`) requires:
    1. Every wire (j, k) is forward (j > i), points to a valid input position,
       and the string type matches.
    2. Every input of every non-first stage is covered by at least one wire
       originating from an earlier stage.
-/
import WorldModel.KB.Boxes.Core

-- Inhabited instances needed for list indexing with `!`
private instance : Inhabited Box := ⟨⟨[], []⟩⟩

/-- Wiring for one output branch.
    `params` has one `(Nat × Nat)` per branch parameter:
    `(j, k)` = parameter goes to input k of stage j (j must be > current stage index).
    Parameters with no downstream use are wired to an explicit terminator stage
    whose output is Bottom. -/
structure BranchWire where
  branch : String
  params : List (Nat × Nat)
  deriving Repr

private instance : Inhabited BranchWire := ⟨⟨"", []⟩⟩

/-- All branch wirings for one stage's outputs. -/
abbrev TypeWiring := List BranchWire

-- Check that every wire is forward, in-range, and type-compatible.
private def wiresOk (types : List Box) (wirings : List TypeWiring) : Bool :=
  let n := types.length
  (List.range (n - 1)).all fun i =>
    let wiring := wirings[i]!
    (types[i]!).outputs.all fun (branch, paramTypes) =>
      match wiring.find? (fun bw => bw.branch == branch) with
      | none    => true  -- branch absent from wiring: zero params expected
      | some bw =>
          bw.params.length == paramTypes.length &&
          (List.range bw.params.length).all fun p =>
            let (j, k) := bw.params[p]!
            j > i &&
            j < n &&
            k < (types[j]!).inputs.length &&
            (types[j]!).inputs[k]! == paramTypes[p]!

-- Check that every input of every non-first stage is covered by at least one wire.
private def inputsCovered (types : List Box) (wirings : List TypeWiring) : Bool :=
  let n := types.length
  (List.range (n - 1)).all fun i =>
    let tgt := i + 1
    (List.range (types[tgt]!).inputs.length).all fun k =>
      (List.range tgt).any fun j =>
        (wirings[j]!).any fun bw =>
          bw.params.any fun (tj, tk) => tj == tgt && tk == k

/-- Boolean validity check for a pipeline specification. -/
def validatePipeline (types : List Box) (wirings : List TypeWiring) : Bool :=
  types.length ≥ 2 &&
  wirings.length == types.length - 1 &&
  wiresOk       types wirings &&
  inputsCovered types wirings

/-- A compile-time witness that `types` and `wirings` form a valid pipeline.
    Construct with `mkPipeline`; the proof is discharged by `decide`. -/
structure Pipeline (types : List Box) (wirings : List TypeWiring) : Prop where
  h : validatePipeline types wirings = true

/-- Build a `Pipeline`, validating the wiring at compile time.
    A type or coverage mismatch is a compile error. -/
def mkPipeline
    (types   : List Box)
    (wirings : List TypeWiring)
    (h : validatePipeline types wirings = true := by decide)
    : Pipeline types wirings :=
  ⟨h⟩
