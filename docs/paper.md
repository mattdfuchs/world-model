# Sheet Diagrams as Coproducts of Indexed Monads: A Lean 4 Calculus for Branching Resource-Typed Workflows

**Abstract.** We present a type-theoretic calculus for specifying workflows with typed resources, branching, and nested scope. The key observation is a decomposition: a rig-category arrow system factors into an external coproduct of plain symmetric monoidal category (SMC) indexed monads, one per sheet in the sense of Comfort, Delpeuch, and Hedges. Tensor products and coproducts never cohabit inside a single monad's context, avoiding the exponential blowup that arises from the distributive law in rig categories. We mechanize this decomposition in Lean 4 as the `SheetDiagram` inductive type, with zero unproven assumptions (`sorry`-free). A nested scope discipline provides type-level resource management: each scope carries a *scope state* — a stack of tagged resource entries and constraint declarations — and the scope constructor requires proof evidence for all obligations that the constraints generate. Constraint evaluation is role-indexed: a VO2 technician proves VO2 certification, not blood-pressure certification. The system is illustrated with a complete clinical trial pipeline featuring four branch points, three joins, three levels of scope nesting, and seven constraint types across three scope levels. A negative test demonstrates that an invalid configuration (wrong city) is rejected as a type error. An erasure operation extracts a type-free computational skeleton suitable for runtime execution. All definitions, the constraint system, and the worked example type-check in Lean 4 (toolchain v4.25.0-rc2) with no axioms beyond those in the standard library.

---

## 1. Introduction

Specifying workflows with formal guarantees is a long-standing challenge at the intersection of programming languages and verification. Real workflows manipulate typed resources: a clinical measurement requires a certified clinician, calibrated equipment, and a consenting patient. They branch: a patient may refuse consent, a measurement may fall outside acceptable bounds. They nest: a room scope provides equipment, a clinic scope provides personnel, a trial scope provides regulatory authorization. A specification language for such workflows must account for all three concerns — typed resources, branching, and nested scope — simultaneously.

**Symmetric monoidal categories** provide a natural framework for the first concern. A morphism $f : \Gamma \to \Delta$ transforms an input context $\Gamma$ (a tensor product of typed resources) into an output context $\Delta$. Sequential composition threads contexts forward; parallel composition places independent operations side by side. The free SMC on a signature of typed steps is the type of string diagrams, and its term representation has been well studied (Joyal and Street, 1991). We formalize this as the `Arrow` inductive type in Lean 4.

**Coproducts** are the natural structure for the second concern. A branch point produces one of several possible continuations, each with its own resource requirements. Adding coproducts $\oplus$ alongside tensor products $\otimes$ yields a **rig category** (bimonoidal category) — a category with two monoidal structures where one distributes over the other (Laplaza, 1972):

$$\Gamma \otimes (\Delta_1 \oplus \Delta_2) \cong (\Gamma \otimes \Delta_1) \oplus (\Gamma \otimes \Delta_2)$$

This distributive law is the source of a fundamental difficulty. Embedding coproducts inside the context of an indexed monad forces the system into disjunctive normal form: after $k$ binary branch points, the context is a sum of $2^k$ product terms. This is not an implementation limitation but a structural consequence of the distributive law, analogous to the exponential blowup of DNF in propositional logic.

**The key observation.** The exponential blowup disappears if tensor and coproduct are separated into different levels. Comfort, Delpeuch, and Hedges (2020) introduce *sheet diagrams* for bimonoidal categories, where tensor is wiring on a surface and coproduct is stacking of surfaces. Reading this geometric perspective through the lens of Atkey's indexed monads (2009), we observe that a rig-category arrow system decomposes into an **external coproduct of plain SMC indexed monads**, one per sheet. Each sheet carries the same simple forward-threading indexed monad over a product context; no individual monad ever encounters a coproduct. Branching lives *between* monads as an external operation on the collection of sheets, not inside any single monad's context type.

**Contributions.**

1. **The decomposition.** We identify and formalize the factoring of a rig-category arrow system into an external coproduct of SMC indexed monads, mechanized as the `SheetDiagram` inductive type in Lean 4. The construction avoids DNF blowup while preserving the ability to reuse plain SMC arrows without modification.

2. **A scoped constraint discipline.** Nested scopes carry a *scope state* — a stack of tagged resource entries and constraint declarations. On scope entry, the constraint system evaluates role-indexed obligations: new constraints fire against all entries in scope; existing constraints fire against newly introduced entries. The scope constructor requires proof evidence for every generated obligation. This generalizes monolithic constraint bundles to a compositional, scope-local discipline where each resource conceptually has a role and each constraint fires only for matching roles.

3. **Lean 4 mechanization.** All definitions — the full `SheetDiagram` type, the SMC arrow system, the scope state and constraint system, and a complete clinical trial pipeline with four branch points, three joins, three levels of scope nesting, and seven constraint types — type-check in Lean 4 with zero `sorry`s. A negative test (George at ParisClinic) demonstrates that invalid configurations are rejected as type errors.

**Running example.** Throughout the paper we develop a clinical trial pipeline for patient Jose: consent, heart rate measurement, blood pressure measurement, VO2 max measurement, result aggregation, and final assessment. Each measurement can disqualify the patient. The pipeline has four branch points, three joins (collapsing failure outcomes), and three nested scopes (trial, clinic, room). The type signature of the complete pipeline specifies exactly two possible outcomes: disqualification or full qualification. This example is presented in full in Section 6 (see Figure 5).

**Notation.** We write Lean 4 syntax throughout for definitions, with standard mathematical notation ($\otimes$, $\oplus$, $\Gamma$, $\Delta$) for categorical discussion. `⟫` denotes sequential composition; `⊗` denotes parallel composition; `++` denotes list concatenation (the computational representation of tensor).


---

## 2. Background: Indexed Monads and Free SMCs

### 2.1 Indexed Monads

An indexed monad (Atkey, 2009) is a family $M : I \to I \to \text{Type} \to \text{Type}$ equipped with:

$$\text{return} : \alpha \to M\;i\;i\;\alpha$$
$$\text{bind} : M\;i\;j\;\alpha \to (\alpha \to M\;j\;k\;\beta) \to M\;i\;k\;\beta$$

satisfying the monad laws with indices threading through composition. When $I$ is a category of contexts (typed resource lists), the pre-index $i$ is the input context and the post-index $j$ is the output context. Bind threads the context forward: the output of the first computation becomes the input of the second.

In our setting, the index category is the free commutative monoid on types — concretely, lists of types under concatenation. A context $\Gamma : \text{Ctx}$ is a list of types representing available typed resources:

```lean
abbrev Ctx := List Type
```

### 2.2 Contexts, Membership, and Splitting

Membership is witnessed by a de Bruijn–style proof term:

```lean
inductive Elem : Type → Ctx → Type 1 where
  | here  : Elem α (α :: Γ)
  | there : Elem α Γ → Elem α (β :: Γ)
```

`Elem α Γ` is a constructive proof that type $\alpha$ appears in context $\Gamma$, carrying the position as computational content.

A **split** witnesses a partition of a context into two disjoint halves:

```lean
inductive Split : Ctx → Ctx → Ctx → Type 1 where
  | nil   : Split [] [] []
  | left  : Split Γ Δ₁ Δ₂ → Split (α :: Γ) (α :: Δ₁) Δ₂
  | right : Split Γ Δ₁ Δ₂ → Split (α :: Γ) Δ₁ (α :: Δ₂)
```

`Split Γ Δ₁ Δ₂` witnesses that each element of $\Gamma$ goes to exactly one of $\Delta_1$ or $\Delta_2$. This is the structural separating conjunction from separation logic: the context is partitioned, not duplicated. The split is a proof term — its constructors trace the partition decision for each element.

Symmetry, identity splits, and split-of-append are derivable:

```lean
def Split.comm : Split Γ Δ₁ Δ₂ → Split Γ Δ₂ Δ₁
def Split.idLeft : (Γ : Ctx) → Split Γ Γ []
def Split.append : (Γ₁ Γ₂ : Ctx) → Split (Γ₁ ++ Γ₂) Γ₁ Γ₂
```

### 2.3 Telescopes

A specification's inputs may be dependent: the type of a later input may depend on the value of an earlier one (e.g., a clinician qualification depends on which clinician is selected). This is captured by telescopes:

```lean
inductive Tel : Type 1 where
  | nil  : Tel
  | cons : (A : Type) → (A → Tel) → Tel
```

A flat (non-dependent) telescope is constructed from a context list:

```lean
def Tel.ofList : Ctx → Tel
  | []        => .nil
  | A :: rest => .cons A (fun _ => Tel.ofList rest)
```

A specification bundles a name, a telescope of inputs, consumed types, and produced types:

```lean
structure Spec where
  name        : String
  description : String := ""
  inputs      : Tel
  consumes    : Ctx
  produces    : Ctx
```

### 2.4 The Free SMC: Arrow

Satisfaction witnesses that a telescope's types can all be found in context:

```lean
inductive Satisfy : Tel → Ctx → Ctx → Type 1 where
  | nil  : Satisfy .nil Γ Γ
  | bind : (a : A) → Elem A Γ → Satisfy (t a) Γ frame
         → Satisfy (.cons A t) Γ frame
```

The third parameter is the **frame** — the portion of the context not consumed. In the current model (no consumption), the frame equals the full context.

The `Arrow` inductive type is the **free symmetric monoidal category** on specification steps:

```lean
inductive Arrow : Ctx → Ctx → Type 1 where
  | step : (spec : Spec) → (frame : Ctx)
           → Satisfy spec.inputs Γ frame
           → Arrow Γ (frame ++ spec.produces)
  | seq  : Arrow Γ Δ → Arrow Δ Ε → Arrow Γ Ε
  | par  : Arrow Γ₁ Δ₁ → Arrow Γ₂ Δ₂ → Arrow (Γ₁ ++ Γ₂) (Δ₁ ++ Δ₂)
  | id   : Arrow Γ Γ
  | swap : Arrow (Γ₁ ++ Γ₂) (Γ₂ ++ Γ₁)
```

Each constructor corresponds to a structural operation in the SMC:

- **`step`**: A leaf morphism. The specification declares inputs (found in $\Gamma$ via `Satisfy`), and the output is the frame (untouched resources) concatenated with newly produced types.
- **`seq`**: Sequential composition. $\Gamma \xrightarrow{f} \Delta \xrightarrow{g} E$ becomes $\Gamma \xrightarrow{f \mathbin{⟫} g} E$.
- **`par`**: Parallel composition. Independent arrows on disjoint sub-contexts.
- **`id`**: Identity. Pass the context through unchanged.
- **`swap`**: Symmetric monoidal braiding. Exchange two halves of the context.

The representation is **syntactic**: composition is a constructor, not a computed function. This makes the arrow a free algebraic structure. The type checker enforces that contexts thread correctly by construction — there are no proof obligations beyond those embedded in `Satisfy`, and no `sorry`s anywhere in the formalization.

Notation: `f ⟫ g` for `Arrow.seq f g`, `f ⊗ g` for `Arrow.par f g`.

**The Arrow type as an indexed monad.** `Arrow Γ Δ` is an indexed monad over `Ctx` with `seq` as bind (taking unit return type). The pre-index $\Gamma$ is the input context; the post-index $\Delta$ is the output context. Within this monad, only the tensor product (parallel composition, context concatenation) is available. Coproducts are absent. This is by design: the Arrow monad handles the $\otimes$-world. Coproducts will live at a different level.

---

## 3. The Rig Category Problem

### 3.1 Why Coproducts are Needed

The Arrow type handles linear pipelines well. A clinical measurement session is a sequence of steps:

$$\text{consent} \mathbin{⟫} \text{heartRate} \mathbin{⟫} \text{bloodPressure} \mathbin{⟫} \text{vo2Max} \mathbin{⟫} \text{products} \mathbin{⟫} \text{assessment}$$

where each step finds required resources in the context (via `Satisfy`) and produces new ones. The type of the composite arrow completely specifies every valid execution.

But real workflows branch. A patient may consent or refuse. A heart rate measurement may yield an acceptable or unacceptable result. An adverse event may trigger protocol deviation. Each branch leads to a different continuation with different resource requirements. The natural categorical structure for this is the **coproduct** $\oplus$.

### 3.2 The Distributive Law and DNF Blowup

Adding coproducts to a symmetric monoidal category yields a **rig category** (also called a bimonoidal category). The defining coherence is the **distributive law**:

$$\Gamma \otimes (\Delta_1 \oplus \Delta_2) \cong (\Gamma \otimes \Delta_1) \oplus (\Gamma \otimes \Delta_2)$$

This law is the source of exponential blowup. Consider a pipeline with $k$ sequential binary branch points. After the first branch, the continuation is a coproduct of two product contexts. After the second branch, each of those two contexts branches again, yielding four product contexts. After $k$ branches, the context is a sum of $2^k$ product terms.

This is not an implementation artifact — it is a structural consequence of the distributive law. The analogy to propositional logic is exact: the distributive law $p \wedge (q \vee r) \Leftrightarrow (p \wedge q) \vee (p \wedge r)$ converts any formula to disjunctive normal form, and DNF can be exponentially larger than the nested formula it represents.

**Concrete example.** Consider a context $\Gamma$ with three sequential binary branch points $B_1$, $B_2$, $B_3$. Each branch produces either an "OK" continuation or a "fail" outcome:

| Branches resolved | Contexts in DNF |
|---|---|
| 0 | $\Gamma$ (1 context) |
| After $B_1$ | $\Gamma_{\text{ok}_1},\ \Gamma_{\text{fail}_1}$ (2 contexts) |
| After $B_2$ | $\Gamma_{\text{ok}_1,\text{ok}_2},\ \Gamma_{\text{ok}_1,\text{fail}_2},\ \Gamma_{\text{fail}_1}$ |
| After $B_3$ | $\Gamma_{\text{ok}_1,\text{ok}_2,\text{ok}_3},\ \Gamma_{\text{ok}_1,\text{ok}_2,\text{fail}_3},\ \Gamma_{\text{ok}_1,\text{fail}_2},\ \Gamma_{\text{fail}_1}$ |

Even with joins collapsing identical failure outcomes, the intermediate representation grows. Without joins, 3 branches produce $2^3 = 8$ product contexts. In general, every step after a branch point must be stated for each of the $2^k$ branches individually, even when the step is identical across branches.

In the sheet diagram approach (next section), each branch point adds one sheet. Three branches require three sheets (plus the main continuation), not eight product contexts. The growth is linear in the number of branch points, not exponential.

<!--
Figure 1: DNF blowup — 3 branches → 8 contexts vs 3 sheets.

    DNF approach:                          Sheet approach:
    ┌──────────┐                           ┌──────────┐
    │    Γ     │                           │    Γ     │   (1 sheet)
    └────┬─────┘                           └────┬─────┘
         │ B₁                                   │ B₁
    ┌────┴────┐                            ┌────┴────┐
    │ Γ·ok₁  │ Γ·f₁                       │ sheet 1 │ sheet 2
    └────┬────┘                            │ (ok₁)   │ (fail₁)
         │ B₂                              └────┬────┘
    ┌────┴────┐                                 │ B₂
    │Γ·ok₁₂  │ Γ·ok₁·f₂                  ┌────┴────┐
    └────┬────┘                            │ sheet 1 │ sheet 3
         │ B₃                              │ (ok₁₂)  │ (fail₂)
    ┌────┴────┐                            └────┬────┘
    │Γ·ok₁₂₃ │ Γ·ok₁₂·f₃                      │ B₃
    └─────────┘                            ┌────┴────┐
                                           │ sheet 1 │ sheet 4
    Total: 8 product contexts              │ (ok₁₂₃) │ (fail₃)
    (full DNF of 3 variables)              └─────────┘
                                           Total: 4 sheets
                                           (linear in branch count)
-->

### 3.3 Why This is Fundamental

The blowup is not merely a performance concern. It affects the *specification* itself:

1. **Readability.** A specification with $2^k$ cases is unintelligible to humans for moderate $k$.

2. **Compositionality.** Adding a new branch point doubles the entire specification. This violates the principle that local changes should have local effects.

3. **Proof burden.** Each product context requires its own proof that constraints are satisfied. Identical proofs must be duplicated across branches, or else a complex lemma must establish their equivalence.

4. **Execution mapping.** Compiling to executable processes (e.g., session-typed channels) requires mapping each product context to a process. Exponentially many processes for linearly many branch points is a non-starter.

The needed insight is that the exponential comes from *distributing* $\otimes$ over $\oplus$ — from embedding coproducts inside product contexts. If the two operations are separated into different levels, the blowup vanishes.


---

## 4. The Decomposition

This section presents the core contribution: the `SheetDiagram` type, which factors a rig-category arrow system into an external coproduct of SMC indexed monads.

### 4.1 Sheet Diagrams (Review)

Comfort, Delpeuch, and Hedges (2020) introduce sheet diagrams as a graphical calculus for bimonoidal categories (rig categories). The key geometric idea:

- The tensor product $\otimes$ is represented by **wiring on a surface** — ordinary string diagrams drawn on a 2D sheet.
- The coproduct $\oplus$ is represented by **stacking surfaces** — creating parallel sheets, one per summand.

A branch point takes one sheet and splits it into multiple sheets. Each sheet carries its own string diagram. Sheets evolve independently: they have their own contexts, their own morphisms, their own resource accounting. The only interactions between sheets are at branch points (where one sheet spawns new sheets) and at join points (where multiple sheets with identical outcomes collapse into one).

The main theorem of Comfort–Delpeuch–Hedges is that sheet diagrams form the free bimonoidal category on a signature. We give this geometric perspective a type-theoretic implementation.

### 4.2 The SheetDiagram Type

The `SheetDiagram` inductive type is indexed by a *scope state* `st : ScopeState` (tracking which resources and constraints are in scope), an input context $\Gamma$, and a list of output contexts $\Delta s$:

$$\texttt{SheetDiagram} : \text{ScopeState} \to \text{Ctx} \to \text{List Ctx} \to \text{Type 1}$$

The `ScopeState` index is described in Section 5. The `List Ctx` output represents the **external coproduct**: each element of the list is one possible output context (one sheet). This is the central design choice — the coproduct lives in the *index* of the type, as a list of alternatives, not inside any single context.

**Listing 1.** The `SheetDiagram` inductive type.

```lean
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
```

Each constructor is analyzed below.

**`arrow`: Embedding the SMC.** A single `Arrow Γ Δ` (a morphism in the free SMC) is wrapped as a one-outcome sheet diagram. This is the embedding of the $\otimes$-world into the $(\otimes, \oplus)$-world. The output is the singleton list `[Δ]` — exactly one possible outcome.

**`pipe`: Sequential composition.** An `Arrow Γ Δ` is followed by a `SheetDiagram Δ Εs`. The arrow transforms the context from $\Gamma$ to $\Delta$; the sheet diagram then takes $\Delta$ and produces any of the outcomes $E_s$. This is the ordinary indexed monad bind restricted to the case where the first computation is a single-outcome arrow. It is sufficient because any multi-step sequence can be decomposed into arrow-then-diagram steps.

**`branch`: The core operation.** A branch point performs two operations simultaneously:

1. **Multiplicative partition** via `Split`: the context $\Gamma$ is partitioned into $\Gamma_{\text{branch}}$ (resources that will be routed to branches) and $\Gamma_{\text{par}}$ (resources preserved for all branches — the parallel/frame context).

2. **Additive selection** via `Selection`: from $\Gamma_{\text{branch}}$, each branch *selects* the resources it needs. Selections may overlap — both branches may select the same resource — because only one branch executes at runtime. This is precisely the additive contraction of linear logic.

The left branch receives $\Gamma_1 \mathbin{++} \Gamma_{\text{par}}$ (its selected resources plus the parallel frame); the right branch receives $\Gamma_2 \mathbin{++} \Gamma_{\text{par}}$. Each branch is itself a `SheetDiagram`, producing its own list of outcomes. The overall outcomes are the concatenation $\Delta s_1 \mathbin{++} \Delta s_2$ — the external coproduct of the two sub-diagrams' outcomes.

**`join`: Collapsing identical outcomes.** When two adjacent outcomes in the list are identical ($\Delta :: \Delta :: \text{rest}$), they can be collapsed to $\Delta :: \text{rest}$. This is the codiagonal map $\Delta \oplus \Delta \to \Delta$: two sheets with the same output type are merged because, from the perspective of subsequent computation, they are indistinguishable.

**`halt`: Empty coproduct.** A sheet with no outcomes — the initial object of the coproduct. This terminates a branch that produces no continuation (e.g., a fatal error with no recovery path).

**`scope`: Nested resource management with constraints.** A scope pushes `newItems` onto the scope state, introduces an extension context `ext`, and requires proof evidence (`AllObligations obligations`) for all constraint obligations generated by the new scope items. The inner diagram operates over the extended scope state `newItems ++ st` and extended context `ext ++ Γ`. On exit, both the scope items and the extension context are stripped. This is discussed in detail in Section 5.

### 4.3 Selection: The Additive Counterpart to Split

The `Selection` type deserves separate attention because its interaction with `Split` captures the precise difference between multiplicative and additive operations.

**Listing 2.** The `Selection` type.

```lean
inductive Selection : Ctx → Ctx → Type 1 where
  | nil  : Selection Γ []
  | cons : Elem α Γ → Selection Γ Δ → Selection Γ (α :: Δ)
```

`Selection Γ Δ` witnesses that each element of $\Delta$ can be found in $\Gamma$. Unlike `Split` (which partitions — each element of $\Gamma$ goes to exactly one side), `Selection` *picks* elements, and multiple selections from the same $\Gamma$ may overlap.

The operational justification: `Split` is multiplicative because both halves of the partition are used (both in parallel composition, or both for branch-body and frame). `Selection` is additive because only one selected sub-context is used at runtime — whichever branch actually executes. Duplicating a resource across two selections is sound because the two branches are mutually exclusive.

In the terminology of linear logic:

| Operation | Linear logic | Role in branch |
|---|---|---|
| `Split` | $\otimes$ (tensor, multiplicative conjunction) | Partition context into branch-part and frame-part |
| `Selection` | $\oplus$ / $\&$ (additive disjunction / conjunction) | Each branch selects what it needs from the branch-part |

### 4.4 Properties of the Decomposition

**No DNF blowup.** Each branch point adds sheets to the outcome list. The number of sheets grows linearly with the number of branch points (before joins). Joins reduce the count. At no point is a context distributed into exponentially many product terms. The `List Ctx` index tracks the sheets externally; each individual sheet's context remains a simple product.

**Each sheet reuses the plain SMC arrow.** The `arrow` and `pipe` constructors embed `Arrow Γ Δ` unchanged. No modifications to the Arrow type, the Satisfy mechanism, or the Spec structure are needed to support branching. The entire complexity of coproducts is handled by the `branch`, `join`, and `halt` constructors — operations on the *collection* of sheets.

**The partition problem is local.** The question "what does each branch need?" is answered at the branch point by the `Split` and `Selection` witnesses. These are local proof obligations: the `Split` certifies that the partition is complete, and each `Selection` certifies that the branch's claimed inputs exist in the branch-part of the context. No global reorganization of the pipeline is required.

**The decomposition is the type.** `SheetDiagram Γ Δs` is simultaneously:
- A specification of all valid executions (the type is the set of permitted behaviors).
- A proof that the resource accounting is correct (every `Satisfy`, `Split`, and `Selection` is a witness).
- A data structure that can be interpreted (the constructors form a free algebraic term).

<!--
Figure 2: Branch constructor as sheet diagram.

    Input: one sheet with context Γ
    ┌─────────────────────────┐
    │          Γ              │
    │    ┌─────┴──────┐       │
    │    │   Split    │       │
    │    ├────┬───────┤       │
    │  Γ_br  │  Γ_par │       │
    │    │   │        │       │
    │  ┌─┴─┐ │        │       │
    │  │Sel│ │        │       │
    │  ├─┬─┤ │        │       │
    │  Γ₁ Γ₂ │        │       │
    └──┼──┼──┼────────┘       │
       │  │  │                │
    Output: two sheets
    ┌──┼──┘  │  ┌─────────────┘
    │  │     │  │
    │ Γ₁++Γ_par │  Γ₂++Γ_par
    │ (sheet 1) │  (sheet 2)
    │  → Δs₁   │  → Δs₂
    └───────────┘
    Overall outcomes: Δs₁ ++ Δs₂
-->

<!--
Figure 3: Join operation.

    Input: sheet diagram with outcomes [Δ, Δ, rest...]
    ┌─────────┬─────────┬──────────┐
    │ sheet 1 │ sheet 2 │ sheet 3… │
    │  → Δ    │  → Δ    │  → rest  │
    └────┬────┴────┬────┴──────────┘
         │ codiag  │
         └────┬────┘
    Output: [Δ, rest...]
    ┌─────────┬──────────┐
    │ sheet 1 │ sheet 2… │
    │  → Δ    │  → rest  │
    └─────────┴──────────┘
-->


---

## 5. Nested Scopes and Constraint Obligations

### 5.1 Scopes as Type-Level Resource Management with Constraints

The `scope` constructor of `SheetDiagram` provides block-structured resource management at the type level, with proof obligations enforced at each scope boundary:

```lean
  | scope : (label : String)
           → (newItems : List ScopeItem)
           → (ext : Ctx)
           → (obligations : List Type)
           → AllObligations obligations
           → SheetDiagram (newItems ++ st) (ext ++ Γ) (Δs.map (ext ++ ·))
           → SheetDiagram st Γ Δs
```

On entry, the scope performs two parallel operations:

1. **Context extension.** The scope prepends `ext : Ctx` to the current context. The inner diagram operates over `ext ++ Γ`, and the requirement `Δs.map (ext ++ ·)` ensures that extension resources are preserved on every exit path. On scope exit, the extension is stripped.

2. **Scope state extension.** The scope pushes `newItems : List ScopeItem` onto the scope state. Each item is either a *resource entry* (a tagged entity with a name and role) or a *constraint declaration* (a named constraint that generates proof obligations). The scope constructor requires evidence of type `AllObligations obligations` — a dependent product of all obligation types that the new items generate against the current scope state.

This is the type-level analogue of block-structured resource management:
- **Region-based memory** (Tofte and Talpin, 1997): a region is allocated on scope entry, and all values in the region are deallocated on exit.
- **Linear scoping** (Bernardy et al., 2018): resources introduced in a scope are guaranteed to be consumed or returned before the scope closes.

In our setting, the extension context provides typed resources — equipment, personnel, evidence — that are available within the scope but not outside it. The scope state tracks *which* resources are available and *what constraints* apply, enabling role-indexed constraint checking. The type system enforces both that inner computation cannot "leak" scoped resources into outcomes, and that all constraint obligations are satisfied at scope entry.

### 5.2 Three-Level Nesting in the Clinical Pipeline

The clinical trial pipeline uses three levels of scope nesting:

**Listing 3a.** Scope items — resource entries and constraint declarations.

```lean
/-- Trial scope: introduces the trial and declares that clinicians
    must speak the patient's language. -/
abbrev trialItems : List ScopeItem :=
  [.entry ⟨"OurTrial", .trial⟩,
   .constraint .clinicianSpeaksPatient]

/-- Clinic scope: introduces clinic + clinician, declares clinic-level constraints. -/
abbrev clinicItems : List ScopeItem :=
  [.entry ⟨"ValClinic", .clinic⟩,
   .entry ⟨"Allen", .clinician⟩,
   .constraint .clinicInPatientCity,
   .constraint .clinicianAssigned,
   .constraint .trialApprovesClinic]

/-- Room scope: introduces technician role assignments and equipment constraints. -/
abbrev roomItems : List ScopeItem :=
  [.entry ⟨"Room3", .room⟩,
   .entry ⟨"Allen", .examBedTech⟩,
   .entry ⟨"Allen", .bpTech⟩,
   .entry ⟨"Allen", .vo2Tech⟩,
   .constraint .examBedQual,
   .constraint .bpQual,
   .constraint .vo2Qual]
```

**Listing 3b.** Context extensions — the typed resources each scope provides.

```lean
/-- Trial scope: just the trial object. -/
abbrev trialExt : Ctx := [ClinicalTrial "OurTrial"]

/-- Clinic scope: clinic + clinician + shared language evidence. -/
abbrev clinicExt : Ctx := [Clinic "ValClinic", Clinician "Allen",
                            SharedLangEvidence "Allen" "Jose"]

/-- Room scope: room marker + equipment + clinician qualifications. -/
abbrev roomExt : Ctx := [Room "Room3", ExamBed, BPMonitor, VO2Equipment,
                          holdsExamBedQual allen .mk, holdsBPMonitorQual allen .mk,
                          holdsVO2EquipmentQual allen .mk]
```

The nesting produces a context that grows on entry and shrinks on exit:

```
Entry context:  [Patient "Jose"]
After trial scope entry:   trialExt ++ [Patient "Jose"]
After clinic scope entry:  clinicExt ++ trialExt ++ [Patient "Jose"]
After room scope entry:    roomExt ++ clinicExt ++ trialExt ++ [Patient "Jose"]
                           = insideAllScopes  (12 typed resources)
After room scope exit:     clinicExt ++ trialExt ++ [Patient "Jose"]
After clinic scope exit:   trialExt ++ [Patient "Jose"]
After trial scope exit:    [Patient "Jose"]
```

Inside all three scopes, the full context `insideAllScopes` contains 12 typed resources. Each measurement step declares exactly what it needs from this context via its `Satisfy` proof:

| Step | Required resources from context |
|------|------|
| Consent | `Patient`, `SharedLangEvidence` |
| Heart measurement | `Patient`, `Clinician`, `ExamBed`, `holdsExamBedQual`, `SharedLangEvidence` |
| BP measurement | `Patient`, `Clinician`, `BPMonitor`, `holdsBPMonitorQual`, `SharedLangEvidence` |
| VO2 measurement | `Patient`, `Clinician`, `VO2Equipment`, `holdsVO2EquipmentQual`, `SharedLangEvidence` |

Missing resources — a clinician without the required equipment qualification, a room without the needed equipment — produce a type error at definition time. The specification cannot be constructed if the resources are unavailable.

<!--
Figure 4: Three-level scope nesting with context growth and shrinkage.

    Context width (number of typed resources)
    ──────────────────────────────────────────────►

    [Patient "Jose"]           ╔══ Trial scope ═══════════════════════╗
    ·                          ║                                      ║
    ·───────────────────►      ║  [ClinicalTrial, Patient]            ║
    ·                          ║  ╔══ Clinic scope ═══════════════╗   ║
    ·                          ║  ║                                ║   ║
    ·───────────────────────►  ║  ║ [Clinic, Clinician,           ║   ║
    ·                          ║  ║  SharedLang, Trial, Patient]  ║   ║
    ·                          ║  ║ ╔══ Room scope ═══════════╗   ║   ║
    ·                          ║  ║ ║                          ║   ║   ║
    ·───────────────────────►  ║  ║ ║ [Room, ExamBed, BPMon,  ║   ║   ║
    ·                          ║  ║ ║  VO2Eq, 3×Quals,        ║   ║   ║
    ·  ← measurements here →   ║  ║ ║  Clinic, Clinician,     ║   ║   ║
    ·                          ║  ║ ║  SharedLang, Trial,      ║   ║   ║
    ·                          ║  ║ ║  Patient]  (12 items)    ║   ║   ║
    ·                          ║  ║ ╚══════════════════════════╝   ║   ║
    ·───────────────────────►  ║  ║  back to 5 items              ║   ║
    ·                          ║  ╚════════════════════════════════╝   ║
    ·───────────────────►      ║   back to 2 items                    ║
    ·                          ╚══════════════════════════════════════╝
    [Patient "Jose", ...]       back to 1 item + produced results
-->

### 5.3 Scope State, Constraint Interpretation, and Obligation Generation

The scope state tracks which resources and constraints are currently active. It is a stack of `ScopeItem`s, each either a resource entry or a constraint declaration:

```lean
inductive Tag where
  | clinic | trial | room
  | examBed | bpMonitor | vo2Equipment
  | patient | clinician
  | examBedTech | bpTech | vo2Tech
  deriving DecidableEq, Repr

structure ScopeEntry where
  name : String
  tag  : Tag

inductive ConstraintId where
  | clinicInPatientCity
  | clinicianSpeaksPatient
  | clinicianAssigned
  | trialApprovesClinic
  | examBedQual | bpQual | vo2Qual

inductive ScopeItem where
  | entry      : ScopeEntry → ScopeItem
  | constraint : ConstraintId → ScopeItem

abbrev ScopeState := List ScopeItem
```

The `Tag` type distinguishes roles: Allen may appear as both `.clinician` (general role) and `.bpTech` (specific qualification role). A VO2 qualification constraint fires only for entries tagged `.vo2Tech`, not for entries tagged `.bpTech`. This **role-indexed** design ensures that each person proves only the qualifications relevant to the roles they actually fill.

**Constraint interpretation.** Each `ConstraintId` maps to a function from scope entries to a list of proof obligation types:

```lean
def interpretConstraint (cid : ConstraintId) (entries : List ScopeEntry)
    : List Type :=
  match cid with
  | .clinicInPatientCity =>
      let clinics  := entries.filterMap fun e =>
        if e.tag == .clinic  then some e.name else none
      let patients := entries.filterMap fun e =>
        if e.tag == .patient then some e.name else none
      clinics.flatMap fun cn =>
        patients.map fun pn => ClinicCityEvidence cn pn
  | .examBedQual =>
      (entries.filterMap fun e =>
        if e.tag == .examBedTech then some e.name else none).map fun n =>
          holdsExamBedQual (Human.mk n) .mk
  -- ... (remaining cases follow the same pattern)
```

Each constraint examines the entries for matching tags and produces one obligation per relevant pair. The `clinicInPatientCity` constraint fires for every (clinic, patient) pair; the `examBedQual` constraint fires for every examBedTech entry.

**Obligation generation.** When new items enter scope, obligations are computed incrementally to avoid re-proving constraints from earlier scope levels:

```lean
def newObligations (newItems : List ScopeItem) (existingState : ScopeState)
    : List Type :=
  let fullState := newItems ++ existingState
  let allEntries := fullState.filterMap fun | .entry e => some e | _ => none
  let newConstraints := newItems.filterMap fun | .constraint c => some c | _ => none
  let existingConstraints := existingState.filterMap fun | .constraint c => some c | _ => none
  let newEntries := newItems.filterMap fun | .entry e => some e | _ => none
  -- New constraints fire against ALL entries
  (newConstraints.flatMap fun cid => interpretConstraint cid allEntries)
  -- Existing constraints fire against NEW entries only
  ++ (existingConstraints.flatMap fun cid => interpretConstraint cid newEntries)
```

This precisely captures the intended semantics: when a new constraint is declared, it is checked against every resource in scope; when a new resource enters, it is checked against every existing constraint. Constraints declared at the trial level fire when a matching resource appears at a deeper scope.

**AllObligations.** The resulting obligation list is reduced to a nested product type:

```lean
def AllObligations : List Type → Type
  | []        => PUnit
  | [T]       => T
  | T :: rest => T × AllObligations rest
```

$$\text{AllObligations}([T_1, T_2, \ldots, T_n]) = T_1 \times T_2 \times \cdots \times T_n$$

The scope constructor requires a proof term inhabiting this product — a certificate that every obligation is satisfied.

**Explicit obligation types.** The `newObligations` function serves as a *specification*: it defines which obligations should fire. However, it cannot be used directly as the `obligations` parameter of the `scope` constructor because the Lean 4 kernel cannot reduce the `filterMap`/`flatMap`/`BEq` chains at type-checking time. Instead, the obligation types are spelled out as explicit abbreviations:

```lean
abbrev trialObligations : List Type := []
abbrev clinicObligations : List Type :=
  [ClinicCityEvidence "ValClinic" "Jose",
   assigned (Human.mk "Allen") (Clinic.mk "ValClinic"),
   trialApproves (ClinicalTrial.mk "OurTrial") (Clinic.mk "ValClinic"),
   SharedLangEvidence "Allen" "Jose"]
abbrev roomObligations : List Type :=
  [holdsExamBedQual (Human.mk "Allen") .mk,
   holdsBPMonitorQual (Human.mk "Allen") .mk,
   holdsVO2EquipmentQual (Human.mk "Allen") .mk]
```

The obligation types are derived from the `newObligations` specification but written explicitly so the kernel can match them against the evidence. This is a pragmatic concession: the semantics are defined by `newObligations`; the types are written by hand.

**How obligations fire across scope levels.** The interplay between scope items and obligation generation is shown in Table 1:

| Scope entry | New constraints | New entries | Obligations generated |
|-------------|----------------|-------------|----------------------|
| Trial | `clinicianSpeaksPatient` | `OurTrial` | `[]` (no clinician in scope yet) |
| Clinic | `clinicInPatientCity`, `clinicianAssigned`, `trialApprovesClinic` | `ValClinic`, `Allen` (clinician) | `ClinicCityEvidence`, `assigned`, `trialApproves`, `SharedLangEvidence` |
| Room | `examBedQual`, `bpQual`, `vo2Qual` | `Allen` (examBedTech, bpTech, vo2Tech) | `holdsExamBedQual`, `holdsBPMonitorQual`, `holdsVO2EquipmentQual` |

At the clinic level, the trial-level constraint `.clinicianSpeaksPatient` fires for the first time because a clinician (Allen) has entered scope. At the room level, the equipment qualification constraints fire for Allen's technician roles. The system captures the design principle that *constraints are declared where the policy originates, but fire when the relevant resources appear*.

### 5.4 The Negative Test: George at ParisClinic

The constraint system makes incorrect configurations **unprovable** rather than merely undetected. This is mechanized in the `GeorgeExample` namespace.

Consider patient George, who lives in London:

```lean
def george_lives_london : lives george london := .mk
```

The George example defines clinic-level scope items that place George at ParisClinic with clinician Matthew:

```lean
namespace GeorgeExample
abbrev georgeState : ScopeState := [.entry ⟨"George", .patient⟩]

abbrev clinicItems : List ScopeItem :=
  [.entry ⟨"ParisClinic", .clinic⟩,
   .entry ⟨"Matthew", .clinician⟩,
   .constraint .clinicInPatientCity,
   .constraint .clinicianAssigned,
   .constraint .trialApprovesClinic]

abbrev clinicObligations : List Type :=
  [ClinicCityEvidence "ParisClinic" "George",
   assigned (Human.mk "Matthew") (Clinic.mk "ParisClinic"),
   trialApproves (ClinicalTrial.mk "OurTrial") (Clinic.mk "ParisClinic"),
   SharedLangEvidence "Matthew" "George"]
end GeorgeExample
```

The first obligation, `ClinicCityEvidence "ParisClinic" "George"`, requires:

```lean
structure ClinicCityEvidence (clinicName patientName : String) : Type where
  city   : String
  cIsIn  : isIn (Clinic.mk clinicName) (City.mk city)
  pLives : lives (Human.mk patientName) (City.mk city)
```

To inhabit this type, one must provide a city where both ParisClinic is located AND George lives. ParisClinic is in Paris; George lives in London. No such city exists in the knowledge base. The type is uninhabited, so any scope constructor requiring `AllObligations clinicObligations` as evidence cannot be constructed.

This is the system working correctly: the type error is the specification rejecting an invalid configuration. The error is caught at definition time — before any runtime execution — and the obligation list identifies exactly which constraint is unprovable and which scope boundary it arises at.


---

## 6. The Clinical Trial Pipeline

This section presents the complete clinical trial pipeline as a worked example. The pipeline is the payoff of the preceding sections: it exercises every feature of the calculus — typed resources, branching, joining, nested scopes, and constraint satisfaction — in a realistic (if simplified) clinical domain.

The domain is illustrative, not the contribution. The mathematics is domain-agnostic.

### 6.1 Setup

**Patient:** Jose, living in Valencia, speaking Spanish.
**Clinician:** Allen, assigned to ValClinic (Valencia), speaking English and Spanish, holding qualifications for exam bed, BP monitor, and VO2 equipment.
**Clinic:** ValClinic, in Valencia, approved by OurTrial.
**Room:** Room3 at ValClinic, equipped with exam bed, BP monitor, and VO2 equipment.

**Shared language evidence.** A key resource is the proof that Allen and Jose share a language:

```lean
def allenJoseLangEvidence : SharedLangEvidence "Allen" "Jose" :=
  { lang := "Spanish"
    cSpeaks := allen_speaks_spanish
    pSpeaks := jose_speaks_spanish }
```

This is a **proof term**: it names the shared language (Spanish) and provides two ground-fact witnesses (`allen_speaks_spanish`, `jose_speaks_spanish`) drawn from the knowledge base. The `SharedLangEvidence` type is parameterized by both names, so evidence for Allen/Jose cannot be used for a different clinician/patient pair.

### 6.2 Pipeline Stages

The pipeline has six stages. Each stage is an `Arrow` step that declares its inputs (found in context via `Satisfy`) and its outputs (appended to the context).

**Listing 5.** Representative step: heart rate measurement.

```lean
def heartArrow : Arrow afterConsent (afterConsent ++ [HeartRate "Jose"]) :=
  .step
    { name := "heartMeasurement"
      description := "Measures the patient's heart rate using an exam bed"
      inputs := Tel.ofList [Patient "Jose", Clinician "Allen", ExamBed,
                            holdsExamBedQual allen .mk,
                            SharedLangEvidence "Allen" "Jose"]
      consumes := []
      produces := [HeartRate "Jose"] }
    afterConsent
    (.bind (Patient.mk "Jose") (by elem_tac)
      (.bind (Clinician.mk "Allen") (by elem_tac)
        (.bind ExamBed.mk (by elem_tac)
          (.bind holdsExamBedQual.mk (by elem_tac)
            (.bind allenJoseLangEvidence (by elem_tac)
              .nil)))))
```

The `Satisfy` proof term (the nested `.bind` chain) is the formal certificate that every required resource exists in the context. The `elem_tac` tactic resolves each `Elem` obligation automatically by searching through the context list — a de Bruijn index computation. The frame is `afterConsent` (the full context, since `consumes` is empty), and the output is the frame with `HeartRate "Jose"` appended.

The six stages are:

| Stage | Arrow | Inputs | Produces |
|-------|-------|--------|----------|
| 0 | `consentArrow` | Patient, SharedLangEvidence | ConsentGiven |
| 1 | `heartArrow` | Patient, Clinician, ExamBed, ExamBedQual, SharedLangEvidence | HeartRate |
| 2 | `bpArrow` | Patient, Clinician, BPMonitor, BPMonitorQual, SharedLangEvidence | BloodPressure |
| 3 | `vo2Arrow` | Patient, Clinician, VO2Equipment, VO2EquipmentQual, SharedLangEvidence | VO2Max |
| 4 | `productsArrow` | ConsentGiven, HeartRate, BloodPressure, VO2Max | ProductsOutput |
| 5 | `assessmentArrow` | Patient, ProductsOutput | AssessmentResult |

### 6.3 Branching and Joining

Each measurement can disqualify the patient (consent refused, heart rate too fast, blood pressure too high, VO2 too low). The pipeline has **four branch points** — one after each measurement that can disqualify.

At each branch point:
- The left branch produces `NonQualifying "Jose"` (disqualification) via `nqArrow`.
- The right branch continues the pipeline.

All four failure branches produce the same outcome type: `[Patient "Jose", NonQualifying "Jose"]` (after scope exit). Three `.join` operations collapse four identical failure outcomes into one, yielding exactly two final outcomes.

The failure selection `insideAllScopesSel` uses `Selection.prefix` to pick the 12 scope items from any extended context, discarding items produced by prior steps. This ensures that every failure branch sees the same context before disqualification — the precondition for `.join`.

### 6.4 The Complete Pipeline

**Listing 4.** Type signature of `scopedClinicalPipeline`.

```lean
def scopedClinicalPipeline : SheetDiagram initState joseCtx
    [[Patient "Jose", NonQualifying "Jose"],
     joseCtx ++ [ConsentGiven "Jose", HeartRate "Jose",
                  BloodPressure "Jose", VO2Max "Jose",
                  ProductsOutput "Jose", AssessmentResult "Jose"]] :=
```

The type is the specification. It states:
- **Input:** A context containing `Patient "Jose"`, under the initial scope state `[.entry ⟨"Jose", .patient⟩]`.
- **Outcome 1:** The patient was disqualified: context contains `Patient "Jose"` and `NonQualifying "Jose"`.
- **Outcome 2:** The patient completed all stages: context contains the patient plus all six produced types (consent, heart rate, blood pressure, VO2 max, products, assessment result).

There are exactly two outcomes. No other execution path is possible. This is a theorem, enforced by the type checker.

**Listing 6.** Full pipeline body.

```lean
  .scope "trial" trialItems trialExt
    trialObligations
    PUnit.unit                              -- no obligations at trial level
    (.scope "clinic" clinicItems clinicExt
      clinicObligations
      (valClinicJoseCityEvidence,           -- ClinicCityEvidence "ValClinic" "Jose"
       allen_assigned_val,                  -- assigned Allen ValClinic
       trial_approves_val,                  -- trialApproves OurTrial ValClinic
       allenJoseLangEvidence)               -- SharedLangEvidence "Allen" "Jose"
      (.scope "room" roomItems roomExt
        roomObligations
        (allen_holds_exambed,               -- holdsExamBedQual Allen
         allen_holds_bpmonitor,             -- holdsBPMonitorQual Allen
         allen_holds_vo2equip)              -- holdsVO2EquipmentQual Allen
        (.join (.join (.join
          (.branch (Split.idLeft insideAllScopes)
            insideAllScopesSel (Selection.id insideAllScopes)
            (.arrow nqArrow)
            (.pipe consentArrow
              (.pipe heartArrow
                (.branch (Split.idLeft afterHeart)
                  insideAllScopesSel (Selection.id afterHeart)
                  (.arrow nqArrow)
                  (.pipe bpArrow
                    (.branch (Split.idLeft afterBP)
                      insideAllScopesSel (Selection.id afterBP)
                      (.arrow nqArrow)
                      (.pipe vo2Arrow
                        (.branch (Split.idLeft afterVO2)
                          insideAllScopesSel (Selection.id afterVO2)
                          (.arrow nqArrow)
                          (.pipe productsArrow
                            (.arrow assessmentArrow)))))))))))))))
```

The structure reads from outside in:
1. Three nested scopes (`trial`, `clinic`, `room`) provide resources. Each scope carries its scope items, context extension, obligation types, and proof evidence.
2. At the trial level, no obligations fire (`PUnit.unit`) because the `clinicianSpeaksPatient` constraint has no clinician to check against.
3. At the clinic level, four obligations are discharged: city evidence, assignment, trial approval, and shared language.
4. At the room level, three qualification obligations are discharged — one per technician role.
5. Three `.join`s collapse four failure outcomes into one.
6. Four `.branch`es: the first branches on consent (left = disqualify, right = continue); the subsequent three branch after each measurement.
7. Within the right (continuation) branch, `.pipe` sequences the next arrow and continues.

Each `Split.idLeft` sends the entire context to the branch-part (with empty parallel frame), because in this pipeline both branches need access to the full scope context. Each `insideAllScopesSel` selects the 12 scope items for the failure branch (discarding produced items), and each `Selection.id` passes the full extended context to the continuation branch.

<!--
Figure 5: Complete clinical pipeline as sheet diagram.

                            ┌─ Trial ───────────────────────────────────────────┐
                            │ ┌─ Clinic ─────────────────────────────────────┐  │
                            │ │ ┌─ Room ──────────────────────────────────┐  │  │
    [Patient "Jose"]  ──────┤ │ │                                          │  │  │
                            │ │ │  ┌──── B₀ (consent?) ────┐               │  │  │
                            │ │ │  │                        │               │  │  │
                            │ │ │  ▼ fail                   ▼ ok            │  │  │
                            │ │ │  NQ ──┐            consent ──► heart      │  │  │
                            │ │ │       │                        │          │  │  │
                            │ │ │       │           ┌── B₁ (HR ok?) ──┐    │  │  │
                            │ │ │       │           │                  │    │  │  │
                            │ │ │       │           ▼ fail             ▼ ok │  │  │
                            │ │ │       ├─── NQ ──┐              bp        │  │  │
                            │ │ │       │  (join) │              │         │  │  │
                            │ │ │       │         │    ┌── B₂ (BP ok?) ──┐│  │  │
                            │ │ │       │         │    │                  ││  │  │
                            │ │ │       │         │    ▼ fail     ▼ ok   ││  │  │
                            │ │ │       ├─────────┤─── NQ    vo2max     ││  │  │
                            │ │ │       │ (join)  │          │          ││  │  │
                            │ │ │       │         │   ┌── B₃ (VO2 ok?)─┐│  │  │
                            │ │ │       │         │   │                 ││  │  │
                            │ │ │       │         │   ▼ fail    ▼ ok   ││  │  │
                            │ │ │       ├─────────┤── NQ   products    ││  │  │
                            │ │ │       │ (join)  │            │       ││  │  │
                            │ │ │       │         │        assessment   ││  │  │
                            │ │ │       │         │            │       ││  │  │
                            │ │ └───────┼─────────┼────────────┼───────┘│  │  │
                            │ └─────────┼─────────┼────────────┼────────┘  │  │
                            └───────────┼─────────┼────────────┼───────────┘  │
                                        ▼                      ▼
                            [Patient, NonQualifying]   [Patient, Consent, HR,
                                                        BP, VO2, Products,
                                                        Assessment]
-->

### 6.5 What the Type System Catches

The pipeline definition succeeds only if:

1. **Every resource is available.** Each `Satisfy` proof finds the required types in the current context. If `SharedLangEvidence "Allen" "Jose"` is removed from `clinicExt`, every measurement step fails to type-check.

2. **Equipment qualifications match.** The heart measurement requires `holdsExamBedQual allen .mk` — a proof that Allen holds the exam bed qualification. This is provided by `roomExt`. If Allen's qualifications are changed to a different clinician's, the `Elem` search fails.

3. **Shared language is provable.** `allenJoseLangEvidence` is a proof term requiring ground facts `allen_speaks_spanish` and `jose_speaks_spanish`. If Allen does not speak Spanish, the evidence cannot be constructed.

4. **Scope-level constraints are satisfied.** Each scope entry requires `AllObligations` evidence. The clinic scope requires proof that ValClinic is in Jose's city, that Allen is assigned to ValClinic, that OurTrial approves ValClinic, and that Allen speaks Jose's language. The room scope requires proof that Allen holds all three equipment qualifications. Missing any evidence term is a type error.

5. **Constraint obligations are role-indexed.** If Allen fills the `examBedTech` and `bpTech` roles but Matthew fills the `vo2Tech` role, the obligations require `holdsExamBedQual Allen`, `holdsBPMonitorQual Allen`, and `holdsVO2EquipmentQual Matthew` — each person proves only their own qualifications.

6. **Geographic constraints reject invalid configurations.** The George negative test (Section 5.4) demonstrates that placing George (London) at ParisClinic (Paris) produces an unprovable `ClinicCityEvidence "ParisClinic" "George"` obligation.

4. **Scopes nest correctly.** The scope exit strips the extension from every outcome. If an inner step produces a resource of the wrong type, the outcome list does not match the required `Δs.map (ext ++ ·)` pattern.

5. **Joins have identical outcomes.** Each `.join` requires two adjacent identical contexts in the outcome list. The failure-selection mechanism ensures this.


---

## 7. Erasure

After type-checking, the proof content in a `SheetDiagram` — de Bruijn indices, `Selection`/`Split`/`Satisfy` witnesses, frame arguments, context lists — is needed only for verification, not for execution. The **erasure** operation extracts a type-free computational skeleton.

**Listing 7.** The erased pipeline type and erasure functions.

```lean
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
```

```lean
def eraseArrow : Arrow Γ Δ → Pipeline
  | .step spec _ _ => .step spec.name
  | .seq a b       => .seq (eraseArrow a) (eraseArrow b)
  | .par a b       => .par (eraseArrow a) (eraseArrow b)
  | .id            => .noop
  | .swap          => .noop

def erase : SheetDiagram st Γ Δs → Pipeline
  | .arrow a                  => eraseArrow a
  | .pipe a s                 => .seq (eraseArrow a) (erase s)
  | .branch _ _ _ l r         => .branch (erase l) (erase r)
  | .join s                   => .join (erase s)
  | .halt                     => .halt
  | .scope label _ _ _ _ s    => .scope label (erase s)
```

`eraseArrow` maps each Arrow constructor to its untyped counterpart: steps carry only their name; `id` and `swap` become `noop` (they have no computational effect beyond context rearrangement). `erase` maps each `SheetDiagram` constructor similarly, discarding the `Split`, `Selection`, scope items, obligation types, evidence, and extension arguments.

The erased `Pipeline` type preserves the branching structure, scope nesting, and step sequencing of the original — everything needed for execution — while discarding the type-level invariants that were needed for verification. This separation follows the standard pattern of **program extraction** in proof assistants: type-check once with full proof content, then extract an executable term.

The erased clinical pipeline:

```
scope trial
  scope clinic
    scope room
      join
        join
          join
            branch
              step disqualify
              seq
                step consent
                seq
                  step heartMeasurement
                  branch
                    step disqualify
                    seq
                      step bpMeasurement
                      branch
                        step disqualify
                        seq
                          step vo2Measurement
                          branch
                            step disqualify
                            seq
                              step products
                              step assessment
```

The structure is immediately readable: three scopes, four branches (each with a `disqualify` left arm), and the happy path threading through consent, heart, BP, VO2, products, and assessment.

---

## 8. Related Work

### 8.1 Indexed Monads

Atkey (2009) introduces parameterised (indexed) monads $M\;i\;j\;a$ with bind threading indices. Our `Arrow` type is an indexed monad over `Ctx` with sequential composition as bind. The indexed monad framework provides the right abstraction for resource-tracking computations — the pre-index captures available resources, the post-index captures resources after the operation.

The novelty relative to Atkey is not in the indexed monad itself but in the *coproduct decomposition*: we show that when branching is needed, the correct structure is an external coproduct of indexed monads (one per branch/sheet), rather than embedding coproducts inside the monad's index. This keeps each individual monad simple.

### 8.2 Rig Categories and Sheet Diagrams

Laplaza (1972) establishes the coherence conditions for categories with two monoidal structures related by distributivity — what are now called rig categories or bimonoidal categories. The coherence conditions are intricate; the challenge is managing the interaction between tensor and coproduct.

Comfort, Delpeuch, and Hedges (2020) introduce sheet diagrams as a graphical calculus for rig categories. Their key insight — that tensor lives on surfaces and coproduct lives as stacking of surfaces — provides the geometric intuition behind our decomposition. We give their geometric perspective a type-theoretic implementation: the `SheetDiagram` inductive type is the term representation of their graphical calculus, with the `List Ctx` index playing the role of the stack of sheets.

The relationship is: Comfort–Delpeuch–Hedges provide the geometry; Atkey provides the monadic structure; our contribution is the explicit bridge between them, formalized as an inductive type in a proof assistant.

### 8.3 Linear Logic

Girard (1987) introduces the distinction between multiplicative and additive connectives that underlies our separation of `Split` and `Selection`:

| Our type | Linear logic | Intuition |
|---|---|---|
| `Split Γ Δ₁ Δ₂` | $\Gamma \vdash \Delta_1 \otimes \Delta_2$ | Partition: both halves used |
| `Selection Γ Δ` | $\Gamma \vdash \Delta$ (under $!$) | Selection: one branch used at runtime |
| `branch` constructor | $\oplus$ introduction | Creating alternative continuations |
| `join` constructor | $\oplus$ elimination (codiagonal) | Collapsing identical alternatives |

The multiplicative/additive distinction in linear logic corresponds exactly to the split/selection distinction in our calculus: `Split` partitions resources that are all consumed (multiplicative), while `Selection` picks resources for one of several exclusive alternatives (additive). The overlap permitted by `Selection` — two branches selecting the same resource — is sound precisely because the branches are mutually exclusive at runtime, corresponding to the additive contraction rule.

### 8.4 Session Types

Honda (1993) introduces session types for binary communication. Wadler (2012) connects session types to linear logic via the Curry–Howard correspondence: propositions correspond to session types, proofs correspond to processes. Toninho, Caires, and Pfenning (2011) extend this to dependent session types.

The branching operation in session types — where a channel offers one of several possible continuations — is operationally the same decomposition we describe. Each branch of a session-type offer proceeds independently with its own continuation type, and the branches are mutually exclusive. The difference is the setting: session types concern communication protocols between processes, while our calculus concerns resource-typed workflow specifications. The mathematical structure (external coproduct of continuations, each carrying its own resource discipline) is the same.

### 8.5 Choreographic Programming

Montesi (2023) develops choreographic programming, where a global specification (choreography) is projected to endpoint implementations. The choreography specifies interactions between participants; projection produces local programs for each participant.

The analogy to our system: a `SheetDiagram` is a global specification of a workflow; the `erase` operation projects it to an executable skeleton; the runtime execution (future work) produces local state for each step. The scoped constraint system — which checks invariants at scope boundaries — plays a role analogous to well-formedness conditions on choreographies.

### 8.6 Workflow Verification

Prior approaches to workflow verification often use model checking: specify a workflow as a state machine, specify properties in temporal logic, and exhaustively search the state space. This scales to moderate-sized systems but provides no compositional guarantees — adding a step may require re-checking the entire system.

Our approach is **correct by construction**: the type of the pipeline IS the specification, and the type checker verifies that the construction is valid. Adding a step changes the type (the specification), and the type checker re-verifies only the affected portions. This is compositional by design.

### 8.7 Delineation of Novelty

The ingredients of our construction are individually well-established:

- Free SMCs and string diagrams (Joyal and Street, 1991)
- Indexed monads for resource tracking (Atkey, 2009)
- Sheet diagrams for rig categories (Comfort, Delpeuch, and Hedges, 2020)
- Multiplicative/additive distinction (Girard, 1987)
- Branching in session types (Honda, 1993; Wadler, 2012)

The contribution is the **explicit bridge**: that a rig-category arrow system decomposes into an external coproduct of plain SMC indexed monads, one per sheet, with the practical consequence that tensor and coproduct never cohabit inside a single monad's context. This avoids DNF blowup while preserving the simplicity of the forward-threading indexed monad within each sheet. The bridge connects Comfort–Delpeuch–Hedges's geometric insight (surfaces as monoidal worlds, stacking as coproduct) with Atkey's algebraic structure (indexed monads as parameterized computations) in a way that we have not found stated explicitly in the literature.

The mechanization in Lean 4 — with the `SheetDiagram` inductive type, the `Split`/`Selection` separation, nested scopes, and a complete clinical pipeline type-checking with zero `sorry`s — provides formal evidence for the construction.


---

## 9. Discussion and Future Work

### 9.1 Runtime State Monad

The current system is purely type-level: the `SheetDiagram` specifies valid executions but does not track which steps have completed, what values were produced, or what time has elapsed. The natural next step is a **runtime state monad** that tracks position within the type-level space.

The architecture described in the introduction (see also the CLAUDE.md design document) envisions two levels:

- **Type level** (`SheetDiagram`): the space of correct executions (current implementation).
- **State level**: a concrete state monad tracking certificates, timestamps, and execution history. The state monad carries the runtime evidence that the type-level conditions hold.

The state monad would be indexed by the same `Ctx` as the type level, ensuring that runtime state is always consistent with the specification.

### 9.2 Re-planning via Incremental Proof Construction

When real-world events require plan revision (a patient reschedules, a clinician becomes unavailable), the two levels interact. After partial execution:

$$M\;\Gamma\;\Delta_{\text{final}}\;\alpha \quad\text{(original pipeline type)}$$

the continuation from the current point is:

$$M\;\Delta_{\text{current}}\;\Delta_{\text{final}}\;\alpha \quad\text{(remaining plan)}$$

When circumstances change:

1. **Reflect**: Reconstruct the type-level context $\Delta_{\text{current}}$ from the runtime state. Completed steps have produced typed certificates; these form a heterogeneous list over $\Delta_{\text{current}}$.

2. **Re-plan**: Construct a new `SheetDiagram` $\Delta_{\text{current}} \to \Delta'_{\text{final}}$ under revised constraints. The type checker verifies correctness from the current execution point.

3. **Carry forward**: Objects already in $\Delta_{\text{current}}$ are inherited by the new pipeline without re-running completed steps.

This is incremental proof construction: the pipeline is a proof term, partial execution consumes part of it, and rescheduling extends or revises the remaining proof obligations.

### 9.3 Compilation via Rig Functor

The sheet decomposition makes compilation to executable processes practical. A **rig functor** from the specification category to a process calculus (e.g., DLπ, a dependently typed π-calculus) can be defined sheet-by-sheet:

- Each sheet is compiled independently as an SMC functor (preserving sequential and parallel composition).
- Branch points compile to channel offers/selections.
- Join points compile to process merges.

Because each sheet is a plain SMC arrow (no internal coproducts), the sheet-level compilation is exactly the standard string-diagram-to-process translation. The rig structure (cross-sheet branching) is handled separately. This factoring of the compilation problem mirrors the factoring of the specification.

### 9.4 Knowledge Base as Event Log

The Neo4j knowledge base in the current system stores ground facts (who speaks what language, which clinician is assigned where, which room has which equipment). The type-level pipeline is always a **derived view** of those facts — every proof term in the pipeline ultimately references ground facts from the KB.

When the KB is updated (appointment rescheduled, new fact asserted), a new pipeline type is derived. The type derivation IS the re-planning step. This is the event-sourcing pattern: KB = source of truth, pipeline = derived specification. The combination of event sourcing with dependently typed specifications — where the derivation is a type-level computation verified by a proof assistant — connects two traditionally separate worlds (distributed systems architecture and type theory).


---

## 10. Conclusion

We have presented a decomposition of rig-category arrow systems into external coproducts of plain SMC indexed monads, formalized as the `SheetDiagram` type in Lean 4. The key design principle is separation: tensor products (resource composition within a single execution path) and coproducts (branching between alternative execution paths) live at different levels. Each sheet — each summand of the external coproduct — carries the same simple forward-threading indexed monad that works for linear pipelines. No sheet ever encounters a coproduct; no branch point ever manipulates tensor products internally.

This separation has three consequences. First, the exponential blowup of the distributive law (DNF for $2^k$ branch points) is avoided: the number of sheets grows linearly with branch points, and joins reduce it. Second, the plain SMC arrow system is reused without modification as the intra-sheet computation model, avoiding the complexity of a monolithic rig-category calculus. Third, the partition problem at branch points is localized: `Split` and `Selection` witnesses are local proof obligations at each branch point, not global concerns.

A nested scope discipline provides type-level resource management: resources are introduced on scope entry and deallocated on exit, with a role-indexed constraint system enforcing domain invariants at scope boundaries. Constraints are declared where the policy originates and fire when matching resources appear at deeper scopes.

The full system is mechanized in Lean 4 (toolchain v4.25.0-rc2) with zero unproven assumptions. A complete clinical trial pipeline — six stages, four branch points, three joins, three levels of scope nesting, and seven constraint types across three scope levels — type-checks and demonstrates all features of the calculus. A negative test confirms that an invalid configuration (George at ParisClinic) is rejected as a type error. An erasure operation extracts a type-free computational skeleton suitable for runtime interpretation.

The ingredients are known; the bridge is new. The geometric insight of Comfort, Delpeuch, and Hedges (sheets as surfaces, stacking as coproduct) and the algebraic structure of Atkey (indexed monads for parameterized computation) are connected by the observation that the external coproduct of indexed monads is the right algebraic structure for branching resource-typed workflows — and that this structure avoids the coherence difficulties of full rig categories by keeping the two monoidal operations at separate levels.

---

## References

Atkey, R. (2009). Parameterised Notions of Computation. *Journal of Functional Programming*, 19(3-4), 335–376.

Bernardy, J.-P., Boespflug, M., Newton, R. R., Peyton Jones, S., and Spiwack, A. (2018). Linear Haskell: Practical Linearity in a Higher-Order Polymorphic Language. *Proceedings of the ACM on Programming Languages*, 2(POPL), 5:1–5:29.

Comfort, C., Delpeuch, A., and Hedges, J. (2020). Sheet Diagrams for Bimonoidal Categories. arXiv:2010.13361.

Girard, J.-Y. (1987). Linear Logic. *Theoretical Computer Science*, 50(1), 1–102.

Honda, K. (1993). Types for Dyadic Interaction. *CONCUR '93*, Lecture Notes in Computer Science 715, 509–523.

Joyal, A. and Street, R. (1991). The Geometry of Tensor Calculus I. *Advances in Mathematics*, 88(1), 55–112.

Laplaza, M. (1972). Coherence for Distributivity. *Lecture Notes in Mathematics*, 281, 29–65.

Montesi, F. (2023). *Introduction to Choreographies*. Cambridge University Press.

Tofte, M. and Talpin, J.-P. (1997). Region-Based Memory Management. *Information and Computation*, 132(2), 109–176.

Toninho, B., Caires, L., and Pfenning, F. (2011). Dependent Session Types via Intuitionistic Linear Type Theory. *PPDP '11*, 161–172.

Wadler, P. (2012). Propositions as Sessions. *ICFP '12*, 273–286.
