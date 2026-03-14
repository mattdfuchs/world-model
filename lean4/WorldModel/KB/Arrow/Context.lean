/-
  WorldModel.KB.Arrow.Context
  Contexts, membership, and splitting for the indexed arrow system.

  A context (`Ctx`) is a list of types representing available objects.
  `Elem` witnesses membership, `Split` witnesses a partition into two halves.
  All live in `Type 1` (not `Prop`) so we can compute with them at runtime.
-/

/-- A context is a list of types representing available typed objects. -/
abbrev Ctx := List Type

/-- De Bruijn-style membership proof: `Elem α Γ` witnesses that `α` appears in `Γ`. -/
inductive Elem : Type → Ctx → Type 1 where
  | here  : Elem α (α :: Γ)
  | there : Elem α Γ → Elem α (β :: Γ)

/-- Multiset split: each element of `Γ` goes to exactly one of `Δ₁` or `Δ₂`.
    This is the structural separating conjunction from separation logic. -/
inductive Split : Ctx → Ctx → Ctx → Type 1 where
  | nil   : Split [] [] []
  | left  : Split Γ Δ₁ Δ₂ → Split (α :: Γ) (α :: Δ₁) Δ₂
  | right : Split Γ Δ₁ Δ₂ → Split (α :: Γ) Δ₁ (α :: Δ₂)

/-- Split is symmetric: swap the two halves. -/
def Split.comm : Split Γ Δ₁ Δ₂ → Split Γ Δ₂ Δ₁
  | .nil     => .nil
  | .left s  => .right s.comm
  | .right s => .left s.comm

/-- Identity split: everything goes to the right half. -/
def Split.idRight : (Γ : Ctx) → Split Γ [] Γ
  | []     => .nil
  | _ :: Γ => .right (Split.idRight Γ)

/-- Identity split: everything goes to the left half. -/
def Split.idLeft : (Γ : Ctx) → Split Γ Γ []
  | []     => .nil
  | _ :: Γ => .left (Split.idLeft Γ)

/-- Split an append into its two components: `Γ₁ ++ Γ₂` splits into `Γ₁` and `Γ₂`. -/
def Split.append : (Γ₁ Γ₂ : Ctx) → Split (Γ₁ ++ Γ₂) Γ₁ Γ₂
  | [],     Γ₂ => Split.idRight Γ₂
  | _ :: Γ₁, Γ₂ => .left (Split.append Γ₁ Γ₂)

/-- Weaken an `Elem` proof by appending on the right. -/
def Elem.appendRight (e : Elem α Γ₁) (Γ₂ : Ctx) : Elem α (Γ₁ ++ Γ₂) :=
  match e with
  | .here    => .here
  | .there e => .there (e.appendRight Γ₂)

/-- Weaken an `Elem` proof by appending on the left. -/
def Elem.appendLeft : (Γ₁ : Ctx) → Elem α Γ₂ → Elem α (Γ₁ ++ Γ₂)
  | [],      e => e
  | _ :: Γ₁, e => .there (Elem.appendLeft Γ₁ e)

/-- Tactic that resolves `Elem α Γ` goals automatically by searching
    through the context list. Eliminates manual de Bruijn index counting. -/
syntax "elem_tac" : tactic
macro_rules
  | `(tactic| elem_tac) =>
    `(tactic| first | exact .here | (apply Elem.there; elem_tac))
