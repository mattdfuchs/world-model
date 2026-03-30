# Resource Allocation on Wiring Diagrams: 𝗑𝗙𝗹𝗼, Prof(Rig), and DLπ

**Docimion Corporation · Internal Use Only · March 2026**

---

## Part I: The Problem

---

## 1. The Problem

A clinical trial is a network. Its nodes are clinical operations — consent, measurement, assessment, drug administration. Its wires are typed resources — patients, practitioners, equipment, drug doses, consent evidence. The wires carry quantities governed by conservation laws: a 5mg drug dose can be split into 2mg and 3mg, but not into 5mg and 5mg. The network has splits (parallel sub-processes), merges (joining outcomes), branches (mutually exclusive alternatives), nested scopes (resources available within a block and reclaimed on exit), and — for chronic disease protocols — feedback loops (conserved resources cycling back for reuse).

The **problem** is: given such a network, find a consistent assignment of rig-valued resource quantities to every wire such that every local constraint is satisfied — conservation laws at splits, domain obligations at scope boundaries (the clinic is in the patient's city, the clinician speaks the patient's language, the equipment qualifications are held), and accounting invariants throughout.

A **solution** is a fully type-checked term in Lean 4: a specific construction whose type encodes the specification and whose existence constitutes the proof that all constraints are met. From this term, a verified concurrent process — a DLπ program — is compiled by a functorial mapping that translates each clinical operation to a subprocess and each structural combinator to a process composition primitive.

The **goal of this document** is to frame each stage of this solution-finding as a functor between specific finite categories, and to show how the categorical framework (monoidal categories, profunctors, rig categories) provides the mathematical guarantee that the constructions are sound — while every artifact in the chain is a computable Lean 4 inductive type.

---

## 2. The Representational Principle

**The system never manipulates resources. It manipulates representations of resources.**

A workflow specification does not move a physical practitioner from one room to another. It transforms a *token* representing a claim on a practitioner. A drug is not administered inside the formal system — a token representing an available drug dose is consumed. The physical practitioner, the physical drug, the physical patient exist in the physical world, outside the formal system. The formal system manages *claims* — credits and debits — at the cyber-physical integration boundary.

This is not a limitation. It is the defining characteristic of a control layer. Fly-by-wire avionics do not fly the aircraft; they manage representations of control-surface positions and sensor readings. The control layer is correct when the representations are faithful and the accounting is sound.

### Credits and Debits

Every resource that enters the system is represented by a matched **credit-debit pair**. When a practitioner is brought into scope, the system issues a **credit** ("practitioner available for use in this scope") and simultaneously records a **debit** ("practitioner must be accounted for at scope exit"). When the practitioner completes a task and cycles back for the next, the old credit is surrendered and a fresh credit is issued against the same standing debit. When the scope closes, the credit is surrendered and the debit is discharged. Both vanish.

In a compact closed category, η_A : I → A ⊗ A* creates a matched pair from the empty context, and ε_A : A* ⊗ A → I annihilates a matched pair. Taken as operations on physical resources, these are absurd. Taken as operations on *representations*, they are natural: η creates a credit-debit pair (issuance of a claim), and ε cancels a credit against a debit (redemption of a claim). The **snake equations** — η followed by ε equals the identity — say that issuing a claim ticket and immediately redeeming it is a no-op. This is the accounting invariant.

### Which Resources Have Duals

**Conserved resources** (practitioners, conserved equipment, protocol state) support the full credit-debit cycle. They have duals. Their dual type represents the debit.

**Consumed resources** (drug doses, single-use devices, specimens) do not. When a drug dose credit is redeemed, no new credit is issued. They have no dual.

**Certificate resources** (consent evidence, qualification records) persist as immutable claims. They have no dual because there is no debit to track.

### Rig-Indexed Accounting: Copying vs. Division

When a resource token splits, there are two possibilities:

**Copying**: 5mg becomes 5mg *and* 5mg. The quantity doubles. Information works this way.

**Division**: 5mg becomes 2mg *and* 3mg. The total is conserved. Physical quantities work this way.

The distinction is made by the **rig** (semiring) indexing the resource type. A token of type A carrying rig element r ∈ S can split into A(r₁) ⊗ A(r₂) if and only if **r₁ + r₂ = r** under the rig's addition. The rig addition *is* the conservation law.

**Idempotent rigs** (r + r = r): copying and division coincide. Protocol approvals are duplicable.

**Non-idempotent rigs** (r + r ≠ r): only genuine division is valid. Drug(5) → Drug(2) ⊗ Drug(3), not Drug(5) ⊗ Drug(5).

| Resource type | Rig | Splitting semantics |
|---|---|---|
| Drug dose | (ℝ≥0, +, ·) | Division: r₁ + r₂ = r |
| Patient count | (ℕ, +, ·) | Division: counts partition |
| Protocol approval | Boolean / idempotent | Copying: r + r = r |
| Equipment use | Bounded rig with top | Division with capacity constraint |

The comultiplication is a **rig-indexed comultiplication** — a family δ_{r₁,r₂} : A(r) → A(r₁) ⊗ A(r₂) parameterized by pairs satisfying r₁ + r₂ = r [Coecke, Fritz, and Spekkens 2016].

---

## Part II: The Architecture

---

## 3. The Diagram

The architecture is a chain of specific finite (or finitely presented) categories connected by functors. Each node in the following diagram is a specific object — not a large ambient category. The colored containers are the ambient categories that guarantee the constructions exist; they are never computed in.

<svg width="100%" viewBox="0 0 680 720" xmlns="http://www.w3.org/2000/svg">
<style>
  .th { font-family: system-ui, -apple-system, sans-serif; font-size: 14px; font-weight: 500; }
  .ts { font-family: system-ui, -apple-system, sans-serif; font-size: 12px; font-weight: 400; }
  .fill-purple { fill: #EEEDFE; stroke: #534AB7; }
  .fill-teal { fill: #E1F5EE; stroke: #0F6E56; }
  .fill-gray { fill: #F1EFE8; stroke: #5F5E5A; }
  .text-purple { fill: #3C3489; }
  .text-teal { fill: #085041; }
  .text-gray { fill: #444441; }
  .text-muted { fill: #888780; }
  .text-accent { fill: #534AB7; }
  .stroke-main { stroke: #5F5E5A; }
  .stroke-teal { stroke: #0F6E56; }
  @media (prefers-color-scheme: dark) {
    .fill-purple { fill: #3C3489; stroke: #7F77DD; }
    .fill-teal { fill: #085041; stroke: #5DCAA5; }
    .fill-gray { fill: #444441; stroke: #888780; }
    .text-purple { fill: #CECBF6; }
    .text-teal { fill: #9FE1CB; }
    .text-gray { fill: #D3D1C7; }
    .text-muted { fill: #888780; }
    .text-accent { fill: #AFA9EC; }
    .stroke-main { stroke: #888780; }
    .stroke-teal { stroke: #5DCAA5; }
  }
</style>
<defs>
<marker id="arrow" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M2 1L8 5L2 9" fill="none" stroke="context-stroke" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></marker>
</defs>
<rect class="fill-gray" x="270" y="30" width="140" height="44" rx="8" stroke-width="0.5"/>
<text class="th text-gray" x="340" y="52" text-anchor="middle" dominant-baseline="central">1</text>
<line x1="300" y1="74" x2="300" y2="138" class="stroke-main" stroke-width="1" marker-end="url(#arrow)"/>
<text class="ts text-muted" x="268" y="110" text-anchor="end">𝗽𝗶𝗰𝗸</text>
<line x1="380" y1="74" x2="380" y2="138" class="stroke-main" stroke-width="1" marker-end="url(#arrow)"/>
<text class="ts text-muted" x="412" y="110" text-anchor="start">𝗹𝗮𝗯𝗲𝗹(𝗽𝗶𝗰𝗸)</text>
<text class="th text-accent" x="340" y="98" text-anchor="middle" dominant-baseline="central">⇒</text>
<text class="ts text-accent" x="340" y="116" text-anchor="middle" dominant-baseline="central">𝗹𝗮𝗯𝗲𝗹</text>
<rect x="120" y="122" width="440" height="86" rx="16" fill="#FBEAF0" stroke="#ED93B1" stroke-width="0.5" opacity="0.45"/>
<text class="ts" x="536" y="140" text-anchor="end" fill="#72243E" opacity="0.7">FinTensScheme</text>
<rect class="fill-purple" x="224" y="148" width="232" height="44" rx="8" stroke-width="0.5"/>
<text class="th text-purple" x="340" y="170" text-anchor="middle" dominant-baseline="central">𝗹𝗮𝗯𝗲𝗹(G₀)</text>
<line x1="340" y1="192" x2="340" y2="270" class="stroke-main" stroke-width="1" marker-end="url(#arrow)"/>
<text class="ts text-muted" x="358" y="234" text-anchor="start">𝗳𝗿𝗲𝗲</text>
<rect x="120" y="254" width="440" height="86" rx="16" fill="#E6F1FB" stroke="#85B7EB" stroke-width="0.5" opacity="0.45"/>
<text class="ts" x="536" y="272" text-anchor="end" fill="#0C447C" opacity="0.7">TracedSMC</text>
<rect class="fill-purple" x="194" y="270" width="292" height="44" rx="8" stroke-width="0.5"/>
<text class="th text-purple" x="340" y="292" text-anchor="middle" dominant-baseline="central">𝗑𝗙𝗹𝗼 = 𝗳𝗿𝗲𝗲(𝗹𝗮𝗯𝗲𝗹(G₀))</text>
<line x1="90" y1="372" x2="590" y2="372" stroke="#888780" stroke-width="0.5" stroke-dasharray="6 4" opacity="0.25"/>
<text class="ts" x="340" y="364" text-anchor="middle" fill="#888780" opacity="0.35">— construct + type-check —</text>
<line x1="340" y1="314" x2="340" y2="406" class="stroke-main" stroke-width="1" marker-end="url(#arrow)"/>
<rect x="120" y="390" width="440" height="86" rx="16" fill="#FAEEDA" stroke="#EF9F27" stroke-width="0.5" opacity="0.45"/>
<text class="ts" x="536" y="408" text-anchor="end" fill="#633806" opacity="0.7">Prof(Rig)</text>
<rect class="fill-teal" x="194" y="406" width="292" height="44" rx="8" stroke-width="0.5"/>
<text class="th text-teal" x="340" y="428" text-anchor="middle" dominant-baseline="central">SheetDiagram term</text>
<path d="M116 430 C86 430, 86 292, 116 292" fill="none" class="stroke-main" stroke-width="0.8" marker-end="url(#arrow)" opacity="0.5"/>
<text class="ts text-muted" x="74" y="364" text-anchor="end" opacity="0.45">𝗳𝗼𝗿𝗴𝗲𝘁</text>
<line x1="340" y1="450" x2="340" y2="536" class="stroke-teal" stroke-width="1.5" marker-end="url(#arrow)"/>
<text class="ts text-muted" x="358" y="496" text-anchor="start">𝗮𝘀𝘀𝘂𝗿𝗲</text>
<rect class="fill-teal" x="194" y="536" width="292" height="44" rx="8" stroke-width="0.5"/>
<text class="th text-teal" x="340" y="558" text-anchor="middle" dominant-baseline="central">DL𝜋 process term</text>
<text class="ts" x="46" y="52" text-anchor="start" fill="#888780" opacity="0.4">terminal</text>
<text class="ts" x="46" y="170" text-anchor="start" fill="#888780" opacity="0.4">data</text>
<text class="ts" x="46" y="292" text-anchor="start" fill="#888780" opacity="0.4">a category</text>
<text class="ts" x="46" y="428" text-anchor="start" fill="#888780" opacity="0.4">a category</text>
<text class="ts" x="46" y="558" text-anchor="start" fill="#888780" opacity="0.4">a category</text>
<text class="ts" x="634" y="110" text-anchor="end" fill="#888780" opacity="0.3">2-cell</text>
<text class="ts" x="634" y="234" text-anchor="end" fill="#888780" opacity="0.3">functor</text>
<text class="ts" x="634" y="364" text-anchor="end" fill="#888780" opacity="0.3">functor</text>
<text class="ts" x="634" y="496" text-anchor="end" fill="#888780" opacity="0.3">functor</text>
<text class="ts" x="340" y="620" text-anchor="middle" fill="#888780" opacity="0.4">Colored containers: ambient categories guaranteeing existence.</text>
<text class="ts" x="340" y="638" text-anchor="middle" fill="#888780" opacity="0.4">Inner nodes: the specific finite categories we compute in.</text>
<text class="ts" x="340" y="656" text-anchor="middle" fill="#888780" opacity="0.4">Every arrow is a functor. Every inner node is finite or finitely presented.</text>
</svg>

*Figure 1. The KlinikOS architecture. Every inner node is a specific finite (or finitely presented) object. Every arrow is a functor.*

### Reading the Diagram

**1** is the terminal category — one object, one morphism. The functor **𝗽𝗶𝗰𝗸** selects a specific finite tensor scheme G₀. The natural transformation **𝗹𝗮𝗯𝗲𝗹** refines **𝗽𝗶𝗰𝗸** into **𝗹𝗮𝗯𝗲𝗹**(**𝗽𝗶𝗰𝗸**), assigning FHIR [HL7 2019] clinical vocabulary to abstract sorts and generators.

**𝗹𝗮𝗯𝗲𝗹(G₀)** is the resulting labeled finite tensor scheme — combinatorial data, not yet a category. It lives in the ambient category **FinTensScheme** of finite tensor schemes and their morphisms.

The functor **𝗳𝗿𝗲𝗲** picks out a specific finitely presented traced symmetric monoidal category from the ambient **TracedSMC**. This category is **𝗑𝗙𝗹𝗼** — the space of all syntactically well-formed wirings of the labeled generators. It is the grammar of workflow descriptions.

Below the dashed line is the **construction problem**: given a workflow skeleton in 𝗑𝗙𝗹𝗼, construct a SheetDiagram term that type-checks in Lean 4. This is the resource allocation problem — a constraint satisfaction problem on the network. The resulting **SheetDiagram term** is a specific finite rig category. It lives in the ambient **Prof(Rig)** — the sub-bicategory of the bicategory of profunctors [Loregian 2023, Ch. 5] restricted to objects that are rig categories. (The full definition of **Prof(Rig)** is given in Appendix B.)

The functor **𝗳𝗼𝗿𝗴𝗲𝘁** runs back up from the SheetDiagram term to 𝗑𝗙𝗹𝗼, forgetting proof content and the additive structure ⊕, retaining the multiplicative workflow skeleton ⊗. Building a protocol is a **lifting problem** against **𝗳𝗼𝗿𝗴𝗲𝘁**: find a morphism m in the SheetDiagram such that **𝗳𝗼𝗿𝗴𝗲𝘁**(m) = f for a given skeleton f.

The functor **𝗮𝘀𝘀𝘂𝗿𝗲** compiles the SheetDiagram term into a **DLπ process term** — a specific finite category of subprocesses. It is defined generator-by-generator: each clinical operation in the SheetDiagram maps to a DLπ subprocess. The DLπ process term stands alone — it is the endpoint, with no ambient.

---

## 4. Finite Tensor Schemes and 𝗹𝗮𝗯𝗲𝗹(G₀)

A **finite tensor scheme** consists of:

- **Sorts** — finitely many wire types: the primitive resource types of the domain. In the clinical case: `Patient`, `Practitioner`, `Drug`, `Device`, `ConsentGiven`, `HeartRate`, etc. Each sort carries a rig assignment (Section 2).
- **Generators** — finitely many boxes: the primitive operations. Each generator has a **domain** and **codomain** that are finite lists (formal tensor products) of sorts. In the clinical case: `consentStep : [Patient, SharedLangEvidence] → [Patient, SharedLangEvidence, ConsentGiven]`.

A tensor scheme is not a directed multigraph. A multigraph has edges with single source/target vertices; a tensor scheme has generators with multi-sorted input/output lists. The free construction on a multigraph produces a free *category* (whose morphisms are paths); the free construction on a tensor scheme produces a free *monoidal category* (whose morphisms are wirings). The classical reference for this distinction is Leinster's treatment of PROs [Leinster 2004, §2.3, §6.6]; see Appendix A.

The functor **𝗽𝗶𝗰𝗸** : **1** → **FinTensScheme** selects a specific finite tensor scheme G₀. The natural transformation **𝗹𝗮𝗯𝗲𝗹** : **𝗽𝗶𝗰𝗸** ⇒ **𝗹𝗮𝗯𝗲𝗹**(**𝗽𝗶𝗰𝗸**) refines it by assigning FHIR types to sorts and named clinical operations to generators. Since the domain of both functors is **1**, this 2-cell is exactly a morphism G₀ → 𝗹𝗮𝗯𝗲𝗹(G₀) in **FinTensScheme**.

---

## 5. 𝗑𝗙𝗹𝗼 — the Finitely Presented Traced SMC

The functor **𝗳𝗿𝗲𝗲** applied to the labeled tensor scheme 𝗹𝗮𝗯𝗲𝗹(G₀) produces a specific category — **𝗑𝗙𝗹𝗼**, the category of *transform flows*. It is one specific object inside the large ambient category **TracedSMC** of traced symmetric monoidal categories.

**Objects** of 𝗑𝗙𝗹𝗼 are resource contexts — finite lists of FHIR-typed resource types (`Ctx = List Type`).

**Morphisms** are all syntactically well-formed wirings of the labeled generators: sequences, parallel compositions, swaps, and (once implemented) feedback via the trace.

𝗑𝗙𝗹𝗼 is **finitely presented** (finitely many sorts, finitely many generators) but not finite — free composition generates infinitely many morphisms. It is defined once for the full FHIR clinical vocabulary; different clinical protocols are different morphisms within the fixed 𝗑𝗙𝗹𝗼.

Because **𝗳𝗿𝗲𝗲** is a functor, the 2-cell **𝗹𝗮𝗯𝗲𝗹** propagates:

> **𝗳𝗿𝗲𝗲**(**𝗹𝗮𝗯𝗲𝗹**) : **𝗳𝗿𝗲𝗲** ∘ **𝗽𝗶𝗰𝗸** ⇒ **𝗳𝗿𝗲𝗲** ∘ **𝗹𝗮𝗯𝗲𝗹**(**𝗽𝗶𝗰𝗸**)

This is a traced SMC functor from **𝗳𝗿𝗲𝗲**(G₀) — the pure unlabeled topology — to 𝗑𝗙𝗹𝗼 — the labeled syntax.

𝗑𝗙𝗹𝗼 supports four of the six resource phenomena syntactically: transformation (morphism composition), allocation (⊗), division (rig-indexed splitting), and reuse (trace). It has one monoidal structure ⊗ only — no coproduct, no branching. It permits the trace and rig-indexed splits on *all* types without domain judgment. Domain restrictions are deferred to the SheetDiagram level.

In Selinger's taxonomy [Selinger 2010], 𝗑𝗙𝗹𝗼 sits in the cell **symmetric traced** (§5.7). The coherence theorem [Joyal, Street, and Verity 1996] guarantees the soundness of the graphical calculus.

As currently implemented in Fuchs [2026], 𝗑𝗙𝗹𝗼 is realised by the `Arrow` inductive type with constructors `step`, `seq`, `par`, `id`, `swap` — the free SMC (phenomena 1–2 only). See Appendix C for the full mapping.

---

## 6. The Construction Problem

The dashed line in Figure 1 marks the boundary between the freely generated syntax and the constrained construction. Above the line, everything follows from the tensor scheme by universal constructions. Below the line is a **resource allocation problem**: given the wiring diagram, find a consistent assignment of rig-valued resources to all wires satisfying all constraints.

### Rigs as Categories

Every rig (S, +, ·, 0, 1) with a compatible partial order ≤ is itself a bimonoidal category: objects are elements of S; a morphism a → b exists when a ≤ b; the addition + gives the additive monoidal structure ⊕ (with unit 0); the multiplication · gives the multiplicative structure ⊗ (with unit 1). A product of rigs is itself a rig. So a resource context — a finite list of rig-indexed resource types — determines a product rig, which is a bimonoidal category.

### Generators as Profunctors

Each generator in the tensor scheme is a clinical operation: it takes an input context (a product rig) and produces an output context (a product rig). The relationship between input and output is not a function — it is a *relation*, constrained by conservation laws, domain obligations, and proof requirements.

The categorified version of a relation between sets is a **profunctor** between categories [Loregian 2023, §5.1]. A profunctor P : C ⇸ D is a functor C^op × D → Set. Profunctor composition is given by the coend:

> (Q ⋄ P)(A, C) = ∫^B P(A, B) × Q(B, C)

This categorifies relational composition, where the coend plays the role of existential quantification over the intermediate variable [Loregian 2023, §5.1.5; Fong and Spivak 2019, §4.2]. See Appendix B for the full account.

Each generator in the tensor scheme, viewed as a profunctor between its input and output product rig categories, carries the conservation laws and domain constraints as conditions on the profunctor. The composite profunctor across the entire wiring diagram is the composition of these individual profunctors through the network's structure. A **consistent global assignment** is an element of this composite profunctor. The composite is *inhabited* if and only if the resource allocation problem has a solution.

### Iterative Narrowing

The constraint-satisfaction process begins with the most permissive profunctor — all rig values on all wires, unconstrained. Each constraint narrows it: apply conservation at a split, domain obligations at a scope boundary, the Dual classification at a feedback loop. Each narrowing is a morphism of profunctors. The iteration converges either to an inhabited profunctor (a solution exists) or to the empty profunctor (no solution exists). Because we work with finitely many sorts, finitely many generators, and finitely structured rigs, the iteration terminates.

When a constraint application fails — the narrowed profunctor becomes empty along some path — **backtracking** undoes the narrowing and returns to the prior, wider solution space. The forward step (constraint application) is conjecturally **left adjoint** to the backtracking step — a Galois connection on the poset of sub-profunctors, ordered by inclusion.

The solutions live in a small sub-bicategory of **Prof(Rig)** — profunctors between the specific product rig categories arising from the finite tensor scheme. The constraints being satisfied may, however, require a somewhat larger sub-bicategory of **Prof(Rig)**, because domain obligations (e.g. "the clinic is in the patient's city") reference structure beyond the rig arithmetic.

Currently, Fuchs [2026] solves this problem by **direct construction** with AI assistance — the LLM proposes SheetDiagram constructor expressions, and the Lean 4 type checker accepts or rejects them. The profunctor framing describes the mathematical structure of the search space, whether that search is conducted by hand, by AI, or by an algorithm.

---

## 7. The SheetDiagram Term — a Finite Rig Category

The result of the construction (Section 6) is a specific Lean 4 term of type `SheetDiagram Γ Δs`. This term, understood through its graph structure, determines a **finite rig category**:

**Objects** are the specific resource contexts appearing as intermediate states in the term — Γ, `afterConsent`, `afterHeart`, `afterBP`, etc. Finitely many.

**Morphisms** are the specific clinical actions (`Arrow.step` leaves) and structural combinators (`seq`, `par`, `branch`, `join`, `scope`) connecting them. Finitely many.

This finite rig category has two monoidal structures:

**⊗ within each sheet** — the Arrow/par/seq structure inherited from 𝗑𝗙𝗹𝗼. Witness: `Split Γ Δ₁ Δ₂`, a proof that every element of Γ goes to exactly one of Δ₁ or Δ₂ (allocation).

**⊕ between sheets** — the `branch`/`join`/`halt` structure. Witness: `Selection Γ Δ`, a proof that each element of Δ can be found in Γ (selection). The separation of ⊗ and ⊕ avoids the exponential DNF blowup [Comfort, Delpeuch, and Hedges 2020].

The SheetDiagram term adds four things beyond 𝗑𝗙𝗹𝗼:

1. **The additive structure ⊕** — branching, joining, halting.
2. **Proof obligations** — every scope entry requires an `AllObligations` proof term.
3. **The Dual classification** — restricting the trace to conserved resource types.
4. **Rig conservation enforcement** — restricting splits to those satisfying r₁ + r₂ = r.

Critically, **every generator from the original tensor scheme is individually present** as an `Arrow.step` leaf in the SheetDiagram term. No generator is fused or absorbed by the structural constructors. This is what makes the generator-by-generator compilation to DLπ possible (Section 8).

The SheetDiagram term lives in the ambient **Prof(Rig)**. The functor **𝗳𝗼𝗿𝗴𝗲𝘁** maps it back to 𝗑𝗙𝗹𝗼, forgetting proof content and collapsing the ⊕ structure. There is no forward functor from 𝗑𝗙𝗹𝗼 to the SheetDiagram — certification can fail. Building a protocol is a lifting problem against **𝗳𝗼𝗿𝗴𝗲𝘁**.

Fuchs' `erase : SheetDiagram st Γ Δs → Pipeline` is related to **𝗳𝗼𝗿𝗴𝗲𝘁** but goes further: **𝗳𝗼𝗿𝗴𝗲𝘁** drops proofs and ⊕ but retains typed structure (still Arrow terms, still typed contexts); `erase` additionally strips types, producing an untyped `Pipeline`. So `erase` = type-erasure ∘ **𝗳𝗼𝗿𝗴𝗲𝘁**.

For the detailed mapping of Lean 4 constructs, see Appendix C.

---

## 8. 𝗮𝘀𝘀𝘂𝗿𝗲 — Compilation to DLπ

**𝗮𝘀𝘀𝘂𝗿𝗲** is a functor from the finite rig category (the SheetDiagram term) to a finite subcategory of 𝗣𝗿𝗼𝗰 — the DLπ process space.

It is defined **generator-by-generator**: each `Arrow.step` in the SheetDiagram maps to a specific DLπ [Ciccone and Padovani 2020] subprocess. The structural constructors map to DLπ composition primitives:

| SheetDiagram construct | DLπ subprocess |
|---|---|
| `Arrow.step` | Send/Recv pair on a typed channel |
| `Arrow.par` / `Split` | Parallel composition P \| Q |
| `Selection` / `branch` | Channel offer and selection |
| Credit surrendered (counit) | Linear channel use with multiplicity #1 |
| Rig-indexed comultiplication | Dependent type splitting: Chan(r) → Chan(r₁) \| Chan(r₂) |
| Trace (credit-debit cycle) | Recursive session type μX.T [Dardha 2016] |

The functor is extended from generators to the whole finite category by **functoriality** — guaranteed because the source category was freely generated from the tensor scheme's generators. Both the source (the SheetDiagram term) and the target (the DLπ process term) are finite categories — finitely many objects, finitely many morphisms, all explicitly constructed as Lean 4 inductive types. The functor **𝗮𝘀𝘀𝘂𝗿𝗲** is itself a computable Lean 4 function defined by recursion on the SheetDiagram constructors.

**𝗮𝘀𝘀𝘂𝗿𝗲** is **independently constructed** from the specific constraints of a particular clinical trial. It is not given in advance by the platform. Every morphism in its domain has been certified; the translation necessarily produces a well-typed DLπ process. **𝗮𝘀𝘀𝘂𝗿𝗲** is a particular necessarily working program.

The end-to-end certificate — **PCT Claim 25** [Brown, Fuchs, and Sax 2026] — is the composition:

> **𝗮𝘀𝘀𝘂𝗿𝗲** ∘ construct ∘ **𝗳𝗿𝗲𝗲** ∘ **𝗹𝗮𝗯𝗲𝗹**(**𝗽𝗶𝗰𝗸**) : **1** → DLπ process term

Claim 25 states that the resulting program is executed to conduct the clinical trial, with each transition either dispatching a real-world instruction or validating that a real-world event has occurred, governing the ordering, authorization, and completion of clinical trial operations in accordance with the verified schedule of activities.

The DLπ process term has **no ambient category** in the diagram. It is the endpoint.

---

## 9. 𝗵𝗮𝘇𝗮𝗿𝗱 — The Open Question

For each clinical trial, a separate **𝗮𝘀𝘀𝘂𝗿𝗲** is independently constructed. The open question is whether a **universal** functor **𝗵𝗮𝘇𝗮𝗿𝗱** exists that subsumes every per-protocol **𝗮𝘀𝘀𝘂𝗿𝗲**: a single functor from the ambient **Prof(Rig)** to 𝗣𝗿𝗼𝗰 such that for every finite tensor scheme G₀, **𝗵𝗮𝘇𝗮𝗿𝗱** agrees with **𝗮𝘀𝘀𝘂𝗿𝗲** on the SheetDiagram term constructed from that tensor scheme.

If **𝗵𝗮𝘇𝗮𝗿𝗱** exists, KlinikOS is a **platform** — a single machine that correctly executes any certified protocol. If not, KlinikOS is a **family** — a collection of per-protocol compilers, each independently constructed and independently correct.

**𝗵𝗮𝘇𝗮𝗿𝗱** is currently deferred.

---

## Part III: Grounding

---

## 10. The Six Resource Phenomena

With all categories defined, we can state precisely the six phenomena that resource tokens exhibit, their categorical homes, and their Lean 4 constructs.

**1. Transformation.** A resource token enters a process and a different token exits. A morphism f : A → B.

**2. Allocation.** Tokens partitioned among parallel sub-processes. The separating conjunction ⊗. Witness: `Split Γ Δ₁ Δ₂`.

**3. Selection.** At a branch point, mutually exclusive branches select overlapping subsets of tokens. Additive contraction ⊕ [Girard 1987]. Witness: `Selection Γ Δ`.

**4. Consumption.** A token surrendered with no reissuance. Counit ε_A : A → I.

**5. Division.** A token carrying quantity r splits into tokens with r₁ + r₂ = r. Rig-indexed comultiplication δ_{r₁,r₂} : A(r) → A(r₁) ⊗ A(r₂).

**6. Reuse.** A conserved token cycles back via the trace Tr(f) : A → B, derived from the credit-debit cycle via the Int construction [Joyal, Street, and Verity 1996].

| Phenomenon | Structure | 𝗑𝗙𝗹𝗼 | SheetDiagram |
|---|---|---|---|
| Transformation | Morphism | `Arrow.step` | `SheetDiagram.arrow` / `.pipe` |
| Allocation | ⊗ | `Arrow.par` / `Arrow.swap` | `Split` |
| Selection | ⊕ | — | `Selection` / `branch` / `join` |
| Consumption | Counit | `Arrow.step` (empty output) | Scope exit |
| Division | Rig comultiplication | Proposed | Proposed |
| Reuse | Trace | Proposed | Proposed |

Phenomena 1–2 are implemented. Phenomena 3–4 are implemented at the SheetDiagram level. Phenomena 5–6 are specified but not yet implemented (see Appendix C).

---

## 11. Structure Preservation

Not every functor in the architecture is a plain functor. Several must preserve monoidal or richer structure.

| Functor | Preserves |
|---|---|
| **𝗽𝗶𝗰𝗸** | (object selection) |
| **𝗹𝗮𝗯𝗲𝗹** | Tensor scheme structure (sorts, generator signatures) |
| **𝗳𝗿𝗲𝗲** | (left adjoint; output has traced SMC structure by construction) |
| **𝗳𝗼𝗿𝗴𝗲𝘁** | ⊗, symmetry, trace (monoidal functor; forgets ⊕ and proofs) |
| **𝗮𝘀𝘀𝘂𝗿𝗲** | ⊗, ⊕, symmetry, trace, compact closed on dualizable objects |
| **𝗵𝗮𝘇𝗮𝗿𝗱** | (same as **𝗮𝘀𝘀𝘂𝗿𝗲**, universally) |

**𝗮𝘀𝘀𝘂𝗿𝗲** must be a rig functor (preserving both monoidal structures) that additionally preserves the compact closed structure on dualizable objects — mapping credit-debit pairs to session-typed channels and the trace to recursive session types. These structural requirements are substantial, which is part of why the existence of **𝗵𝗮𝘇𝗮𝗿𝗱** is non-obvious.

---

## 12. Authoring and Type Checking

The composition separates into two activities:

**Authoring** (creative, AI-assisted):

- **𝗽𝗶𝗰𝗸** — choose the abstract topology.
- **𝗹𝗮𝗯𝗲𝗹** — assign clinical vocabulary.

An LLM can assist with both. Authoring is where clinical judgment enters the system.

**Type checking** (at increasing depth):

- **𝗳𝗿𝗲𝗲** — *grammatical* type checking. Do wire types match at connection points? Are parallel compositions over disjoint sub-contexts? Built once.
- **construct** — *structural and domain* type checking. The construction problem of Section 6. Can a SheetDiagram term be built? Are all proof obligations dischargeable? This is where the LLM proposes constructor expressions and the Lean 4 type checker disposes. Per-protocol, AI-assisted.
- **𝗮𝘀𝘀𝘂𝗿𝗲** — *compilation*. Does the generator-by-generator mapping produce a well-typed DLπ process? Per-protocol, AI-assisted in construction.

Every artifact in the chain is a **Lean 4 inductive type** because it figures in computation. The category theory tells us what properties these types must satisfy. The implementation is the types themselves.

---

## Appendix A. Connection to Leinster's Framework

This appendix traces the intellectual lineage from Leinster's framework to the profunctor machinery used in the main body.

### A.1 The 1-Categorical Foundation

Leinster's *Basic Category Theory* [Leinster 2014] covers categories, functors, natural transformations, adjunctions, the Yoneda lemma, and limits/colimits. This is the foundation for the individual categories (𝗑𝗙𝗹𝗼, the SheetDiagram term, the DLπ process term) and the functors (**𝗳𝗼𝗿𝗴𝗲𝘁**, **𝗮𝘀𝘀𝘂𝗿𝗲**) between them.

### A.2 Monoidal Categories, Multicategories, and the Free Construction

Leinster's *Higher Operads, Higher Categories* [Leinster 2004] provides the next layers:

**§1.2**: Monoidal categories, the coherence theorem (Theorem 1.2.15), and monoidal functors (Definition 1.2.10). This is the foundation for the internal ⊗ and ⊕ structure of 𝗑𝗙𝗹𝗼 and the SheetDiagram term.

**Chapter 2, §2.3**: Multicategories, PROs, and PROPs. Definition 2.3.6 defines **modules** — Leinster's term for profunctors in the multicategorical setting. What we call a tensor scheme is Leinster's coloured PRO (Proposition 2.3.1). G₀ is the generating data for a coloured PRO.

**§6.6**: The adjunction **𝗳𝗿𝗲𝗲** ⊣ **𝗳𝗼𝗿𝗴𝗲𝘁** between T-structured categories and T-multicategories for any cartesian monad T. When T is the free monoid monad (Example 6.6.3), T-structured categories are strict monoidal categories. **𝗳𝗿𝗲𝗲** is the left adjoint specialised to traced SMCs; **𝗳𝗼𝗿𝗴𝗲𝘁** is the right adjoint extended to forget ⊕ and proofs. Proposition 6.6.12 guarantees that G₀'s generators embed faithfully into 𝗑𝗙𝗹𝗼.

### A.3 Bicategories and Modules — Where Leinster Opens the Door

**§1.5**: Bicategories. Example 1.5.5 — the bicategory of rings, bimodules, and bimodule maps — is the prototype for **Prof**. This is where Leinster introduces the structure that profunctors inhabit.

**§2.3, Definition 2.3.6**: Modules for multicategories. A (D, C)-module X : C ⇸ D consists of sets X(a₁, ..., aₙ; b) for each tuple of source objects and target object, with left and right actions by the morphisms of D and C. This is the multicategorical generalization of profunctors.

**Chapter 5**: fc-multicategories — Leinster's general framework integrating functors (vertical 1-cells) and modules/profunctors (horizontal 1-cells) into a single structure. Example 5.1.1 (Ring₂) is the 2-dimensional structure where rings, homomorphisms, bimodules, and tensor products cohabit. Our architecture has the same shape: the specific categories are the 0-cells, the functors (**𝗳𝗼𝗿𝗴𝗲𝘁**, **𝗮𝘀𝘀𝘂𝗿𝗲**) are the vertical 1-cells, and the profunctors in **Prof(Rig)** that describe the constraint-satisfaction problem are the horizontal 1-cells.

### A.4 Where Leinster Stops

Leinster provides the framework — bicategories, modules, fc-multicategories — but does not develop the bicategory **Prof** with its coend-based composition, its compact closed structure, or its monoidal structure. That development is in Loregian [2023, Chapter 5]. The applied resource-theoretic interpretation of profunctors as feasibility relations is in Fong and Spivak [2019, Chapter 4]. The graphical languages for each cell in the monoidal taxonomy are in Selinger [2010].

### A.5 Mapping

| Our construction | Leinster's framework | Extended by |
|---|---|---|
| Tensor scheme G₀ | Coloured PRO (§2.3, §6.6) | — |
| **𝗽𝗶𝗰𝗸** | Functor **1** → T-Multicat | — |
| **𝗹𝗮𝗯𝗲𝗹** | 2-cell; morphism of T-multicategories | — |
| **𝗳𝗿𝗲𝗲** | Left adjoint in **𝗳𝗿𝗲𝗲** ⊣ **𝗳𝗼𝗿𝗴𝗲𝘁** (§6.6) | — |
| **𝗳𝗼𝗿𝗴𝗲𝘁** | Right adjoint (§6.6) | — |
| Profunctors between rig categories | Modules (§2.3.6); horizontal 1-cells in fc-multicategories (Ch. 5) | Loregian Ch. 5; Fong-Spivak Ch. 4 |
| **Prof(Rig)** | Sub-bicategory of modules (§1.5.5, Ch. 5) | Loregian Ch. 5 |
| Constraint satisfaction as profunctor narrowing | — | Fong-Spivak Ch. 4; Loregian Ch. 5 |

---

## Appendix B. Profunctors and Rig Categories

### B.1 Rigs as Categories

A rig (S, +, ·, 0, 1) with a compatible partial order ≤ is a bimonoidal category: objects are elements of S; a morphism a → b exists when a ≤ b; + gives ⊕ (unit 0); · gives ⊗ (unit 1); distributivity of · over + is the rig category coherence [Laplaza 1972]. A product of rigs is a rig. Resource contexts — finite lists of rig-indexed types — determine product rigs.

### B.2 Profunctors

A **profunctor** P : C ⇸ D is a functor C^op × D → Set [Loregian 2023, Definition 5.1.2]. This categorifies the notion of a relation between sets: where a relation R ⊆ A × B assigns to each pair (a, b) a truth value, a profunctor assigns to each pair (c, d) a *set* — the set of ways that c and d are related.

Profunctor **composition** is given by the coend [Loregian 2023, §5.1]:

> (Q ⋄ P)(A, C) = ∫^B P(A, B) × Q(B, C)

This categorifies relational composition. Where relational composition uses existential quantification (∃b. R(a,b) ∧ S(b,c)), profunctor composition uses the coend — the categorified existential quantifier.

### B.3 The Bicategory Prof

**Prof** is a bicategory [Loregian 2023, Definition 5.1.2] whose 0-cells are small categories, 1-cells are profunctors, and 2-cells are natural transformations between profunctors. It is **compact closed** [Loregian 2023, §5.3; Fong and Spivak 2019, §4.5]: the dual of a category C is its opposite C^op; the cup η_C : 1 ⇸ C^op × C and cap ε_C : C × C^op ⇸ 1 are given by the hom-functor; the snake equations hold.

### B.4 Prof(Rig)

**Prof(Rig)** is the sub-bicategory of **Prof** whose 0-cells are rig categories (rigs with partial order, viewed as categories). Its 1-cells are profunctors between rig categories. Its 2-cells are natural transformations between such profunctors.

This is where the constraint-satisfaction problem of Section 6 lives. Each generator in the tensor scheme determines a profunctor between its input and output product rig categories. The composite profunctor across the network is the composition of these profunctors via coends. A consistent global assignment of rig values is an element of the composite profunctor.

### B.5 Profunctors as Feasibility Relations

The connection to Fong and Spivak's *Seven Sketches* [Fong and Spivak 2019, §4.2]: a Bool-profunctor (a profunctor enriched over {0,1}) is exactly a feasibility relation — it says whether a given output is feasible from a given input. A rig-profunctor is a *quantitative* feasibility relation, carrying resource accounting. The conservation law r₁ + r₂ = r at a split is a condition on the profunctor, not an opaque subset of a cartesian product.

---

## Appendix C. Embedding of Fuchs26

This appendix maps the Lean 4 constructs of Fuchs [2026] into the categorical architecture of the main body, drawing on both the monoidal framework (Appendix A) and the profunctor machinery (Appendix B).

### C.1 Construct Mapping

| Fuchs26 construct | Categorical location | Description |
|---|---|---|
| `Ctx = List Type` | Objects of 𝗑𝗙𝗹𝗼 and SheetDiagram | Resource contexts; product rig elements (Appendix B) |
| `Elem α Γ` | Infrastructure | De Bruijn witness that type α appears in context Γ |
| `Satisfy tel Γ frame` | Infrastructure for `Arrow.step` | Witness that a step's inputs exist in context |
| `Split Γ Δ₁ Δ₂` | ⊗ structure of SheetDiagram | Multiplicative partition; phenomenon 2 |
| `Selection Γ Δ` | ⊕ structure of SheetDiagram | Additive selection; phenomenon 3 |
| `Arrow Γ Δ` | Morphisms of 𝗑𝗙𝗹𝗼 | Free SMC on `Spec` steps |
| `SheetDiagram st Γ Δs` | Morphisms of the finite rig category | Rig category morphisms with proof obligations |
| `ScopeState`, `AllObligations` | Proof machinery | Constraint tracking and discharge at scope boundaries |
| `erase : SheetDiagram → Pipeline` | type-erasure ∘ **𝗳𝗼𝗿𝗴𝗲𝘁** | See C.2 |
| `scopedClinicalPipeline` | A specific morphism | The complete clinical trial pipeline for patient Jose |

### C.2 erase and 𝗳𝗼𝗿𝗴𝗲𝘁

**𝗳𝗼𝗿𝗴𝗲𝘁** is a functor between categories: it retains typed structure (Arrow morphisms, Ctx objects) but drops the ⊕ structure and proof content.

Fuchs' `erase` goes further: it strips types themselves, producing an untyped `Pipeline` — a computational skeleton with no resource types, no proof terms, no context lists. The relationship is:

> `erase` = type-erasure ∘ **𝗳𝗼𝗿𝗴𝗲𝘁**

**𝗳𝗼𝗿𝗴𝗲𝘁** is a functor (it lives in the categorical architecture). Type-erasure moves outside the categorical world into the runtime implementation.

### C.3 The Profunctor Perspective on SheetDiagram

The SheetDiagram term, understood as a finite rig category in **Prof(Rig)** (Appendix B), has a profunctor interpretation: each `Arrow.step` leaf is a profunctor between its input and output product rig categories, and the composite SheetDiagram is the composition of these profunctors through the network structure. The type-checking of the SheetDiagram term — the fact that it can be constructed in Lean 4 — is the proof that the composite profunctor is inhabited: a consistent global assignment exists. The free construction guaranteed by Leinster's adjunction (Appendix A, §A.2) ensures that this profunctor composition is well-defined and associative.

### C.4 Implementation Status

| Phenomenon | Fuchs26 status | Extension needed |
|---|---|---|
| 1. Transformation | Implemented (`Arrow.step`) | — |
| 2. Allocation | Implemented (`Arrow.par`, `Split`) | — |
| 3. Selection | Implemented (`Selection`, `branch`, `join`, `halt`) | — |
| 4. Consumption | Implemented (scope exit, step with empty output) | — |
| 5. Division | Not implemented | Rig-indexed types and conservation witness |
| 6. Reuse | Not implemented | `Arrow.cup/cap/trace` in 𝗑𝗙𝗹𝗼; `SheetDiagram.loop` |

The current implementation (phenomena 1–4, sorry-free, Lean 4 v4.25.0-rc2) suffices for single-visit protocols with unquantified resources. Chronic disease protocols require the traced extension. Dose management requires the rig-indexed extension.

---

## References

Atkey, R. (2009). Parameterised Notions of Computation. *Journal of Functional Programming* 19(3-4), 335–376.

Ciccone, L. and Padovani, L. (2020). A Dependently Typed Linear π-Calculus in Agda. *PPDP 2020*.

Coecke, B., Fritz, T., and Spekkens, R.W. (2016). A mathematical theory of resources. *Information and Computation* 250, pp. 59–86.

Comfort, C., Delpeuch, A., and Hedges, J. (2020). Sheet Diagrams for Bimonoidal Categories. arXiv:2010.13361.

Dardha, O. (2016). *Type Systems for Distributed Programs: Components and Sessions.* Atlantis Studies in Computing.

Fong, B. and Spivak, D.I. (2019). *An Invitation to Applied Category Theory: Seven Sketches in Compositionality.* Cambridge University Press.

Fuchs, M. (2026). Sheet Diagrams as Coproducts of Indexed Monads: A Lean 4 Calculus for Branching Resource-Typed Workflows. Docimion Corporation.

Brown, A.L. Jr., Fuchs, M.D., and Sax, F.L. (2026). Distributed Decentralized Clinical Trial: Design to Executable Digital Twin. PCT Patent Application BFS.P001.PCT.

Girard, J.-Y. (1987). Linear Logic. *Theoretical Computer Science* 50(1), pp. 1–102.

HL7 International (2019). FHIR R4: Fast Healthcare Interoperability Resources, Release 4. https://hl7.org/fhir/R4/.

Joyal, A. and Street, R. (1991). The Geometry of Tensor Calculus I. *Advances in Mathematics* 88(1), pp. 55–112.

Joyal, A., Street, R., and Verity, D. (1996). Traced monoidal categories. *Mathematical Proceedings of the Cambridge Philosophical Society* 119, pp. 447–468.

Laplaza, M. (1972). Coherence for Distributivity. *Lecture Notes in Mathematics* 281, pp. 29–65.

Leinster, T. (2004). *Higher Operads, Higher Categories.* London Mathematical Society Lecture Note Series 298, Cambridge University Press.

Leinster, T. (2014). *Basic Category Theory.* Cambridge Studies in Advanced Mathematics 143, Cambridge University Press.

Loregian, F. (2023). *Coend Calculus.* London Mathematical Society Lecture Note Series 468, Cambridge University Press. arXiv:1501.02503.

Sakayori, K. and Tsukada, T. (2019). A Categorical Model of an i/o-typed π-calculus. *ESOP 2019*, LNCS 11423, pp. 640–667.

Sangiorgi, D. and Walker, D. (2001). *The π-calculus: A Theory of Mobile Processes.* Cambridge University Press.

Selinger, P. (2010). A survey of graphical languages for monoidal categories. In *New Structures for Physics*, Lecture Notes in Physics 813, pp. 289–355. arXiv:0908.3347.

Toninho, B., Caires, L., and Pfenning, F. (2011). Dependent Session Types via Intuitionistic Linear Type Theory. *PPDP '11*, pp. 161–172.
