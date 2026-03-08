# WorldModel Project — Intellectual Property Overview

This document summarizes the technical architecture, novel contributions, and prior art for the WorldModel project, intended as context for IP analysis.

## 1. What the System Does

The system provides a **formally verified specification and execution framework for clinical trial workflows** (Schedules of Activities / SoAs). An AI agent constructs a workflow specification; the specification is compiled to executable distributed processes; and the compilation is proven correct by a dependently typed proof assistant (Lean 4).

The concrete domain is clinical trials: a patient goes through consent, measurements (heart rate, blood pressure, VO2 max), product administration, and assessment. Real workflows branch (patient consents or refuses), have parallel activities, and must satisfy regulatory constraints (clinician certifications, timing between doses, equipment availability).

## 2. Architecture Layers

### 2.1 Specification Layer: Arrow Calculus in Lean 4

Workflows are expressed as morphisms in a **free symmetric monoidal category (SMC)** on a signature of typed steps. Each step transforms a typed context (a list of typed resources):

```
Arrow : Ctx → Ctx → Type
```

The `Arrow` type is an inductive with constructors: `step`, `seq` (sequential composition, `⟫`), `par` (parallel composition, `⊗`), `id`, and `swap`. This is implemented and builds with zero `sorry`s (no unproven assumptions).

A full 6-stage clinical pipeline is implemented: consent → heart rate → blood pressure → VO2 max → products → assessment.

### 2.2 Branching: Rig Categories and Sheet Diagrams

Real workflows require **coproducts** (`⊕`) for branching (consent/refusal, adverse events, protocol deviations). Adding `⊕` alongside `⊗` yields a **rig category** (bimonoidal category), governed by a distributive law:

$$\Gamma \otimes (\Delta_1 \oplus \Delta_2) \cong (\Gamma \otimes \Delta_1) \oplus (\Gamma \otimes \Delta_2)$$

A naive implementation (distributing into disjunctive normal form) causes exponential blowup in the number of contexts tracked. We adopt the **sheet diagram** approach of Comfort, Delpeuch, and Hedges (arXiv:2010.13361), where `⊗` is wiring on a surface (string diagrams) and `⊕` is stacking of surfaces (parallel sheets).

### 2.3 Compilation Target: DLπ (Dependently Typed π-Calculus)

The workflow specifications are compiled into **DLπ**, a dependently typed version of the π-calculus originally embedded in Agda and since translated to Lean 4. DLπ expressions are executable distributed processes with session-typed communication channels.

### 2.4 Knowledge Graph: Neo4j

A Neo4j knowledge base serves as the **event log** — the ground facts from which constraint evidence is derived. The type-level pipeline is a derived view of these facts. When facts change (appointment rescheduled, new data), a new pipeline is derived automatically (event-sourcing pattern).

### 2.5 Orchestration: n8n + Python MCP

An n8n workflow orchestrates the system. A Python FastAPI server wraps LeanInteract to run Lean commands. Claude (via Anthropic API) acts as the SoA-constructing agent.

## 3. Potentially Novel Contributions

### 3.1 Coproduct of Indexed Monads Decomposition

**Claim:** A rig-category arrow system decomposes into an **external coproduct of plain SMC indexed monads**, one per sheet, so that `⊗` and `⊕` never cohabit inside a single monad's context.

The specification language is built on an indexed monad `M Γ Δ α` (Atkey, 2009) where `Γ` is the pre-context, `Δ` is the post-context, and bind threads the context forward. Rather than embedding `⊕` inside the context (which causes DNF blowup), a branch point spawns **separate indexed monads**, each evolving a simple product context on its own sheet:

$$M_1\;\Gamma_1\;\Delta_1\;\alpha_1 \;\oplus\; M_2\;\Gamma_2\;\Delta_2\;\alpha_2 \;\oplus\; M_3\;\Gamma_3\;\Delta_3\;\alpha_3$$

Each sheet reuses the existing forward-threading monad without modification. Branching is structural (between monads), not contextual (inside a monad). Sheets rejoin only at `copair`-type boxes where multiple branches converge.

**Prior art status:** The geometric content (sheets as independent diagrams) is in Comfort–Delpeuch–Hedges. The monadic content (indexed monads for resource tracking) is in Atkey. The explicit bridge — that the rig structure decomposes into an external coproduct of SMC indexed monads, and the practical consequence that each sheet reuses the simple monad — does not appear to be explicitly stated in the literature we have surveyed. Related but distinct formulations exist in session types (Wadler, 2012), linear logic (additive `⊕`), and algebraic effects (Hyland–Plotkin–Power on coproducts of monads, which addresses combining different effect systems rather than branching within one).

### 3.2 Bitmask Partition Algorithm for Context Splitting

At a branch point, the context must be partitioned among sheets. Each branch declares its needs as a list of `Elem` witnesses (type-safe references to context members). The partition algorithm:

1. Each branch's element list is converted to a bitmask over the context.
2. OR all bitmasks → elements used by at least one branch.
3. Complement of OR → elements needed by no branch → assigned to a parallel continuation sheet.
4. Overlap positions (multiple bitmasks have 1) → require contraction/copying at the branch point.

This is decidable and computable at type-checking time in Lean 4 since the context is a finite list and membership is decidable. No backward/reverse generation of the context is needed — each branch arrow's input type directly provides the element list.

### 3.3 Three-Layer Defense Against Agent Hallucination

The system provides three layers of machine-checkable defense when an AI agent constructs an SoA:

1. **Monoidal/rig category structure** — The SoA is a wiring diagram (morphism) in a typed category. The categorical structure prevents ill-formed compositions. An agent cannot wire incompatible steps together.

2. **Rig functor to DLπ + session typing** — The compilation from the SoA category to DLπ must be a structure-preserving rig functor (preserving both `⊗` and `⊕`). The target DLπ expressions must additionally be session-typed. This prevents translations that look plausible but don't faithfully implement the specification.

3. **Behavioral theorems** — Depending on the degree of safety required, the agent must prove theorems about the typed sessions: session fidelity, deadlock freedom, progress, liveness under resource constraints. Each level is strictly harder; the required level is configurable per deployment.

All three layers are verified by Lean 4's kernel — the agent produces witnesses (diagrams, functors, proofs) that are machine-checked. The coproduct-of-indexed-monads decomposition makes layer 2 practical: the functor can be defined sheet-by-sheet.

**Prior art status:** Session-typed compilation from choreographies exists (Montesi's choreographic programming). Categorical semantics for process calculi exist. The specific combination — monoidal categories as a typed intermediate representation between an LLM agent and a dependently typed process calculus, with functorial compilation as the correctness condition and machine-checked behavioral proofs as the safety guarantee — does not appear in the literature we have surveyed.

### 3.4 Re-planning via Incremental Proof Construction

After partial execution of a pipeline, the system can **re-plan** when circumstances change:

1. **Reflect** — reconstruct the type-level context from runtime state (completed steps have produced typed certificates).
2. **Re-plan** — construct a new continuation arrow under revised constraints. The type checker verifies correctness from the current execution point.
3. **Carry forward** — objects already produced are inherited without re-execution.

This is incremental proof construction: the pipeline is a proof term, partial execution consumes part of it, and rescheduling extends or revises the remaining proof obligations. The KB update triggers re-derivation of the pipeline type.

**Prior art status:** Re-planning in AI planning systems is well-established. Incremental proof construction exists in proof assistants. The combination — re-planning as incremental proof construction over an indexed monad, triggered by event-sourced KB updates — appears to be a novel integration.

## 4. Known Prior Art

| Component | Prior Art |
|---|---|
| Free SMC / string diagrams | Standard category theory (Joyal–Street, 1991) |
| Indexed monads | Atkey (2009), *Parameterised Notions of Computation* |
| Rig categories | Laplaza (1972), *Coherence for Distributivity* |
| Sheet diagrams | Comfort, Delpeuch, Hedges (2020), arXiv:2010.13361 |
| Session types | Honda (1993); Wadler (2012), *Propositions as Sessions* |
| DLπ | Toninho, Caires, Pfenning (2011) and subsequent work |
| Choreographic programming | Montesi (2023), *Introduction to Choreographies* |
| Linear logic resource management | Girard (1987) |
| Event sourcing | Fowler (2005); standard architecture pattern |
| LLM agents with tool use | Standard practice (2023–present) |

## 5. Implementation Status

| Component | Status |
|---|---|
| Arrow as free SMC (Lean 4) | Implemented, zero `sorry`s |
| 6-stage clinical pipeline | Implemented, builds clean |
| Context splitting (`Split` witness) | Implemented |
| Coproducts / branching (`⊕`) | Design phase — reading Comfort/Delpeuch |
| Bitmask partition algorithm | Designed, not yet implemented |
| DLπ in Lean 4 | Available (translated from Agda), not yet integrated |
| Rig functor (SoA → DLπ) | Not yet implemented |
| Runtime state monad | Not yet implemented |
| Re-planning | Not yet implemented |
| Neo4j KB integration | Infrastructure exists, not connected to Arrow system |
| Python MCP server | Implemented (REST, not yet full MCP) |
| n8n orchestration | Test workflow implemented |

## 6. Key Files

- `lean4/WorldModel/KB/Arrow/Arrow.lean` — Arrow inductive type (free SMC)
- `lean4/WorldModel/KB/Arrow/Context.lean` — Context type, Elem, Split witnesses
- `lean4/WorldModel/KB/Arrow/Spec.lean` — Telescopes and specifications
- `lean4/WorldModel/KB/Arrow/Clinical.lean` — 6-stage clinical pipeline
- `docs/rig-indexed-monads.md` — Technical writeup of the coproduct-of-indexed-monads observation (shareable)

## 7. References

- Atkey, R. (2009). *Parameterised Notions of Computation.* JFP 19(3-4).
- Comfort, C., Delpeuch, A., Hedges, J. (2020). *Sheet Diagrams for Bimonoidal Categories.* arXiv:2010.13361.
- Girard, J.-Y. (1987). *Linear Logic.* Theoretical Computer Science 50(1).
- Honda, K. (1993). *Types for Dyadic Interaction.* CONCUR '93.
- Joyal, A., Street, R. (1991). *The Geometry of Tensor Calculus I.* Advances in Mathematics 88(1).
- Laplaza, M. (1972). *Coherence for Distributivity.* LNM 281.
- Montesi, F. (2023). *Introduction to Choreographies.* Cambridge University Press.
- Toninho, B., Caires, L., Pfenning, F. (2011). *Dependent Session Types.* PPDP '11.
- Wadler, P. (2012). *Propositions as Sessions.* ICFP '12.
