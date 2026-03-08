# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Monorepo for a Lean4 + Python + Neo4j + n8n workflow. Claude (via n8n) picks numbers, Lean4 computes on them via a Python MCP server, and results are stored in Neo4j via the Neo4j MCP server.

## Architecture

Four Docker services orchestrated via `docker-compose.yaml`:

- **python-mcp** (`python/`): FastAPI server (port 7010) wrapping LeanInteract to run Lean commands/files. Not yet a full MCP server — uses REST endpoints (`/lean/build`, `/lean/command`, `/lean/file`, `/health`, `/tools`).
- **mcp-neo4j** (`mcp/neo4j/`): Official Neo4j MCP binary in HTTP mode (port 7011). Accepts JSON-RPC at `/mcp` with Basic Auth.
- **neo4j**: Neo4j 5 Community (browser at 7474, bolt at 7687).
- **n8n**: Workflow automation (port 5678). Orchestrates calls between services. Accesses `ANTHROPIC_API_KEY` and `NEO4J_MCP_AUTH_HEADER` via env allowlist.

The test workflow (`n8n/workflows/test-components.json`) chains: Manual Trigger → Python health check → Claude API (pick numbers) → Lean command (sum) → Neo4j MCP (init → tools/list → write → read).

## Build & Run Commands

```bash
# Start entire stack
docker compose up -d

# Rebuild after code changes
docker compose up -d --build

# Lean4 (requires lake on PATH)
cd lean4 && lake build                    # build all targets
cd lean4 && lake build worldmodel_test    # build test executable
cd lean4 && lake env lean --run Test.lean # run tests

# Python service (local dev)
cd python && python -m venv .venv && source .venv/bin/activate
pip install -e .                          # install deps
pip install -e ".[dev]"                   # install with pytest
uvicorn world_model.mcp_server:app --host 0.0.0.0 --port 7010
pytest                                    # run tests (when tests exist)
```

## Key Configuration

- `.env` (copied from `.env.example`): Neo4j creds, MCP versions/ports, Anthropic API key, n8n auth settings.
- `LEAN_PROJECT_PATH` env var: tells the Python service where the Lean4 project lives (set to `/app/lean4` in Docker).
- Neo4j MCP auth: `NEO4J_MCP_AUTH_HEADER` should be `Basic <base64(user:password)>`. The n8n workflow currently has a hardcoded auth header that must match your Neo4j credentials.

## Lean4 Project Structure

- Toolchain: `leanprover/lean4:v4.25.0-rc2`
- Library root: `WorldModel.lean` imports `Basic`, `Logic`, `Examples`
- `WorldModel.Basic`: placeholder (`hello`, `greet`)
- `WorldModel.Logic`: arithmetic + theorems (`add`, `add_comm`)
- Default executable: `Main.lean`; test executable: `Test.lean`
- No external Lake dependencies (empty `lake-manifest.json` packages)

## Python Package Layout

Source lives in `python/src/world_model/`. Entry point: `world_model.mcp_server:app`. `LeanClient` (`lean_client.py`) manages a thread-safe `LeanServer` instance. The Dockerfile installs elan/lake inside the container via `install-lean` (provided by `lean-interact`).

---

## WorldModel Architecture — Core Design Insight

### Boxes as an Indexed Monad

The `Box`/`Pipeline` system in `lean4/WorldModel/KB/` is the static, type-level shadow of a richer two-level architecture. Understanding both levels is essential.

#### The Two Levels

**Type level — the space of correct executions**

Boxes are transformers and their inputs/outputs are typed objects. The correct way to think about pipeline construction is as an **indexed monad** `M Γ Δ α`, where:

- `Γ` is the *pre-context*: the set of typed objects available on entry
- `Δ` is the *post-context*: the set of typed objects available on exit
- `α` is the return type

Sequential composition (bind) threads the context:

```
bind : M Γ Δ α → (α → M Δ Ε β) → M Γ Ε β
```

The type of a pipeline IS a specification of every correct execution — it defines an invariant space that all concrete runs must inhabit. This is not just validation; it is the full set of permitted behaviours expressed as a type.

**State level — actual execution**

A concrete state monad tracks position within the type-level space: which steps have completed, what values were produced, which constraint certificates have been satisfied, what timestamps were recorded. The state monad carries the runtime evidence that the type-level conditions hold. It is the computational content of the type-level proof term.

#### Constraints as Monadic Queries

Each box, at construction time, queries the monad's context for the capabilities it requires:

```lean
requireCapability (BPAuthorization "Jose") : M Γ Γ BPAuthorization
requireTimeSince  "Jose" "DrugX" 24h       : M Γ Γ Unit
```

Different steps can demand different constraint types. The pipeline type aggregates all demands. This avoids the limitation of a single flat `LegalMeasurementMeeting` bundle — step-local constraints (e.g. BP certification), meeting-level constraints (clinic location, shared language), and cross-session constraints (time between doses) each live at the right level.

#### Nesting

Sub-pipelines are composite monadic actions running in the same indexed context. Inner boxes see the same `Γ` as outer ones and can query and extend it. The existing `Step (Pipeline types wirings)` instance is a degenerate form of this — the full monadic version makes the context flow explicit.

#### The Interplay — Re-planning and Backtracking

The two levels interact when real-world events require plan revision (e.g. a patient reschedules an appointment).

After partial execution:
```
M Γ Δ_final α          — original pipeline type (full plan)
     ↓ partial execution
M Δ_current Δ_final α  — continuation type (remaining plan)
```

When circumstances change:

1. **Reflect** — reconstruct the type-level context `Δ_current` from the runtime state. Completed steps have produced typed certificates; these form an `HList` over `Δ_current`.
2. **Re-plan** — construct a new `M Δ_current Δ_final' α'` under revised constraints. The type checker verifies the new plan is correct from where execution stands.
3. **Carry forward** — objects already in `Δ_current` are inherited by the new pipeline without re-running completed steps.

This is incremental proof construction: the pipeline is a proof term, partial execution consumes part of it, and rescheduling extends or revises the remaining proof obligations.

#### Connection to the Knowledge Graph

The Neo4j KB is the **event log** — the ground facts from which all constraint evidence is derived. The type-level pipeline is always a *derived view* of those facts. When the KB is updated (appointment rescheduled, new fact asserted), a new pipeline type is derived automatically. The type derivation IS the re-planning step. This is the event-sourcing pattern: KB = source of truth, pipeline = derived specification.

#### Current State vs. Target Architecture

| Layer | Current implementation | Target |
|---|---|---|
| Shape validation | `Pipeline types wirings` + `native_decide` | Same, as the static skeleton |
| Constraint evidence | `LegalMeasurementMeeting patientName` as type parameter | Generalised to per-step capability queries in the indexed monad |
| Runtime execution | Not yet implemented | State monad tracking certificates, timestamps, history |
| Re-planning | Not yet implemented | `reflect` operation from `RuntimeState` to `TypeContext` + re-derivation from KB |

The natural next implementation step is defining `M Γ Δ α` in Lean 4 and showing that the existing `Pipeline` construction is a degenerate (fully static, no runtime state) instance of it.
