/-
  WorldModel.KB.Arrow.Selection
  Additive context selection for branching.

  Unlike `Split` (which partitions — each element goes to exactly one side),
  `Selection` *picks* elements from a context.  Duplication across different
  selections is permitted because only one branch executes at runtime.
  This is the additive (⊕) counterpart to Split's multiplicative (⊗) role.
-/
import WorldModel.KB.Arrow.Context

/-- Additive selection: each element of `Δ` is witnessed in `Γ`.
    Multiple selections from the same `Γ` may overlap. -/
inductive Selection : Ctx → Ctx → Type 1 where
  | nil  : Selection Γ []
  | cons : Elem α Γ → Selection Γ Δ → Selection Γ (α :: Δ)

/-- Weaken a selection by prepending a new element to the source context. -/
def Selection.weaken : Selection Γ Δ → Selection (β :: Γ) Δ
  | .nil       => .nil
  | .cons e s  => .cons (.there e) s.weaken

/-- Identity selection: select everything in order. -/
def Selection.id : (Γ : Ctx) → Selection Γ Γ
  | []     => .nil
  | _ :: Γ => .cons .here (Selection.id Γ).weaken
