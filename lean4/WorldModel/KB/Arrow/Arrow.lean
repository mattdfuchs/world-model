/-
  WorldModel.KB.Arrow.Arrow
  Indexed arrow as the free symmetric monoidal category on steps.

  An `Arrow Γ Δ` transforms context `Γ` into context `Δ`.  Composition
  is represented syntactically — `seq`, `par`, `swap`, and `id` are
  constructors, not derived definitions.  This eliminates all `sorry`s:
  the type checker enforces that contexts thread correctly by construction.

  Each leaf (`step`) carries:
    1. A `Spec` declaring inputs/outputs
    2. A `Satisfy` proof that the required inputs exist in `Γ`
    3. A frame (the untouched portion of `Γ`)

  The result context is `frame ++ spec.produces`.
-/
import WorldModel.KB.Arrow.Spec

/-- Proof that a telescope's types can all be found in context `Γ`.
    The third parameter is the frame — the portion of the context not
    consumed.  In the current (no-consumption) model, `frame = Γ`. -/
inductive Satisfy : Tel → Ctx → Ctx → Type 1 where
  | nil  : Satisfy .nil Γ Γ
  | bind : (a : A) → Elem A Γ → Satisfy (t a) Γ frame → Satisfy (.cons A t) Γ frame

/-- An arrow from context `Γ` to context `Δ`, forming the free symmetric
    monoidal category on specification steps.

    - `step`: a single specification with evidence its inputs are in `Γ`
    - `seq`:  sequential composition (threading contexts)
    - `par`:  parallel composition (independent arrows side by side)
    - `id`:   identity (pass everything through)
    - `swap`: symmetric monoidal braiding (exchange two context halves) -/
inductive Arrow : Ctx → Ctx → Type 1 where
  | step : (spec : Spec) → (frame : Ctx)
           → Satisfy spec.inputs Γ frame
           → Arrow Γ (frame ++ spec.produces)
  | seq  : Arrow Γ Δ → Arrow Δ Ε → Arrow Γ Ε
  | par  : Arrow Γ₁ Δ₁ → Arrow Γ₂ Δ₂ → Arrow (Γ₁ ++ Γ₂) (Δ₁ ++ Δ₂)
  | id   : Arrow Γ Γ
  | swap : Arrow (Γ₁ ++ Γ₂) (Γ₂ ++ Γ₁)

/-- Build an arrow from flat input/output lists and a satisfaction proof. -/
def mkArrow {Γ : Ctx} (name : String) (inputs produces : Ctx)
    (satisfy : Satisfy (Tel.ofList inputs) Γ Γ)
    : Arrow Γ (Γ ++ produces) :=
  .step
    { name := name, inputs := Tel.ofList inputs, consumes := [], produces := produces }
    Γ
    satisfy

-- ── Notation ────────────────────────────────────────────────────────────────────

infixl:50 " ⟫ " => Arrow.seq
infixl:60 " ⊗ " => Arrow.par
