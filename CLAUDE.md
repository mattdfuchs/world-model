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
