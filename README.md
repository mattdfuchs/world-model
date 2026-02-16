# World Model Monorepo

This repo hosts a multi-agent workflow that schedules clinical-trial meetings and formally verifies them using Lean 4. An n8n pipeline orchestrates four AI agents (Router, Query, Meeting, Proof) backed by Claude, a Neo4j knowledge graph, and a Lean 4 theorem prover.

## Components

- `lean4/`: Lean 4 knowledge base — entity types, ground-fact predicates, derived predicates (`legalMeeting`), and proved theorems.
- `python/`: FastAPI server (port 7010) wrapping LeanInteract to run Lean commands. Automatically splits `import` statements from theorem code for REPL compatibility.
- `mcp/neo4j/`: Dockerfile for the official Neo4j MCP binary in HTTP mode (port 7011). `script.txt` contains the Cypher commands that seed the graph.
- `n8n/`: n8n Dockerfile and workflow JSON files.
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

### 3. Open n8n

Open http://localhost:5678 in your browser. If prompted, create an n8n owner account (this is local only).

### 4. Create Anthropic credentials in n8n

1. Go to **Settings > Credentials** (or click the credential icon in the left sidebar).
2. Click **Add Credential**, search for **Anthropic**, and select **Anthropic API**.
3. Paste your API key (or leave blank if using `CREDENTIALS_OVERWRITE_DATA`).
4. Click **Save**. Note the credential name (e.g. "Anthropic account").

### 5. Import the workflow

From the command line:

```bash
docker compose cp n8n/workflows/ProveWorkflow.json n8n:/tmp/ProveWorkflow.json
docker compose exec n8n n8n import:workflow --input=/tmp/ProveWorkflow.json
```

Then refresh the n8n browser tab. You should see a workflow named **"Test Lean"**.

Open it. If the Anthropic Chat Model nodes show a credential warning, click each one (Router LLM, Meeting LLM, Query LLM, Proof LLM) and select the Anthropic credential you created in step 4.

### 6. Initialize the database and Lean REPL

This step seeds Neo4j with the clinical-trial knowledge graph and warms up the Lean REPL.

1. Open the **Test Lean** workflow.
2. Click **Test Workflow** (or press the play button on the **Manual Trigger** node).
3. Wait for all five nodes in the top row to complete:
   - Manual Trigger → Neo4j MCP Init → Delete All Nodes → Read Script → Initialize DB → Warm Up Lean
4. The Warm Up Lean node runs `import WorldModel.KB.Relations` which compiles the Lean project. This takes 1-3 minutes on first run.

### 7. Use the chat

1. In the same workflow, click the **Chat** button (bottom-right chat icon) to open the chat panel.
2. Try a **database query**:
   ```
   How many clinics are there?
   ```
   This routes to the Query Agent, which inspects the Neo4j schema and runs a Cypher query.

3. Try a **meeting request**:
   ```
   Arrange a meeting for patient Jose
   ```
   This routes through the full pipeline:
   - **Router Agent** classifies the input as a meeting request
   - **Meeting Agent** queries Neo4j and proposes a meeting as structured JSON
   - **Proof Agent** constructs a Lean 4 proof of `legalMeeting` and verifies it compiles
   - **Verify Proof** re-checks the proof independently
   - If the proof holds, the meeting JSON is returned to the chat

4. Try an **impossible meeting**:
   ```
   Arrange a meeting for patient Rick
   ```
   Rick is an Administrator (not a Patient), so the Meeting Agent returns null and you get "No valid meeting could be arranged."

## Architecture

```
Chat Trigger → Router Agent → Parse Route → IF Is Meeting
  ├─ true → Meeting Agent → Extract JSON → IF Valid
  │           ├─ true → Proof Agent → Extract Proof → Verify Proof → Check Result
  │           └─ false → "No valid meeting"
  └─ false → Query Agent
```

Each AI Agent has its own Anthropic Claude model and tool nodes:
- **Router Agent**: No tools (classification only)
- **Query Agent**: `read_cypher`, `get_neo4j_schema`
- **Meeting Agent**: `read_cypher`, `get_neo4j_schema`
- **Proof Agent**: `lean_command`

## Editing the Knowledge Base

- **Neo4j data**: Edit `mcp/neo4j/script.txt` and re-run the Manual Trigger to reload.
- **Lean 4 types/relations**: Edit files under `lean4/WorldModel/KB/`. After changes, restart the `python-mcp` container (`docker compose restart python-mcp`) so the REPL picks up the new code.

## Notes

- The Neo4j MCP server runs in HTTP mode and accepts JSON-RPC at `/mcp` with Basic Auth.
- The Python MCP server's `/lean/command` endpoint automatically splits `import` statements from subsequent code and chains REPL environments.
- n8n workflow files are mounted read-only into the container at `/home/node/.n8n-files/`.
