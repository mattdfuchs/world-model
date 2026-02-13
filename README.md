# World Model Monorepo

This repo hosts multiple components for a Lean4 + Python + Neo4j + n8n workflow.

## Components
- `lean4/`: Lean4 code (use `lake` to initialize a project).
- `python/`: Python 3 service, intended to expose a local MCP server that talks to Lean4 via LeanInteract.
- `mcp/neo4j/`: Dockerfile that pulls the official Neo4j MCP release binary.
- `n8n/`: n8n configuration notes.
- `docker-compose.yaml`: Local dev stack (Neo4j + n8n + MCP services).

## Quick Start
1) Copy env template:
   ```
   cp .env.example .env
   ```
2) Update `.env` with your credentials and MCP version.
3) Start the stack:
   ```
   docker compose up -d
   ```
4) Open:
   - Neo4j Browser: http://localhost:7474
   - n8n: http://localhost:5678

## Notes
- The Python MCP server is scaffolded as a placeholder. Implement the official MCP protocol using your preferred SDK.
- The Neo4j MCP server runs in HTTP mode so n8n can call it over the network.
