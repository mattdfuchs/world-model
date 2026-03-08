# Rig Categories, Sheet Diagrams, and Coproducts of Indexed Monads

## Setup

We are building a type-level specification language for clinical workflows in Lean 4. The specification language is an arrow calculus — a free symmetric monoidal category (SMC) on a signature of typed steps. Each step transforms a context (a list of typed resources):

$$\text{Arrow} : \text{Ctx} \to \text{Ctx} \to \text{Type}$$

with constructors for identity, sequential composition, parallel composition, and swap. This is standard: the free SMC on a signature is the type of string diagrams, and our `Arrow` inductive is its term representation.

The system works well for linear pipelines. A clinical measurement session is a sequence of steps:

```
consent ⟫ heartRate ⟫ bloodPressure ⟫ vo2Max ⟫ products ⟫ assessment
```

where each step consumes some resources from the context and produces new ones. Sequential composition threads the context forward. The type of the composite arrow is a complete specification of every valid execution.

## The problem: branching

Real workflows branch. A patient may consent or refuse. A measurement may succeed or fail. An adverse event may trigger protocol deviation. Each branch leads to a different continuation with different resource requirements.

The natural categorical structure for branching is the coproduct $\oplus$. Adding $\oplus$ alongside $\otimes$ yields a rig category (bimonoidal category) — a category with two monoidal structures where one distributes over the other:

$$\Gamma \otimes (\Delta_1 \oplus \Delta_2) \cong (\Gamma \otimes \Delta_1) \oplus (\Gamma \otimes \Delta_2)$$

The standard tool for coproduct elimination is:

$$\text{copair} : \text{Arrow}(\Gamma, E) \to \text{Arrow}(\Delta, E) \to \text{Arrow}(\Gamma \oplus \Delta, E)$$

## The difficulty with a monolithic approach

Our specification language is built on an indexed monad $M\;\Gamma\;\Delta\;\alpha$, where $\Gamma$ is the pre-context (resources available on entry), $\Delta$ is the post-context (resources available on exit), and $\alpha$ is a return type. Bind threads the context:

$$\text{bind} : M\;\Gamma\;\Delta\;\alpha \to (\alpha \to M\;\Delta\;E\;\beta) \to M\;\Gamma\;E\;\beta$$

If we embed $\oplus$ into the context type, then after a branch point the context becomes $\Delta_1 \oplus \Delta_2$, and every subsequent step must be polymorphic over which branch was taken — either working uniformly on both branches or explicitly case-splitting. The context algebra becomes a semiring, and the types grow rapidly.

Worse, the distributive law causes a DNF blowup. After $k$ binary branch points, the context is a sum of $2^k$ product terms. Each product term carries its own copy of every shared resource. This is the categorical analogue of the exponential blowup in disjunctive normal form for propositional logic.

## The sheet diagram perspective

Comfort, Delpeuch, and Hedges (*Sheet Diagrams for Bimonoidal Categories*, arXiv:2010.13361) introduce a graphical calculus for rig categories. The key geometric idea:

- $\otimes$ is represented by **wiring on a surface** — ordinary string diagrams.
- $\oplus$ is represented by **stacking surfaces** — creating parallel sheets.

A branch point takes one sheet and splits it into multiple sheets. Each sheet carries its own string diagram. Sheets evolve independently and only interact at $\text{copair}$ boxes, where multiple sheets collapse into one. The main theorem is that sheet diagrams form the free bimonoidal category on a signature.

## The observation: coproduct of indexed monads

Reading the sheet diagram geometry through the indexed monad lens suggests a decomposition. Rather than a single indexed monad $M\;\Gamma\;\Delta\;\alpha$ with coproducts embedded in $\Gamma$ and $\Delta$, the system after a branch point is a **coproduct of indexed monads**:

$$M_1\;\Gamma_1\;\Delta_1\;\alpha_1 \;\oplus\; M_2\;\Gamma_2\;\Delta_2\;\alpha_2 \;\oplus\; M_3\;\Gamma_3\;\Delta_3\;\alpha_3$$

Each summand corresponds to a sheet. Within each sheet, the indexed monad is the same simple forward-threading monad over a product context — exactly the structure that works well for linear pipelines. No individual monad ever sees a $\oplus$. The branching structure lives *between* monads as an external coproduct, not *inside* any single monad's context type.

At a branch point, the current context $\Gamma$ is partitioned:

$$\Gamma \;\cong\; \Gamma_{\text{left}} \otimes \Gamma_{\text{right}} \otimes \Gamma_{\text{parallel}}$$

- $\Gamma_{\text{left}}$ becomes the input context for the left branch's sheet.
- $\Gamma_{\text{right}}$ becomes the input context for the right branch's sheet.
- $\Gamma_{\text{parallel}}$ becomes the input context for a third sheet carrying any context that neither branch needs but that must be preserved for use after rejoining.

Each sheet then evolves its context independently via ordinary sequential and parallel composition. The sheets rejoin at a $\text{copair}$ point, where we require the two branch sheets to have produced a common output context.

### What this buys us

1. **Each sheet is simple.** The forward-threading, context-accumulating indexed monad we already have works unchanged on every sheet. No new internal complexity.

2. **No DNF blowup.** We never distribute $\Gamma$ into each branch. The partition is a three-way split of the original context, not a duplication.

3. **Branching is structural, not contextual.** Branch points and join points are operations *on the collection of sheets*, not operations inside any sheet's context type. The monoidal structure within sheets and the coproduct structure between sheets live at different levels.

4. **The partition problem localises.** The question "what does each branch need?" is answered by the input types of each branch's first arrow. The partition is certified by a split witness — a proof that $\Gamma_{\text{left}} \otimes \Gamma_{\text{right}} \otimes \Gamma_{\text{parallel}} = \Gamma$ — which is a local obligation at the branch point, not a pervasive concern.

### What remains hard

The partition at branch points is **demand-driven**: the correct split of $\Gamma$ depends on what each branch will consume, and that information flows backward from the branch bodies to the split point. In the sheet diagram picture, when you "lay out" a sheet, you implicitly decide which wires cross onto it, and that decision is informed by what boxes live on that sheet. The diagram is constructed holistically, not left-to-right.

Three approaches to this:

- **Explicit annotation.** The user specifies the partition. Verbose but straightforward.
- **Two-pass construction.** Build the branch arrows first (learning their input types), then compute the partition as a derived split. This is the "reverse generation" of the context.
- **Constraint-based.** Leave the partition as metavariables and unify. Lean's elaborator may handle this naturally with `_` placeholders.

The join point also requires care: $\text{copair}$ demands that both branch sheets produce the same output context. When branches produce genuinely different outputs, we need either padding (adding units to equalise) or a weaker compatibility condition (a shared subcontext that suffices for downstream computation).

## Relationship to existing work

The ingredients here are well-known:

- **Indexed monads**: Atkey (2009), *Parameterised Notions of Computation*.
- **Rig categories and sheet diagrams**: Comfort, Delpeuch, Hedges (2020).
- **Session types with branching**: Wadler (2012), *Propositions as Sessions* — each branch of an $\oplus$ offer proceeds independently with its own continuation, which is operationally the same decomposition.
- **Linear logic**: the additive $\oplus$ creates separate proof obligations with separate context subsets.

The geometric content (sheets as independent diagrams) is in Comfort–Delpeuch. The monadic content (indexed monads for resource tracking) is in Atkey. What we have not found stated explicitly in the literature is the bridge: that a rig-category arrow system decomposes into an external coproduct of plain SMC indexed monads, one per sheet, so that $\otimes$ and $\oplus$ never cohabit inside a single monad's context. This may be implicit in some combination of the above, but the explicit decomposition — and particularly its practical consequence that each sheet can reuse the simple forward-threading monad without modification — seems worth noting.

## References

- Atkey, R. (2009). *Parameterised Notions of Computation.* Journal of Functional Programming, 19(3-4), 335–376.
- Comfort, C., Delpeuch, A., & Hedges, J. (2020). *Sheet Diagrams for Bimonoidal Categories.* arXiv:2010.13361.
- Laplaza, M. (1972). *Coherence for Distributivity.* Lecture Notes in Mathematics, 281, 29–65.
- Wadler, P. (2012). *Propositions as Sessions.* ICFP '12.
