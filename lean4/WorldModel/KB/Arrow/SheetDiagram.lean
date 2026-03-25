/-
  WorldModel.KB.Arrow.SheetDiagram
  Coproduct of indexed monads — branching between Arrow sheets.

  A `SheetDiagram st Γ Δs` transforms input context `Γ` into one of several
  possible output contexts `Δs : List Ctx`, under scope state `st : ScopeState`.

  Key constructors:
  - `arrow`:  wrap a single Arrow as a one-outcome sheet
  - `pipe`:   sequential composition (Arrow then SheetDiagram)
  - `branch`: split context and route to two sub-diagrams
  - `join`:   merge two identical outcome contexts into one
  - `scope`:  push new items onto the scope state, extend the context,
              and require proof obligations computed from constraints
-/
import WorldModel.KB.Arrow.Arrow
import WorldModel.KB.Arrow.Selection
import WorldModel.KB.Arrow.Scope

/-- A sheet diagram from input context `Γ` to a coproduct of output contexts `Δs`,
    under scope state `st`.
    - `arrow`: a single Arrow, producing exactly one outcome
    - `pipe`:  run an Arrow, then continue with a SheetDiagram
    - `branch`: split the context (multiplicatively), select into each branch
                (additively), and run sub-diagrams; outcomes are concatenated
    - `join`:  collapse two identical adjacent outcomes into one
    - `scope`: push `newItems` onto the scope stack, extend context by `ext`,
               require `AllObligations obligations` as evidence -/
inductive SheetDiagram : ScopeState → Ctx → List Ctx → Type 1 where
  | arrow : Arrow Γ Δ → SheetDiagram st Γ [Δ]
  | pipe  : Arrow Γ Δ → SheetDiagram st Δ Εs → SheetDiagram st Γ Εs
  | branch
      : (split : Split Γ Γ_branch Γ_par)
      → (sel₁  : Selection Γ_branch Γ₁)
      → (sel₂  : Selection Γ_branch Γ₂)
      → (left  : SheetDiagram st (Γ₁ ++ Γ_par) Δs₁)
      → (right : SheetDiagram st (Γ₂ ++ Γ_par) Δs₂)
      → SheetDiagram st Γ (Δs₁ ++ Δs₂)
  | join  : SheetDiagram st Γ (Δ :: Δ :: rest) → SheetDiagram st Γ (Δ :: rest)
  | halt  : SheetDiagram st Γ []
  | scope : (label : String)
           → (newItems : List ScopeItem)
           → (ext : Ctx)
           → (obligations : List Type)
           → AllObligations obligations
           → SheetDiagram (newItems ++ st) (ext ++ Γ) (Δs.map (ext ++ ·))
           → SheetDiagram st Γ Δs
