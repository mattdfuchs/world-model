/-
  WorldModel.KB.Arrow.SheetDiagram
  Coproduct of indexed monads — branching between Arrow sheets.

  A `SheetDiagram Γ Δs` transforms input context `Γ` into one of several
  possible output contexts `Δs : List Ctx`.  Each leaf sheet is a plain
  Arrow (the monoidal ⊗ world); branching (⊕) lives here, between sheets.

  Key constructors:
  - `arrow`:  wrap a single Arrow as a one-outcome sheet
  - `pipe`:   sequential composition (Arrow then SheetDiagram)
  - `branch`: split context and route to two sub-diagrams
  - `join`:   merge two identical outcome contexts into one
-/
import WorldModel.KB.Arrow.Arrow
import WorldModel.KB.Arrow.Selection

/-- A sheet diagram from input context `Γ` to a coproduct of output contexts `Δs`.
    - `arrow`: a single Arrow, producing exactly one outcome
    - `pipe`:  run an Arrow, then continue with a SheetDiagram
    - `branch`: split the context (multiplicatively), select into each branch
                (additively), and run sub-diagrams; outcomes are concatenated
    - `join`:  collapse two identical adjacent outcomes into one -/
inductive SheetDiagram : Ctx → List Ctx → Type 1 where
  | arrow : Arrow Γ Δ → SheetDiagram Γ [Δ]
  | pipe  : Arrow Γ Δ → SheetDiagram Δ Εs → SheetDiagram Γ Εs
  | branch
      : (split : Split Γ Γ_branch Γ_par)
      → (sel₁  : Selection Γ_branch Γ₁)
      → (sel₂  : Selection Γ_branch Γ₂)
      → (left  : SheetDiagram (Γ₁ ++ Γ_par) Δs₁)
      → (right : SheetDiagram (Γ₂ ++ Γ_par) Δs₂)
      → SheetDiagram Γ (Δs₁ ++ Δs₂)
  | join  : SheetDiagram Γ (Δ :: Δ :: rest) → SheetDiagram Γ (Δ :: rest)
  | halt  : SheetDiagram Γ []
  | scope : (ext : Ctx)
           → SheetDiagram (ext ++ Γ) (Δs.map (ext ++ ·))
           → SheetDiagram Γ Δs
