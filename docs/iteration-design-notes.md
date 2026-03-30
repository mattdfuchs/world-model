# From Traces to Promissory Notes: Type-Safe Iteration in KlinikOS

*Notes from discussion, March 2026. For Allen.*

---

## Starting Point: Allen's Trace as a Stream

Allen's notion of trace implies calling the same function repeatedly — this is a stream in the coinductive sense. But streams lack the inductive structure needed for termination proofs: there's no recursive value tending to zero.

The question: how do we model iteration in a way that unifies bounded processes (a clinical trial with N visits) and unbounded processes (weekly checkups while the patient is alive)?

## The Workflow-as-Proof View

We had previously established that the system's core type is essentially:

```
Patient → (Patient × Measurements × Consent) | (Patient × Refusal)
```

and that the entire workflow is a proof of this type (Curry-Howard). In the inductive case, repetition can be seen as a fixed point over this type — expand it at each iteration, find a terminating path (the base case), and prove the inductive step (which leads back to the original type at the recursive call, indicating it's time to recompile — i.e., figure out how to do the next iteration by expanding out in the same fashion).

But this doesn't work in the stream sense. There's no recursive value tending to zero. A patient's ongoing treatment has no structural base case. The patient dying is the stream becoming unproductive — a fundamentally different thing from an inductive base case like `Vial 0`.

## Two Fixed-Point Levels

This leads to a clean two-level architecture:

- **Inner (μ, inductive):** Each `SheetDiagram` is a finite proof term — a plan derived from current KB facts. Consumed step by step.
- **Outer (ν, coinductive):** The runtime trace is a stream of observations. Productive (each step yields an observation) but not well-founded.

```
νX. KB → (SheetDiagram × Trace) + Done
```

Each `SheetDiagram` is consumed inductively. When it's fully consumed or invalidated (a premise is falsified by an external event), we go around the ν-loop: query the KB, run proof search, get a new plan or terminate.

## The Promissory Note Mechanism

The key design insight: instead of modeling iteration as a primitive (bare trace / `!P`), mediate it with a **linear promissory note** in the context.

At iteration start, issue `Foo` into the context. The iteration body must produce evidence — either `Bar` (success) or `Baz` (failure):

- `Foo ⊗ Bar → next iteration` — the promissory note is redeemed, triggers continuation
- `Foo ⊗ Baz → done` — the promissory note is redeemed, triggers termination

**Why type-safe:** `Foo` is linear. It must be consumed. Only `Bar` or `Baz` can consume it. Each iteration is forced to produce evidence, and the evidence determines whether continuation happens. You can't skip the body. You can't silently loop.

### Unification of Bounded and Unbounded

Same mechanism, different promissory note:

| Scenario | Foo | Bar | Baz | Termination |
|---|---|---|---|---|
| Unbounded (weekly checkup) | `Obligation F` | `StillAlive` | `Deceased` | External event |
| Bounded (clinical trial) | `Obligation F n` | `SessionComplete` | `Refusal` | `n = 0` |

The bounded case indexes `Foo` by a decreasing Nat (same pattern as `Vial n` in the drug-dose example). The unbounded case has no index — same `Foo` every time, terminated by evidence of an external event. Both are instances of the same linear-token mechanism.

### What Foo Carries

The promissory note carries the **specification type** (which lives at Type 2, since it specifies what Types of interactions need to happen). It doesn't just say "you owe me something" — it says "you owe me a proof of THIS TYPE."

At the iterative step, when `Foo ⊗ Bar` fires, the system must construct a fresh proof of the specification from `Δ_current`. This is "recompile at the recursive call" made type-theoretically precise:

```
Foo ⊗ Bar
  → reflect(Δ_current)           -- what do we have now?
  → search(F, Δ_current)         -- find new proof of F from here
  → issue fresh Foo              -- new promissory note (cup)
  → execute new SheetDiagram     -- consume the proof
  → collect Bar or Baz           -- credit produced
  → cap                          -- cancel against Foo
  → repeat or stop
```

## Three-Level Type Architecture

This gives us three levels:

| Level | Universe | What it is | Example |
|---|---|---|---|
| **Specification** | Type 2 | Abstract interaction type | SoA: "8 visits, biweekly, BP at odd, VO2 at even" |
| **Plan/Proof** | Type 1 | Concrete `SheetDiagram` | Allen at ValClinic, Room3, all constraints discharged |
| **Execution** | Runtime | Coinductive trace | Stream of actual observations |

A clinical trial's Schedule of Activities (SoA) is the canonical Type 2 object. It specifies what abstractly needs to happen — some number of encounters, spaced in a certain way, with certain activities at each — without saying who, where, or proving any constraints.

The compilation of an SoA encounter into a `SheetDiagram` is proof search. Compilation can fail — if the KB can't satisfy the encounter's constraints (clinician moved, clinic lost approval), the promissory note can't be redeemed. This failure is visible before the encounter happens, which is the entire point of the type system.

This also gives us two natural presentations of the same data:

1. **Visual SoA:** render the Type 2 spec — a table or timeline. What the trial coordinator sees and edits.
2. **Compiled plan:** the SheetDiagram proof — what operations sees. Clinician assigned, clinic booked, equipment reserved, all evidence discharged.

## Mapping to the π-Calculus

### The Promissory Note is a Continuation Channel

This is the connection back to your document. In the π-calculus encoding, `Foo` is **not** `!Foo` (replication). It is a continuation channel threaded through the process:

```
(νk)( iteration_body⟨k⟩ | k(result). match result { bar → next, baz → done } )
```

- `k` is created fresh per iteration — this is the cup, `(νk)`
- `k` is passed as an argument through the process — threaded, not broadcast
- `k` is used exactly once to deliver `Bar` or `Baz` — linear
- `k` is consumed on delivery — this is the cap

This is continuation-passing style. The promissory note means "when you're done, call me back on this channel with your evidence." The receiver is blocked on `k`, waiting for the iteration body to signal.

In DLπ's session typing, `k` carries:

```
k : ⊕{ success: T_next, failure: end }
```

The process holding `k` must eventually send on it — that's the linear obligation. The receiver pattern-matches on the label to decide continuation vs termination.

### Why Not `!P`

The bare trace (`!P` / `rec X.P`) would be replication without accounting. It copies the process and all its channel references, violating exactly-once usage. A replicated drug dose channel lets you administer the same dose repeatedly — the double-spending that linearity prevents.

The continuation channel avoids this entirely: `k` is created fresh each iteration, used once, consumed. No copying, no implicit reuse.

### Connection to Your Cup/Cap Framework

The promissory note mechanism IS the cup/cap trace from your document, arrived at from the operational side:

- **Cup** = issue the continuation channel `k` via `(νk)` (the promissory note / debit)
- **Process** = run iteration body, eventually sending on `k` (producing the credit)
- **Cap on success** = `k` receives `bar`, both endpoints consumed, issue fresh `k'` for next iteration
- **Cap on failure** = `k` receives `baz`, both endpoints consumed, stream terminates

Each iteration is a fresh credit-debit cycle on a fresh channel — this is Dardha's recursive session type `μX.T`. The backward wire (the "loop again" signal from traced monoidal feedback) is resolved into two forward wires: the continuation channel going in, the evidence coming back out. No wire travels backward.

### Summary

The bare trace says "this happens again."

The continuation channel says "this happens again, here is the fresh channel for this iteration's accounting, and the iteration body must produce evidence on that channel to trigger the next cycle."

The Selinger hierarchy plays out exactly:
1. **Progressive** (current `Arrow`): pure forward flow, no feedback
2. **Traced** (bare `!P`): feedback without accounting — available at xFlo level, breaks linearity
3. **Compact closed** (continuation channel per iteration): feedback with fresh accounting — enforced at `SheetDiagram` level by the Dual classification

The choice is determined by the resource physics. Conserved resources (practitioners, equipment) get cup/cap with continuation channels. Consumed resources (drug doses, measurements) get `drop`. The type system enforces which is which.

## Channels Are Resources (Allen's Observation)

In DLπ, virtually every message sent and received corresponds to a resource in the DSL. The exception appears to be the channels themselves — but under linearity, channels are just resources too.

A linear channel is created as two endpoints (read/write) with complementary capability types. This is cup. It is used exactly once on each endpoint. This is the linear obligation. Both endpoints are consumed on communication. This is cap. Channels in DLπ are resources by virtue of linearity.

### Dardha's μ and Effective Linearity

Dardha extends typed linear π with the μ operator on processes with linear channels. μ locally binds a reusable channel over the scope of a process — the same pattern as declaring a physician reusable within a context.

The channel (or physician) is "checked in" at the top of the scope and "checked out" at the bottom. μ then unwinds a new copy, checking in again. At any given time, there is exactly one consumer — **effective linearity**. The same resource is never checked in twice in a row, nor checked out twice in a row. μ unfolds exactly one copy of the program text containing one send and one receive on the channel.

This maps directly to our `scope` constructor with `ext`/`kept`:

- `ext` = check-in (resource enters scope)
- `kept` = check-out (resource exits scope, possibly transformed)
- Inner SheetDiagram uses the resource exactly once (linear within the scope)
- The ν-loop unfolds the next copy with fresh state (next iteration of μ)

### Three Resource Kinds

This gives us three genuinely different roles, all handled by the same linear framework, distinguished by typeclasses:

| Kind | Example | π-calculus role | Typeclass |
|---|---|---|---|
| **Atomic/payload** | DrugDose, Measurement | Message data — flows on channels, consumed | `Consumed` (drop only) |
| **Conserved resource** | Physician, Clinic, Equipment | Channel endpoint — complementary pair | `Dual` (cup/cap) |
| **Process/program** | Clinical trial, SoA encounter | Process term — unfolds via μ | `Dual` + `Specification` |

The third kind is the interesting one. A promissory note `Obligation F n` sits in the context like any other linear resource — it has a dual, it's created (cup) and consumed (cap). But its payload is a Type 2 specification `F`, and redeeming it requires constructing a fresh proof of `F`. A physician just needs to be present; a promissory note needs to be *proved*.

No separate "channel layer" is needed. The `Dual` typeclass covers both physical resources and channels. The difference between a clinic and a trial is that a clinic's check-in/check-out is about *presence*, while a trial's is about *proof*.

## Refinement as CPS Transformation

The workflow is built through successive refinement, starting with the Type 2 specification. The refinement to DLπ is a CPS transformation of the workflow.

```
Type 2 (SoA spec)
  —[proof search, creative, can fail]→
Type 1 (SheetDiagram, direct style)
  —[CPS transform, mechanical, always succeeds]→
DLπ process (executable)
```

The first arrow is **proof search** — creative, uses LLM agents, can fail if constraints are unsatisfiable. This is where the intelligence lives.

The second arrow is **CPS transformation** — mechanical, structure-preserving, always succeeds. Every SheetDiagram construct has a fixed translation:

| SheetDiagram (direct style) | DLπ (CPS) |
|---|---|
| `pipe a s` | Run `a`, send result on continuation `k`, `s` receives on `k` |
| `seq s1 s2` | Run `s1`, send output on `k`, `s2` receives on `k` |
| `scope ext kept body` | `(νk)` — create channel pair, send `ext` in, receive `kept` out |
| `branch` | Send on choice channel `⊕{left: ..., right: ...}` |
| `drop` | No message — resource silently consumed |
| Promissory note | `k(result). match result {...}` — receive on continuation, dispatch |

The SheetDiagram is direct-style: "do this, then that, inside this scope." The DLπ encoding makes every "then" into an explicit channel: "do this, send the result *here*, and *there* is a process waiting for it."

The CPS transform of a well-typed SheetDiagram is automatically a well-typed DLπ process — linearity is preserved by the transformation. The three resource kinds map to three CPS patterns:

- **Atomic** (dose): becomes the payload of a send. No continuation channel of its own.
- **Conserved** (physician): becomes a channel pair. CPS introduces the continuation — check-in is send, check-out is receive.
- **Process** (trial): becomes a recursive process under μ. CPS + Dardha's unfolding.

The promissory note literally IS the continuation in CPS: "call me back on this channel with your evidence."

### Katis-Sabadini-Walters (2002) Confirmation

The factorization chain from "Feedback, Trace and Fixed-Point Semantics":

```
MONOIDAL →(Circ) FEEDBACK →(Q) TRACED →(Int) COMPACT CLOSED
```

confirms that our placement at compact closed (not feedback or traced) is a genuine structural choice. The yanking axiom (which distinguishes traced from feedback) must NOT hold for linear resources — looping a vial channel without drawing a dose is a type error, not a no-op. Our `Dual` classification forces the compact closed structure, where every feedback wire has fresh accounting via cup/cap.
