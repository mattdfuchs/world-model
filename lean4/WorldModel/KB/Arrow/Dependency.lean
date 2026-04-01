/-
  WorldModel.KB.Arrow.Dependency
  Dependency tracking for proof invalidation.

  Scope nesting IS the Gentzen proof tree.  KB facts enter only at scope
  boundaries via `AllObligations`.  A dependency manifest records which KB
  facts support which scopes, enabling targeted re-compilation when facts change.

  When `jose_lives_valencia` becomes false (Jose moves), the `clinic` node is
  invalidated → everything below it must be re-compiled.  When only
  `call_confirmed_jose` changes, only the specific visit scope is invalidated.
-/
import WorldModel.KB.Arrow.Erase

-- ══════════════════════════════════════════════════════════════════════════
-- Section 1: Erased pipeline dependency extraction
-- ══════════════════════════════════════════════════════════════════════════

namespace Erased

/-- A node in the dependency tree extracted from an erased pipeline.
    Each scope records its label; `leaf` nodes represent steps/cups/caps. -/
inductive DepNode where
  | scope (label : String) (children : List DepNode)
  | leaf  (label : String)
  deriving Repr

/-- Extract the dependency tree from an erased pipeline.
    Scopes become tree nodes, steps become leaves. -/
def extractDeps : Pipeline → DepNode
  | .scope lbl body  => .scope lbl [extractDeps body]
  | .seq a b         => .scope "seq" [extractDeps a, extractDeps b]
  | .branch l r      => .scope "branch" [extractDeps l, extractDeps r]
  | .join s          => extractDeps s
  | .step name       => .leaf name
  | .cup label       => .leaf s!"cup:{label}"
  | .cap label       => .leaf s!"cap:{label}"
  | .par a b         => .scope "par" [extractDeps a, extractDeps b]
  | .halt            => .leaf "halt"
  | .noop            => .leaf "noop"

/-- Indented string representation of a dependency tree. -/
partial def DepNode.format (d : DepNode) (indent : Nat) : String :=
  let pad := String.mk (List.replicate (indent * 2) ' ')
  match d with
  | .leaf label => s!"{pad}{label}"
  | .scope label children =>
    let childStrs := children.map (·.format (indent + 1))
    s!"{pad}{label}\n" ++ String.intercalate "\n" childStrs

instance : ToString DepNode where
  toString d := d.format 0

end Erased

-- ══════════════════════════════════════════════════════════════════════════
-- Section 2: Rich dependency manifest (compiler-produced)
-- ══════════════════════════════════════════════════════════════════════════

/-- A dependency manifest produced during compilation.
    Maps scope labels to the KB facts that were used as evidence.
    This is richer than `DepNode`: the compiler knows which KB queries
    it made to satisfy obligations at each scope boundary. -/
structure DependencyManifest where
  scopeLabel : String
  kbFacts    : List String
  children   : List DependencyManifest
  deriving Repr

/-- Pretty-print a dependency manifest as an indented tree. -/
partial def DependencyManifest.format (d : DependencyManifest) (indent : Nat) : String :=
  let pad := String.mk (List.replicate (indent * 2) ' ')
  let facts := if d.kbFacts.isEmpty then "" else s!" [{String.intercalate ", " d.kbFacts}]"
  let children := d.children.map (·.format (indent + 1))
  s!"{pad}{d.scopeLabel}{facts}" ++
    (if children.isEmpty then "" else "\n" ++ String.intercalate "\n" children)

instance : ToString DependencyManifest where
  toString d := d.format 0

-- ══════════════════════════════════════════════════════════════════════════
-- Section 3: JoseTrial dependency manifest
-- ══════════════════════════════════════════════════════════════════════════

/-- Hand-constructed dependency manifest for the JoseTrial compilation.
    Records which KB facts support each scope level.

    Invalidation rules:
    - If `jose_lives_valencia` changes → clinic scope invalidated → everything below
    - If `allen_assigned_val` changes → clinic scope invalidated
    - If `allen_holds_exambed` changes → room scope invalidated
    - If `call_confirmed_jose` changes → only the specific visit scope -/
def joseTrialDeps : DependencyManifest :=
  { scopeLabel := "trial", kbFacts := []
    children := [
      { scopeLabel := "clinic"
        kbFacts := ["jose_lives_valencia", "valClinic_in_valencia",
                     "allen_assigned_val", "trial_approves_val",
                     "allen_speaks_spanish", "jose_speaks_spanish"]
        children := [
          { scopeLabel := "room"
            kbFacts := ["allen_holds_exambed", "allen_holds_bpmonitor", "allen_holds_vo2equip"]
            children := [
              { scopeLabel := "screening", kbFacts := ["call_confirmed_jose"], children := [] }
            , { scopeLabel := "drug-dose", kbFacts := ["call_confirmed_jose"], children := [] }
            , { scopeLabel := "weekly-checkup", kbFacts := ["call_confirmed_jose"], children := [] }
            ] }
        ] }
    ] }

#eval toString joseTrialDeps
