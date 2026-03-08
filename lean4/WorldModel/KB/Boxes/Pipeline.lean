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

  A validated `Pipeline types wirings` is itself a `ToBox` instance:
    • inputs  = the first stage's inputs
    • outputs = the last stage's outputs
  This allows a composed pipeline to be used as a single stage in a larger
  pipeline.
-/
import WorldModel.KB.Boxes.Core

-- Inhabited instances needed for list indexing with `!`
private instance : Inhabited Box := ⟨⟨[], []⟩⟩

-- Coercion: a single `(j, k)` pair is sugar for a one-element list,
-- so `⟨"branch", (j, k)⟩` works alongside `⟨"branch", [(j1,k1), (j2,k2)]⟩`.
instance : Coe (Nat × Nat) (List (Nat × Nat)) := ⟨fun p => [p]⟩

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

/-- A validated, composable pipeline.

    `Pipeline types wirings` is a `Type` (not merely a `Prop`) carrying a
    compile-time proof that `types` and `wirings` form a legal pipeline.
    Because it is a `Type`, it has a `ToBox` instance:

      • inputs  = first stage's inputs
      • outputs = last stage's outputs

    This means a composed pipeline can itself be used as a single stage in a
    larger pipeline, enabling hierarchical composition. -/
structure Pipeline (types : List Box) (wirings : List TypeWiring) : Type where
  h : validatePipeline types wirings = true

/-- A `Pipeline` is a `ToBox` instance whose `Box` exposes the first stage's
    inputs and the last stage's outputs, making it composable as a single unit. -/
instance {types : List Box} {wirings : List TypeWiring} :
    ToBox (Pipeline types wirings) where
  toBox := {
    inputs  := (types.head?.map (·.inputs)).getD [],
    outputs := (types.getLast?.map (·.outputs)).getD []
  }

/-- Build a `Pipeline`, validating the wiring at compile time.
    A type or coverage mismatch is a compile error. -/
def mkPipeline
    (types   : List Box)
    (wirings : List TypeWiring)
    (h : validatePipeline types wirings = true := by decide)
    : Pipeline types wirings :=
  ⟨h⟩

/-- Macro wrapper: resolves `ToBox` instances automatically so types can be
    passed directly instead of being manually wrapped in `ToBox.toBox (α := ...)`.

    ## Syntax

        pipeline! [Type1, Type2, ...] [wiring1, wiring2, ...]

    Expands to:

        mkPipeline [ToBox.toBox (α := Type1), ToBox.toBox (α := Type2), ...]
                   [wiring1, wiring2, ...] (by native_decide)
-/
macro "pipeline!" "[" ts:term,* "]" "[" ws:term,* "]" : term =>
  `(mkPipeline [$[ ToBox.toBox (α := $ts) ],*] [$ws,*] (by native_decide))

/-- Convenience accessor: returns the composed `Box` for a pipeline value,
    equivalent to `ToBox.toBox (α := Pipeline types wirings)`. -/
def Pipeline.box {types : List Box} {wirings : List TypeWiring}
    (_ : Pipeline types wirings) : Box :=
  ToBox.toBox (α := Pipeline types wirings)
