/-
  WorldModel.KB.Arrow.SheetDiagram
  Coproduct of indexed monads — branching between Arrow sheets.

  A `SheetDiagram st_in Γ st_out Δs` transforms input context `Γ` into one of
  several possible output contexts `Δs : List Ctx`, threading scope state from
  `st_in` to `st_out`.

  Key constructors:
  - `arrow`:  wrap a single Arrow as a one-outcome sheet
  - `pipe`:   sequential composition (Arrow then SheetDiagram)
  - `seq`:    sequential composition (SheetDiagram then SheetDiagram)
  - `branch`: split context and route to two sub-diagrams
  - `join`:   merge two identical outcome contexts into one
  - `scope`:  push new items onto the scope state, extend context by `ext`,
              reclaim `kept` at exit, and require proof obligations
  - `mutate`: change scope state without changing context
  - `cup`:    create a conserved resource and its dual (ε → A ⊗ A*)
  - `cap`:    cancel a resource/dual pair via Split (A ⊗ A* → ε)
-/
import WorldModel.KB.Arrow.Arrow
import WorldModel.KB.Arrow.Selection
import WorldModel.KB.Arrow.Scope

/-- A sheet diagram from input context `Γ` to a coproduct of output contexts `Δs`,
    threading scope state from `st_in` to `st_out`.
    - `arrow`:  a single Arrow, producing exactly one outcome (state unchanged)
    - `pipe`:   run an Arrow, then continue with a SheetDiagram
    - `seq`:    compose two SheetDiagrams (first must produce exactly one outcome)
    - `branch`: split the context (multiplicatively), select into each branch
                (additively), and run sub-diagrams; outcomes are concatenated
    - `join`:   collapse two identical adjacent outcomes into one
    - `scope`:  push `newItems` onto scope stack, extend context by `ext`,
                reclaim `kept` at exit; `ext ≠ kept` allows resource transformation
    - `mutate`: change scope state, identity on context
    - `cup`:    create a complementary pair from nothing (ε → A ⊗ A*);
                for `Dual` resources only; maps to (νk) in DLπ compilation
    - `cap`:    find and remove a (resource, dual) pair via `Split`;
                evidence is flexible (a need not match cup's type);
                maps to communication/closure in DLπ compilation -/
inductive SheetDiagram : ScopeState → Ctx → ScopeState → List Ctx → Type 1 where
  | arrow : Arrow Γ Δ → SheetDiagram st Γ st [Δ]
  | pipe  : Arrow Γ Δ → SheetDiagram st Δ st' Εs → SheetDiagram st Γ st' Εs

  | seq   : SheetDiagram st Γ st' [Δ]
           → SheetDiagram st' Δ st'' Εs
           → SheetDiagram st Γ st'' Εs

  | branch
      : (split : Split Γ Γ_branch Γ_par)
      → (sel₁  : Selection Γ_branch Γ₁)
      → (sel₂  : Selection Γ_branch Γ₂)
      → (left  : SheetDiagram st (Γ₁ ++ Γ_par) st' Δs₁)
      → (right : SheetDiagram st (Γ₂ ++ Γ_par) st' Δs₂)
      → SheetDiagram st Γ st' (Δs₁ ++ Δs₂)

  | join  : SheetDiagram st Γ st' (Δ :: Δ :: rest) → SheetDiagram st Γ st' (Δ :: rest)
  | halt  : SheetDiagram st Γ st []

  | scope : (label : String)
           → (newItems : List ScopeItem)
           → (ext : Ctx)
           → (kept : Ctx)
           → (st_out : ScopeState)
           → (obligations : List Type)
           → AllObligations obligations
           → SheetDiagram (newItems ++ st_in) (ext ++ Γ)
                           st_inner (Δs.map (kept ++ ·))
           → SheetDiagram st_in Γ st_out Δs

  | mutate : (st' : ScopeState) → SheetDiagram st Γ st' [Γ]

  | cup : (label : String) → (a : Type) → (a_star : Type)
          → SheetDiagram st Γ st [a :: a_star :: Γ]

  | cap : (label : String) → (a : Type) → (a_star : Type)
          → Split Γ [a, a_star] Γ'
          → SheetDiagram st Γ st [Γ']
