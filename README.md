# World Model Monorepo

A formally verified clinical-pipeline construction system. An LLM Designer agent queries a Neo4j knowledge graph and proposes a pipeline plan; a Prover agent translates it into Lean 4 Arrow/SheetDiagram code that the type checker verifies. The pipeline is expressed as a free symmetric monoidal category with nested scopes, branching, and joining.

## Components

- `lean4/`: Lean 4 knowledge base and formal pipeline framework.
  - `KB/Types.lean` — domain entity types (Patient, Clinic, Equipment, etc.)
  - `KB/Facts.lean` — ground-fact predicates (`speaks`, `treats`, etc.)
  - `KB/Arrow/` — the Arrow/SheetDiagram framework (contexts, specs, arrows, selections, scopes, branching)
  - `KB/Arrow/Clinical.lean` — worked example: 6-stage clinical pipeline with 4 branch points, 3 joins, 3 nested scopes
  - `KB/Arrow/Erase.lean` — type erasure for pretty-printing pipeline structure
  - `KB/ActionCatalog.lean` — action catalog with constraints, categories, and Neo4j edges
  - `KB/Neo4j/` — `ToNeo4j`/`FromNeo4j` deriving handlers for serializing KB types to Cypher
  - `SeedNeo4j.lean` — generates Cypher to seed Neo4j with all KB facts and action catalog
- `python/`: FastAPI server (port 7010) wrapping LeanInteract. Endpoints: `/lean/command`, `/lean/command/raw`, `/neo4j/read`, `/neo4j/schema`.
- `mcp/neo4j/`: Official Neo4j MCP binary in HTTP mode (port 7011). `script.txt` contains the generated Cypher seed.
- `n8n/`: Workflow automation (port 5678).
  - `workflows/PipelineConstruction.json` — Designer → Prover pipeline with retry
  - `prompts/designer.md`, `prompts/prover.md` — LLM system prompts
- `docs/`: Design documents, topology diagrams, and rendered pipeline diagrams.
- `docker-compose.yaml`: Local dev stack (Neo4j, n8n, Python MCP, Neo4j MCP).

## Quick Start

### 1. Configure environment

```bash
cp .env.example .env
```

Edit `.env` and fill in:
- `NEO4J_PASSWORD` — choose a password for Neo4j.
- `NEO4J_MCP_AUTH_HEADER` — set to `Basic <base64 of neo4j:your-password>`. Generate with:
  ```bash
  echo -n "neo4j:your-password" | base64
  ```
- `ANTHROPIC_API_KEY` — your Anthropic API key.

### 2. Start the stack

```bash
docker compose up -d --build
```

Wait for all four services to become healthy. First build will take several minutes (Lean toolchain installation).

### 3. Seed the database

Generate and load the Cypher seed:

```bash
cd lean4 && lake env lean --run SeedNeo4j.lean > ../mcp/neo4j/script.txt
```

Then trigger the seed via the n8n workflow's Manual Trigger, or load directly:

```bash
cat mcp/neo4j/script.txt | docker compose exec -T neo4j cypher-shell -u neo4j -p <your-password>
```

### 4. Open n8n

Open http://localhost:5678 in your browser. If prompted, create an n8n owner account (local only).

### 5. Create Anthropic credentials in n8n

1. Go to **Settings > Credentials**.
2. Click **Add Credential**, search for **Anthropic**, and select **Anthropic API**.
3. Paste your API key.
4. Click **Save**.

### 6. Import the workflow

```bash
docker compose cp n8n/workflows/PipelineConstruction.json n8n:/tmp/PipelineConstruction.json
docker compose exec n8n n8n import:workflow --input=/tmp/PipelineConstruction.json
```

Refresh the n8n browser tab and open the imported workflow. Assign your Anthropic credential to the Designer and Prover agent nodes.

### 7. Run a pipeline construction

Trigger the workflow with a patient name. The Designer queries Neo4j for available actions, equipment, qualifications, and shared-language evidence, then proposes a pipeline plan. The Prover converts the plan into Lean 4 code, verifies it type-checks, and outputs:

1. The verified Lean 4 code
2. A Mermaid flowchart diagram of the pipeline

If verification fails, the Prover retries once with error feedback.

## Architecture

```
Manual Trigger → Designer Agent → Extract Plan → Prover Agent → Parse Result
                                                     ↓ (on failure)
                                                  Prover Agent 2 → Parse Result 2
                                                     ↓ (success)
                                                  Format Output
```

**Designer Agent** tools: `read_cypher`, `get_neo4j_schema`
**Prover Agent** tools: `read_cypher`, `lean_command`

### Lean 4 Arrow Framework

The pipeline is modeled as a free symmetric monoidal category:

- **Ctx** — a list of types representing available objects
- **Arrow Γ Δ** — a morphism from context Γ to context Δ (sequential, parallel, identity, swap)
- **SheetDiagram Γ Δs** — extends arrows with scoping, branching, and joining
- **Scope** — introduces resources (equipment, qualifications) available to inner steps; strips them from outputs
- **Branch/Join** — models success/failure paths (e.g., consent refused → disqualification)
- **elem_tac** — tactic that auto-resolves context membership, eliminating manual de Bruijn indices

### Knowledge Graph

Neo4j stores entities (Patient, Clinician, Clinic, Equipment, etc.) and relations (treats, speaks, hasQualification, clinicHasRoom, etc.), plus an action catalog (REQUIRES/PRODUCES edges). All seeded from Lean 4 via `SeedNeo4j.lean`.

## Editing the Knowledge Base

- **Neo4j data**: Regenerate with `cd lean4 && lake env lean --run SeedNeo4j.lean > ../mcp/neo4j/script.txt`, then re-seed.
- **Lean 4 types/relations**: Edit files under `lean4/WorldModel/KB/`. After changes, rebuild with `cd lean4 && lake build` and restart the `python-mcp` container.
- **LLM prompts**: Edit `n8n/prompts/designer.md` or `n8n/prompts/prover.md`, then sync to the workflow JSON and re-import in n8n.

## Build Commands

```bash
# Full stack
docker compose up -d --build

# Lean 4
cd lean4 && lake build

# Regenerate Neo4j seed
cd lean4 && lake env lean --run SeedNeo4j.lean > ../mcp/neo4j/script.txt

# Python (local dev)
cd python && pip install -e ".[dev]"
uvicorn world_model.mcp_server:app --host 0.0.0.0 --port 7010
```
