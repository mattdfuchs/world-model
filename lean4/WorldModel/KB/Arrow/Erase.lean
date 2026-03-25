/-
  WorldModel.KB.Arrow.Erase
  Type-free pipeline representation obtained by erasing proof content.

  After type checking, all de Bruijn indices, Selection/Split/Satisfy witnesses,
  and frame arguments can be erased.  The `Erased.Pipeline` type captures only the
  computational structure (scopes, branches, steps, joins) with string labels.

  `eraseArrow` and `erase` formally connect the typed and untyped worlds.
-/
import WorldModel.KB.Arrow.SheetDiagram
import WorldModel.KB.Arrow.Clinical

namespace Erased

/-- Type-free pipeline: the computational skeleton of a SheetDiagram. -/
inductive Pipeline where
  | step   : String → Pipeline
  | seq    : Pipeline → Pipeline → Pipeline
  | par    : Pipeline → Pipeline → Pipeline
  | branch : Pipeline → Pipeline → Pipeline
  | scope  : String → Pipeline → Pipeline
  | join   : Pipeline → Pipeline
  | halt   : Pipeline
  | noop   : Pipeline
  deriving Repr

/-- Erase proof content from an Arrow, keeping only step names. -/
def eraseArrow : Arrow Γ Δ → Pipeline
  | .step spec _ _ => .step spec.name
  | .seq a b       => .seq (eraseArrow a) (eraseArrow b)
  | .par a b       => .par (eraseArrow a) (eraseArrow b)
  | .id            => .noop
  | .swap          => .noop

/-- Erase proof content from a SheetDiagram, keeping structure and labels. -/
def erase : SheetDiagram st Γ Δs → Pipeline
  | .arrow a                  => eraseArrow a
  | .pipe a s                 => .seq (eraseArrow a) (erase s)
  | .branch _ _ _ l r         => .branch (erase l) (erase r)
  | .join s                   => .join (erase s)
  | .halt                     => .halt
  | .scope label _ _ _ _ s    => .scope label (erase s)

/-- The clinical pipeline with all proof content erased. -/
def clinicalPipeline : Pipeline := erase JoseExample.scopedClinicalPipeline

/-- Indented string representation for pretty-printing. -/
partial def Pipeline.format (p : Pipeline) (indent : Nat) : String :=
  let pad := String.mk (List.replicate (indent * 2) ' ')
  match p with
  | .step name    => s!"{pad}step {name}"
  | .seq a b      => s!"{pad}seq\n{a.format (indent + 1)}\n{b.format (indent + 1)}"
  | .par a b      => s!"{pad}par\n{a.format (indent + 1)}\n{b.format (indent + 1)}"
  | .branch l r   => s!"{pad}branch\n{l.format (indent + 1)}\n{r.format (indent + 1)}"
  | .scope lbl b  => s!"{pad}scope {lbl}\n{b.format (indent + 1)}"
  | .join s       => s!"{pad}join\n{s.format (indent + 1)}"
  | .halt         => s!"{pad}halt"
  | .noop         => s!"{pad}noop"

instance : ToString Pipeline where
  toString p := p.format 0

#eval toString clinicalPipeline

end Erased
